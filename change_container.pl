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
use IPC::Run3 qw( run3 );

# TODO quiet mode (don't output all the ffmpeg nonsense)
# TODO verbose ffmpeg output
# TODO skip non-media files
# TODO mock mode - just output matched media files without converting

sub convertFile {
	my ($path) = @_;

	my $vidcodec = getCodec($path) eq 'h264' ? 'copy' : 'libx264';
	my ($basename, $dir, $suffix) = fileparse($path, qr/\.[^.]*/);

	print("Converting: $path\n");
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

sub getCodec {
	my ($path) = @_;

	# TODO this can fail sometimes. Wrap in try/catch
	run3([
		'ffprobe',
		'-v', 'error',
		'-select_streams', 'v:0',
		'-show_entries',
		'stream=codec_name',
		'-of',
		'default=noprint_wrappers=1:nokey=1',
		$path
	], \undef, \(my $out));

	chomp $out;
	return $out;
}

for my $path (@ARGV) {
	if (-f $path) {
		convertFile($path);
	}
	elsif (-d $path) {
		for my $path (bsd_glob("$path/*")) {
			if (!-d $path) {
				convertFile($path);
			}
		}
	}
}

