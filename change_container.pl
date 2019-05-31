#!/usr/bin/perl
use strict;
use warnings;
no warnings 'uninitialized';

use File::Basename qw( fileparse );
use File::Glob qw( bsd_glob );
use Getopt::Long;
use IPC::Run3 qw( run3 );

our $VERSION = '2.2';

# TODO actually implement log levels for ffmpeg subprocesses
# TODO actually implement progress
# TODO verify multiple audio tracks are preserved and converted
# TODO ctrl+c handler (currently subshells eat it)

use constant INFO => qq{
Converts a media files to the Funbox Watch format.
    Container  mp4
    Encoding   h.264
    Audio      aac

Videos already encoded with h.264 (typically .mkv files) will simply have
their video container changed without re-encoding the video.
Multiple audio tracks will be preserved (but Watch will only play the first).
Subtitle tracks will be preserved. The output file has .conv appended to the
name if it would otherwise overwrite the input file.
};

use constant OPTIONS => qq{
Options:
  -h --help       Outputs this help text.
  -m --mock       Output operations without actually running the conversion.
  -o --out-dir    Specifies a separate output directory. Defaults to the same
                  directory as the source file.
  -l --log-level  Sets the output level. Valid options:
                      none      Output nothing at all
                      info      Output operations only (useful for cron jobs)
                      progress  (Default) Output operations with progress bar
                      debug     Output full info from ffmpeg
};

use constant LOG_LEVELS => {
	none => 0,
	info => 1,
	progress => 2,
	debug => 3,
};

my %Args;
GetOptions(
	'l|log-level:s' => \($Args{log_level} = 'progress'),
	'm|mock'        => \($Args{mock}),
	'o|out-dir:s'   => \($Args{out_dir}),
	'v|version'     => sub { print("Version $VERSION\n"); exit(0); },
	'h|help'        => sub { Usage(); },
) or die Usage($!);

my $LogLevel = LOG_LEVELS->{$Args{log_level}};

unless (defined $LogLevel) {
	Usage("Invalid log level [$Args{log_level}]");
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

	Log("Converting: $path");

	my $input = "$dir/$basename$suffix";
	my $output = $Args{out_dir} // $dir;
	$output .= "/$basename.mp4";

	if ($input eq $output) {
		Log("Output path matches input path. Appending .conv to output name");
		$output .= ".conv";
	}

	run3([
		'ffmpeg',
		'-i', $input,
		'-c:v', $vidcodec,
		'-map', '0',
		'-c:a', 'aac',
		'-c:s', 'mov_text',
		'-f', 'mp4', $output
	]) unless ($Args{mock});
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

sub Usage {
	my ($msg) = @_;
	my ($scriptname) = fileparse($0);

	my $output = qq{$msg
Usage:
    $scriptname path/to/media
};

	$output .= OPTIONS;
	$output .= INFO;

	print ($output);

	# Exit with status code 1 if $msg is provided. Assume this means error.
	exit(!!$msg);
}
