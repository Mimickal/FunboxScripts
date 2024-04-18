#!/usr/bin/env perl
use strict;
use warnings;

use feature 'say';

use Data::Dumper qw( Dumper );
use English;
use File::Basename qw( fileparse );
use File::Glob qw( bsd_glob );
use Getopt::Long;
use IPC::Run3 qw( run3 );
use Pod::Usage qw( pod2usage );

our $VERSION = '2.8';

# TODO actually implement progress
# TODO ctrl+c handler (currently subshells eat it)
# TODO How do we handle 5.1 surround sound stuff?
# TODO handle files with colons in the name. Regex for : in name, then prefix
# name with "file:"
# TODO Check return code from run3 so if ffmpeg fails, we don't exit
# successfully
# TODO embed srt files into converted media

use constant LOG_LEVELS => {
	none => 0,
	warn => 1,
	info => 2,
	progress => 3,
	debug => 4,
};

my %Args;
GetOptions(
	'a|h264-args:s'   => \($Args{h264_args}),
	'e|override:s'    => \($Args{override}),
	'f|ffmpeg-args:s' => \($Args{ffmpeg_args}),
	'i|ignore:s'      => \($Args{ignore}),
	'l|log-level:s'   => \($Args{log_level} = 'info'),
	'm|mock'          => \($Args{mock}),
	'o|out-dir:s'     => \($Args{out_dir}),
	's|scale:s'       => \($Args{scale}),
	'v|version'       => sub { say("Version $VERSION"); exit(0); },
	'h|help'          => sub {
		pod2usage({
			-exitval => 0,
			-verbose => 99,
			-sections => [qw( DESCRIPTION SYNOPSIS OPTIONS)],
		});
	},
) or pod2usage({ -exitval => $ERRNO });

my $logLevel = LOG_LEVELS->{$Args{log_level}};

unless (defined($logLevel)) {
	Error("Invalid log level [$Args{log_level}]");
}

if ($logLevel >= LOG_LEVELS->{debug}) {
	Info("Args " . Dumper(\%Args));
}

if ($Args{out_dir} && !-d $Args{out_dir}) {
	Error("Invalid output directory [$Args{out_dir}]");
}

my @ffmpegArgs;
if ($logLevel < LOG_LEVELS->{debug}) {
	push(@ffmpegArgs, '-hide_banner');
}

if ($logLevel == LOG_LEVELS->{info}) {
	push(@ffmpegArgs, '-loglevel', 'info');
} elsif ($logLevel == LOG_LEVELS->{warn}) {
	push(@ffmpegArgs, '-loglevel', 'warning');
} elsif ($logLevel == LOG_LEVELS->{none}) {
	push(@ffmpegArgs, '-loglevel', 'fatal');
}

if (defined($Args{ffmpeg_args})) {
	push(@ffmpegArgs, split(/\s+/, $Args{ffmpeg_args}));
}

my @videoArgs;
if ($Args{scale}) {
	my ($height) = ($Args{scale} =~ /(\d+)[pP]/);
	unless (defined($height)) {
		Error("Invalid scale value [$Args{scale}]");
	}

	# Using -1 makes ffmpeg calculate width based on height and aspect ratio
	@videoArgs = ('-filter:v', qq(scale=-1:$height));
}
if (defined($Args{h264_args})) {
	push(@videoArgs, split(/\s+/, $Args{h264_args}));
}

