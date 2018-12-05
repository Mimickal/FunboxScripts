#!/usr/bin/perl
################################################################################
# Changes the container of an .mkv video to a .mp4 video.
#
# Video encoding is assumed to be h.264 (thus we only need to change the
# container).
# Audio is converted to aac.
#
################################################################################
use strict;
use warnings;
no warnings 'uninitialized';

use File::Basename qw( basename dirname );
use File::Glob qw( bsd_glob );
use IPC::Run3 qw( run3 );

sub convertFile {
	my ($path) = @_;

	my $dir = dirname($path);
	my $basename = basename($path, ".mkv");

	print("Converting: $path\n");
	run3([
		'ffmpeg',
		'-i', "$dir/$basename.mkv",
		'-c:v', 'copy',
		'-c:a', 'aac',
		'-c:s', 'mov_text',
		'-f', 'mp4', "$dir/$basename.mp4"
	]);
}

for my $path (@ARGV) {
	if (-f $path) {
		convertFile($path);
	}
	elsif (-d $path) {
		for my $path (bsd_glob("$path/*.mkv")) {
			if (!-d $path) {
				convertFile($path);
			}
		}
	}
}

