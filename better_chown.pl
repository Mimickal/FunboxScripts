#!/usr/bin/env perl

use strict;
use warnings;
no warnings 'uninitialized';

use feature 'say';

our $VERSION = '1.1';

use English;
use File::Find::Rule;
use Getopt::Long;
use Pod::Usage qw( pod2usage );

my %Args;
GetOptions(
	'u|user:s'      => \($Args{user}),
	'g|group:s'     => \($Args{group}),
	'f|file-perm:s' => \($Args{fileperm}),
	'd|dir-perm:s'  => \($Args{dirperm}),
	'e|exclude:s'   => \($Args{exclude}),
	's|silent'      => \($Args{silent}),
	'm|mock'        => \($Args{mock}),
	'v|version'     => sub { say("Version $VERSION"); exit(0); },
	'h|help'        => sub {
		pod2usage({
			-exitval  => 0,
			-verbose  => 99,
			-sections => [qw( DESCRIPTION SYNOPSIS OPTIONS )],
		});
	},
) or pod2usage({ -exitval => $ERRNO });

if (!@ARGV) {
	die "Error: no path provided\n";
}

# Don't print warnings when outputting list of matched files
$Args{silent} = 1 if $Args{mock};

if (
	!$Args{mock} &&
	!$Args{user} &&
	!$Args{group} &&
	!$Args{dirperm} &&
	!$Args{fileperm}
) {
	die "Nothing to do because no options specified. Exiting.\n";
}

if (!$Args{silent} && $REAL_USER_ID) {
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

sub ChangePerms {
	my ($path, $perms) = @_;

	if ($Args{mock}) {
		print("$path\n");
		return;
	}

	# Don't change user / group value if they weren't specified
	my $uid = (defined $Args{user}) ? getpwnam($Args{user}) : -1;
	my $gid = (defined $Args{group}) ? getgrnam($Args{group}) : -1;
	chown($uid, $gid, $path);

	if (defined($perms)) {
		chmod(oct($perms), $path);
	}
}

=pod

=head1 NAME

better_chown - Recursive chown with better options.

=head1 SYNOPSIS

better_chown [options] <path_1> [path_2] ...

better_chown --user funbox --group creator --file-perm 0464 --dir-perm 0575 /home/funbox

=head1 DESCRIPTION

Recursively change the owner, group, and permissions of files and directories
under the given path. Multiple paths may be given (including globs).

=head1 OPTIONS

=over

=item B<-u --user>S<      Make all files and directories owned by this user.>

=item B<-g --group>S<     Make all files and directories owned by this group.>

=item B<-f --file-perm>S< Permissions to apply to files (ex: 644).>

=item B<-d --dir-perm>S<  Permissions to apply to directories (ex: 755).>

=item B<-e --exclude>S<   Comma-separated list of files/directories to exclude.>

=item B<-s --silent>S<    Don't output warning or info text.>

=item B<-m --mock>S<      Don't actually change anything, just print matched files.>

=item B<-h --help>S<      Output this help text and exit.>

=item B<-v --version>S<   Output version and exit.>

=back

=head1 LICENSE

GPL-3.0

=cut