my @ignoreTracks =
	map {('-map', "-0:$_")}
	split(/,/, $Args{ignore} // '');

# Telling ffmpeg to ignore a track shifts the track numbers in the output file.
# Subtract ignore arguments from the output stream numbers so callers don't need
# to care about keeping track of that shift (i.e. can use IDs from ffprobe).
my @overrideTracks = map {
	my ($stream, $format) = split(/=/, $_);
	$stream -= (scalar(@ignoreTracks) / 2);
	("-c:$stream", $format);
} split(/,/, $Args{override} // '');

# Do all the conversions, globbing directories if necessary.
for my $path (@ARGV) {
	if (-f $path) {
		ConvertFile($path);
	} elsif (-d $path) {
		for my $path (bsd_glob("$path/*")) {
			if (!-d $path) {
				ConvertFile($path);
			}
		}
	}
}

sub ConvertFile {
	my ($path) = @_;

	my $vformat = GetCodec($path, 'v:0');
	my $aformat = GetCodec($path, 'a:0');
	my $sformat = GetCodec($path, 's:0');

	unless ($vformat) {
		Info("Skipping (not a media file): $path");
		return;
	}

	my $vidcodec = ($vformat eq 'h264' && !@videoArgs) ? 'copy' : 'libx264';
	my $audcodec = ($aformat eq 'aac') ? 'copy' : 'aac';
	my $subcodec = (
		# Manually determined from https://stackoverflow.com/a/64500869/7954860
		grep { $_ eq $sformat } qw(
			dvd_subtitle
			dvb_subtitle
			hdmv_pgs_subtitle
			xsub
		)
	) ? 'copy' : 'mov_text';

	my ($basename, $dir, $suffix) = fileparse($path, qr/\.[^.]*/);

	if (
		$vidcodec eq 'copy' &&
		$audcodec eq 'copy' &&
		$subcodec eq 'copy' &&
		$suffix eq '.mp4'
	) {
		Info("Skipping (already in proper format): $path");
		return;
	}

	Info("Converting: $path");

	my $output = "@{[ $Args{out_dir} // $dir ]}/$basename.mp4";

	if ($path eq $output) {
		Info("Output path matches input path. Appending .conv to output name");
		$output .= ".conv";
	}

	my $ffmpeg_params = [
		'ffmpeg',
		@ffmpegArgs,
		'-i', $path,

		# Copy all streams by default. This applies to any stream not explicitly
		# mentioned later in the command.
		'-map', '0',
		'-c', 'copy',

		# Apply arguments to the first video stream.
		# TODO does this still skip, if needed?
		'-c:v:0', $vidcodec,
		'-filter:v:0', 'format=yuv420p',
		@videoArgs,

		# Convert first audio and subtitle streams, if needed.
		'-c:a:0', $audcodec,
		'-c:s:0', $subcodec,

		# Ignoring tracks changes output track IDs, so do this near last.
		@ignoreTracks,

		# Override track IDs take ignored tracks into account.
		@overrideTracks,

		'-f', 'mp4', $output,
	];

	if ($Args{mock}) {
		Info(Dumper($ffmpeg_params));
	} else {
		run3($ffmpeg_params);
	}
}

# Stream is something like 'v:0' or 'a:0'
sub GetCodec {
	my ($path, $stream) = @_;

	run3([
		'ffprobe',
		'-v', 'error',
		'-select_streams', $stream,
		'-show_entries',
		'stream=codec_name',
		'-of',
		'default=noprint_wrappers=1:nokey=1',
		$path
	], \undef, \(my $out), \undef);

	chomp $out;
	return $out;
}

sub Error {
	my ($msg) = @_;
	say(STDERR "Error: $msg");
	exit(1);
}

sub Info {
	my ($msg) = @_;
	if ($logLevel >= LOG_LEVELS->{info}) {
		say($msg);
	}
}

=pod

=head1 NAME

change_container - Converts a video file to a widely supported format.

=head1 SYNOPSIS

change_container <media_file_1> [media_file_2] ...

=head1 DESCRIPTION

Takes any video file and converts it to the most widely supported format we can.
We prioritize compatibility across browsers and devices first, quality second,
and file size third.

=head2 Format

=over

=item S<Container    MP4>

=item S<Video        H.264 (YUV planar color space, 4:2:0 chroma subsampling)>

=item S<Audio        AAC>

=item S<Subtitles    mov_text (if text, "copy" if otherwise, e.g. image-based)>

=item S<Attachments  copy>

=back

=head2 Notes

=over

=item - If a given path is a directory instead of a file, all media files within
that directory will be converted.

=item - This script avoids re-encoding when possible
(e.g. all correct encoding, just in an MKV instead of MP4).

=item - Multiple audio tracks are preserved
(but web players will only play the first track).

=item - The output file has .conv appended to the name if it would otherwise
overwrite the input file.

=item - Many video players, particularly ones on mobile devices, do not support
the full range of settings H.264 use. Through testing, we've determined using
format C<yuv420p> ensures the highest compatibility across players.
See L<https://trac.ffmpeg.org/wiki/Encode/H.264#Encodingfordumbplayers>.

=back

=head1 OPTIONS

=over

=item B<-a --h264-args>

Additional H.264 arguments. Remember to use quotes, if necessary.
When possible, use C<-preset veryslow> to get the best file sizes.

Example: C<--h264-args="-crf 28 -tune grain -preset slow">

See L<https://trac.ffmpeg.org/wiki/Encode/H.264>

=item B<-e --override>S<  Override track encoding instead of using defaults.>

Format: <track_id_1>=<format_1>[,<track_id_2>=<format_2>,...]

Example: C<1=h264,4=copy>

=item B<-f --ffmpeg-args>

Additional front-loaded ffmpeg args. Remember to use quotes, if necessary.
This is useful for things like C<-ss X> to trim the first X seconds of a video.

Example: C<--ffmpeg-args="-ss 5">

=item B<-i --ignore>S<    Don't include the given tracks in the output file.>

Format: <id1>[,<id2>,<id3>...]

=item B<-l --log-level>S<  Sets the log output level.>

    none      Output only show-stopping errors.
    warn      Output actions, warnings, and errors (useful for cron jobs).
    info      (Default) Output all the ffmpeg track info.
    progress  Output operations with progress bar (currently does nothing).
    debug     Output full info from ffmpeg.

=item B<-m --mock>

Output operations without actually running the conversion.

=item B<-o --out-dir>

Specifies an output directory. Defaults to same directory as the source file.

=item B<-s --scale>

Scale the output resolution. For example, if "720p" is given for a 1920x1080
video, the script will set the output height to 720 and auto-determine the width
to maintain aspect ratio. Verify the input file's resolution with L<ffprobe>
before using this to avoid fucking things up.

=item B<-h --help>S<     Output this help text and exit.>

=item B<-v --version>S<  Output version and exit.>

=back

=head1 LICENSE

GPL-3.0

=cut

