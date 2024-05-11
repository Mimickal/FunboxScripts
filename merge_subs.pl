#!/usr/bin/perl
use strict;
use warnings;

use feature 'say';

use Data::Dumper;
use English;
use File::Basename qw( fileparse );
use Getopt::Long qw( GetOptions );
use List::Util qw( pairs );
use IPC::Run3 qw( run3 );
use Pod::Usage qw( pod2usage );

our $VERSION = '1.1';

# TODO We probably want a shared module for doing video things, like GetCodec
# TODO how do we handle files that already have streams? Should we add an option
# for appending?

my %Args;
GetOptions(
	'm|mock'       => \($Args{mock}),
	't|sub-type:s' => \($Args{sub_type} = 'copy'),
	'v|version'    => sub { say("Version $VERSION"); exit(0); },
	'h|help'       => sub {
		pod2usage({
			-exitval  => 0,
			-verbose  => 99,
			-sections => [qw( DESCRIPTION SYNOPSIS OPTIONS )],
		});
	},
) or pod2usage({ -exitval => $ERRNO });

# Remaining args after GetOptions are media and subtitle files
my $video_file = shift(@ARGV);

# We want to preserve the given CLI arg order in the video track list,
# so sadly we can't just read this value in as a hash.
my @sub_files = @ARGV;

unless ($video_file) {
	say(STDERR 'Error: Must specify a media file!');
	exit(1);
}

if (scalar(@sub_files) == 0) {
	say(STDERR 'Error: Must specify at least one language=subtitle_file pair!');
	exit(1);
}

unless (scalar(@sub_files) % 2 == 0) {
	say(STDERR 'Error: mismatched language codes and sub files!');
	say(Dumper(\@sub_files));
	exit(1);
}

# Verify these are actual subtitle files, and build arg lists.
# At this point we know we have an even, non-zero number of items in @sub_files.
my @sub_input_args;
my @sub_map_args;
my @sub_meta_args;

my $track = 1; # TODO may need to detect this index based on sub tracks already present
for my $pair (pairs(@sub_files)) {
	my ($lang, $file) = @$pair;
	my $codec = GetSubCodec($file);

	unless ($codec) {
		say(STDERR "Error: Cannot determine codec for $file");
		exit(1);
	}

	say("Sub $track: [$lang] -> \"$file\"");

	# NOTE metadata index offset by one for languages to line up properly
	push(@sub_input_args, '-i', $file);
	push(@sub_map_args,   '-map', "$track");
	push(@sub_meta_args,  "-metadata:s:s:@{[$track - 1]}", "language=$lang");

	$track++;
}

# Now convert / merge all subtitles into the video file.
# Adapted from https://stackoverflow.com/a/65587372/7954860
my $ffmpeg_params = [
	'ffmpeg',
	'-i', $video_file,
	@sub_input_args,
	'-map', '0',
	@sub_map_args,
	'-c', 'copy',
	'-c:s', $Args{sub_type},
	@sub_meta_args,
	'-movflags', 'use_metadata_tags',
	'-map_metadata', '0',
	"merged.$video_file",
];

if ($Args{mock}) {
	say(Dumper($ffmpeg_params));
} else {
	run3($ffmpeg_params);
}

# Gets info about the subtitle file.
# NOTE this is essentially GetCodec from change_container.pl
sub GetSubCodec {
	my ($path) = @_;

	run3([
		'ffprobe',
		'-v', 'error',
		'-select_streams', 's:0',
		'-show_entries',
		'stream=codec_name',
		'-of',
		'default=noprint_wrappers=1:nokey=1',
		$path,
	], \undef, \(my $out), \undef);

	chomp($out);
	return $out;
}

=pod

=head1 NAME

merge_subs - Merges subtitle files into a video file.

=head1 SYNOPSIS

merge_subs <media_file> <lang> <sub_file> [lang2 sub_file2 lang3 sub_file3 ...]

=head1 DESCRIPTION

Embeds one or more subtitle files into an video file, as a subtitle stream.
Subtitles are embedded as-is, with no conversion applied. Not all containers
(mp4, mkv, etc...) accept all subtitle formats (dvd_subtitle, ass, etc...).

Subtitle files are provided as C<language_code subtitle_file> pairs.
C<language_code> should be an ISO-649-1 code (use C<Set 3>)
L<https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes>

=head1 OPTIONS

=over

=item B<-m --mock>S<       Output operations without actually doing anything>

=item B<-t --sub-types>S<  Attempt to convert subtitles to this format.>

=item B<-h --help>S<       Output this help text and exit.>

=item B<-v --version>S<    Output script version and exit.>

=head1 LICENSE

GPL-3.0

=cut

