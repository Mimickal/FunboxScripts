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
	'v|verbose'     => \($Args{verbose}),
	'version'       => sub { say("Version $VERSION"); exit(0); },
	'h|help'        => sub {
		pod2usage({
			-exitval  => 0,
			-verbose  => 99,
			-sections => [qw( DESCRIPTION SYNOPSIS OPTIONS )],
		});
	},
) or pod2usage({ -exitval => $ERRNO });

unless (@ARGV) {
	die("Error: no path provided\n");
}

if ($Args{silent} && $Args{verbose}) {
	warn("--silent and --verbose specified. Disabling both.\n");
	$Args{silent} = 0;
	$Args{verbose} = 0;
}

if ($Args{mock}) {
	$Args{verbose} = 1;

	if ($Args{silent}) {
		warn("--silent and --mock specified. Disabling --silent\n");
		$Args{silent} = 0;
	}
}

if (
	!$Args{mock} &&
	!$Args{user} &&
	!$Args{group} &&
	!$Args{dirperm} &&
	!$Args{fileperm}
) {
	die("Nothing to do because no options specified. Exiting.\n");
}

if ($REAL_USER_ID && !$Args{silent}) {
	warn("Not running as root. Script likely won't work.\n");
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
	) unless ($Args{silent});

	for my $path (@files) {
		if (-f $path) {
			ChangePerms($path, $Args{fileperm});
		} else {
			ChangePerms($path, $Args{dirperm});
		}
	}

	say('Done.') unless ($Args{silent});
}

sub ChangePerms {
	my ($path, $perms) = @_;

	say($path) if ($Args{verbose});
	return if ($Args{mock});

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

=item B<-m --mock>S<      Don't actually change anything. Implies --verbose.>

=item B<-v --verbose>S<   Print all the changed files and directories.>

=item B<-h --help>S<      Output this help text and exit.>

=item B<--version>S<      Output version and exit.>

=back

=head1 LICENSE

GPL-3.0

=cut

