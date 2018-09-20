#!/usr/bin/perl
###########################################################
# Better chown
#
# Recursively changes the owner, group, and permissions on
# all of the sub-directories and files in the given directory.
###########################################################

use strict;
use warnings;
no warnings 'uninitialized';

use File::Find::Rule;
use Getopt::Long;

my %Args;
GetOptions(
	'user:s'      => \($Args{user}),
	'group:s'     => \($Args{group}),
	'file-perm:s' => \($Args{fileperm}),
	'dir-perm:s'  => \($Args{dirperm}),
	'exclude:s'   => \($Args{exclude}),
	'silent'      => \($Args{silent}),
	'h|help'      => \&Usage,
) or die $!;

if (!@ARGV) {
	die "Error: no path provided\n";
	Usage();
}

if (!$Args{user} && !$Args{group} && !$Args{dirperm} && !$Args{fileperm}) {
	die "Nothing to do because no options specified. Exiting.\n";
}

if (!$Args{silent} && $> != 0) {
	warn "Not running as root. Script likely won't work.\n";
}

if (scalar(@ARGV) == 1 && -f $ARGV[0]) {
	ChangePerms($ARGV[0], $Args{fileperm});
} else {
	# Build lookup table of items to exclude
	my %exclude =
		map { $_ => 1 }
		map { File::Find::Rule->in(glob($_)) }
		split(/,/, $Args{exclude});

	# Filter excluded files out of all files in the given directory
	my @files =
		grep { not $exclude{$_} }
		map { File::Find::Rule->in($_) }
		@ARGV;

	printf(
		"Changing permissions for %d file(s) (ignoring %d)...\n",
		scalar(@files), scalar(keys(%exclude))
	) if !$Args{silent};

	for my $path (@files) {
		if (-f $path) {
			ChangePerms($path, $Args{fileperm});
		} else {
			ChangePerms($path, $Args{dirperm});
		}
	}

	print("Done.\n") if !$Args{silent};
}


sub Usage {
print(qq(Usage: $0 [options] <parent path>

Recursively change the owner, group, and permissions
of files and directories under the given path.
The path may also be provided as a glob.

ex: $0 --user funbox --group curator --file-perm 0575 --dir-perm 0464 /home/funbox/

  --user       User for files and directories.
  --group      Group name for files and directories.
  --file-perm  Permissions to apply to files (ex: 644).
  --dir-perm   Permissions to apply to directories (ex: 755).
  --exclude    A comma-separated list of files / sub-directories to exclude.
  --silent     Don't output warning or info text.
  -h --help    Show this text.
));
}

sub ChangePerms {
	my ($path, $perms) = @_;

	# Don't change user / group value if they weren't specified
	my $uid = (defined $Args{user}) ? getpwnam($Args{user}) : -1;
	my $gid = (defined $Args{group}) ? getgrnam($Args{group}) : -1;
	chown($uid, $gid, $path);

	if (defined($perms)) {
		chmod(oct($perms), $path);
	}
}

