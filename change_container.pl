#!/usr/bin/perl
################################################################################
# Converts a media files to the Funbox Watch format.
#     Container  mp4
#     Encoding   h.264
#     Audio      aac
#
# Videos already encoded with h.264 (typically .mkv files) will simply have
# their video container changed without re-encoding the video.
#
# Multiple audio tracks will be preserved (but Watch will only play the first).
#
# Subtitle tracks will be preserved.
#
################################################################################
use strict;
use warnings;
no warnings 'uninitialized';

use File::Basename qw( fileparse );
use File::Glob qw( bsd_glob );
use Getopt::Long;
use IPC::Run3 qw( run3 );

# TODO actually implement log levels for ffmpeg subprocesses
# TODO actually implement progress
# TODO legit usage string (also cleanup die calls). Pod2Usage?
# TODO mock mode - just output matched media files without converting
# TODO verify multiple audio tracks are preserved and converted

use constant LOG_LEVELS => {
	none => 0,     # No output at all
	info => 1,     # Only output conversions and skipped files
	progress => 2, # Output conversions with progress bar (default)
	debug => 3,    # Display ffmpeg output
};

my %Args;
GetOptions(
	'l|log-level:s' => \($Args{log_level} = 'progress'),
) or die $!;

my $LogLevel = LOG_LEVELS->{$Args{log_level}};

unless (defined $LogLevel) {
	my @levels = keys %{LOG_LEVELS()};
	die "Invalid log level [$Args{log_level}]. Valid levels are [@levels].";
}

for my $path (@ARGV) {
	if (-f $path) {
		ConvertFile($path);
	}
	elsif (-d $path) {
		for my $path (bsd_glob("$path/*")) {
			if (!-d $path) {
				ConvertFile($path);
			}
		}
	}
}

sub Log {
	my ($msg) = @_;
	if ($LogLevel >= LOG_LEVELS->{info}) {
		print("$msg\n");
	}
}

sub ConvertFile {
	my ($path) = @_;

	my $format = GetCodec($path);
	unless ($format) {
		Log("$path - Skipping, not a media file");
		return;
	}

	my $vidcodec = $format eq 'h264' ? 'copy' : 'libx264';
	my ($basename, $dir, $suffix) = fileparse($path, qr/\.[^.]*/);

	Log("Converting: $path\n");

	run3([
		'ffmpeg',
		'-i', "$dir/$basename$suffix",
		'-c:v', $vidcodec,
		'-map', '0',
		'-c:a', 'aac',
		'-c:s', 'mov_text',
		'-f', 'mp4', "$dir/$basename.mp4"
	]);
}

sub GetCodec {
	my ($path) = @_;

	run3([
		'ffprobe',
		'-v', 'error',
		'-select_streams', 'v:0',
		'-show_entries',
		'stream=codec_name',
		'-of',
		'default=noprint_wrappers=1:nokey=1',
		$path
	], \undef, \(my $out), \undef);

	chomp $out;
	return $out;
}

