#!/usr/bin/perl
use strict;
use warnings;
no warnings 'uninitialized';

use File::Basename qw( fileparse );
use Getopt::Long qw( GetOptions );
use IPC::Run3 qw( run3 );

our $VERSION = '1.0';

# TODO We probably want a shared module for doing video things, like GetCodec
# TODO also do something fun for Usage
# TODO how do we handle files that already have streams? Should we add an option
# for appending?

use constant INFO => qq{
Embeds one or more subtitle files into an MP4 file, as a subtitle stream.
Subtitles are embedded as-is, with no conversion applied. Not all containers
(mp4, mkv, etc...) accept all subtitle formats (dvd_subtitle, ass, etc...).

Subtitle files are provided as "language_code subtitle_file" pairs.
"language_code" should be an ISO-649-1 code
https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
};

use constant OPTIONS => qq{
Options:
  -t --sub-types  Attempt to convert subtitles to this format. Default: 'copy'
  -h --help       Outputs this help text.
  -v --version    Output script version.
};

my %Args;
GetOptions(
	't|sub-type:s' => \($Args{sub_type} = 'copy'),
	'v|version'    => sub { print("Version $VERSION\n"); exit(0); },
	'h|help|'      => sub { Usage(); },
) or die Usage($!);

# Remaining args after GetOptions are media and subtitle files
my $video_file = shift(@ARGV);
my %sub_file_map = @ARGV;

unless ($video_file) {
	Usage('Must specify a media file!');
}

unless (%sub_file_map) {
	Usage('Must specify at least one language=subtitle_file pair!');
}

# Verify these are actual subtitle files
my $index = 1; # TODO may need to detect this index based on sub tracks already present
my @sub_input_args;
my @sub_map_args;
my @sub_meta_args;
for my $lang_code (keys(%sub_file_map)) {
	my $file = $sub_file_map{$lang_code};
	my $codec = GetSubCodec($file);

	unless ($codec) {
		print(STDERR "Cannot determine codec for $file\n");
		exit(1);
	}
	print("Lang: $lang_code, file: $file\n");

	# NOTE metadata index offset by one for languages to line up properly
	push(@sub_input_args, '-i', $file);
	push(@sub_map_args,   '-map', $index);
	push(@sub_meta_args,  "-metadata:s:s:@{[$index - 1]}", "language=$lang_code");

	$index++;
}

# Now convert / merge all subtitles into the video file.
# Adapted from https://stackoverflow.com/a/65587372/7954860
run3([
	'ffmpeg',
	'-i', $video_file,
	@sub_input_args,
	'-map', '0',
	@sub_map_args,
	'-c', 'copy',
	'-c:s', $Args{sub_type},
	@sub_meta_args,
	"merged.$video_file",
]);

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

# Prints script usage information, with an optional message, then exits.
sub Usage {
	my ($msg) = @_;
	my ($scriptname) = fileparse($0);

	my $output = "$msg\n\n";
	$output .= "Usage:\n";
	$output .= "    $scriptname path/to/media lang subfile [lang subfile] \n";
	$output .= OPTIONS;
	$output .= INFO;

	print($output);

	# Exit with status code 1 if $msg is provided
	exit(!!$msg);
}

