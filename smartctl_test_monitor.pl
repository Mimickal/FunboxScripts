#!/usr/bin/perl
use strict;
use warnings;

use English;
use Getopt::Long qw( GetOptions );
use JSON::PP qw( decode_json );
use List::Util qw( any );

our $VERSION = '1.0';

use constant INFO => qq(Outputs smartctl test progress for selected drives.

NOTE: Disk tests can take a long time. If pairing this script with "watch", use
      a reasonably long polling interval for the type of test you're watching.
      (e.g. for a long test, you could poll every 10 minutes).
);
use constant OPTIONS => qq(
Options:
  -b --bar      Display progress bar in addition to percent. Useful in
                combination with "watch".
  -d --disks    Comma-separated list of disks to get test progress for.
                If not provided, checks all disks.
  -h --help     Outputs this help text and exits.
  -v --version  Outputs script version and exits.
);

my %Args;
GetOptions(
	'b|bar'     => \($Args{bar}),
	'd|disks:s' => \($Args{disks}),
	'h|help'    => sub { usage() },
	'v|version' => sub { print("Version $VERSION\n"); exit(0); },
) or die usage($OS_ERROR);

# Verify we have smartctl installed. It's not a default package on some distros.
qx(smartctl --version);
if ($OS_ERROR) {
	die("Error: smartctl must be installed for this script to do anything!\n");
}

# smartctl requires elevated permissions to read test progress
if ($REAL_USER_ID) {
	warn("Warning: Need to run as root (or sudo) to get test progress!\n\n");
}

# Determine which disks we're going to check
my $all_disk_json = qx(smartctl --scan --json);
my $all_disk_data = decode_json($all_disk_json);
my @all_disks = map { $_->{name} } @{$all_disk_data->{devices}};

my @checked_disks;
if ($Args{disks}) {
	$Args{disks} = [split(',', $Args{disks} || '')];

	for my $given_disk (@{$Args{disks}}) {
		if (any { $given_disk eq $_ } @all_disks) {
			push(@checked_disks, $given_disk);
		} else {
			warn("Warning: not a disk $given_disk\n");
		}
	}
} else {
	@checked_disks = @all_disks;
}

# Check the disks
for my $disk (@checked_disks) {
	my $percent = getTestProgress($disk);

	print("$disk\t");
	if ($Args{bar}) {
		print(makeProgressBar($percent));
		print(' ');
	}
	if (defined $percent) {
		print("$percent%");
	} else {
		print("Complete / Not running");
	}
	print("\n");
}

sub makeProgressBar {
	my ($percent) = @_;
	$percent //= 0;

	my $bar_len = 40;
	my $filled = int($percent * $bar_len / 100);

	my $bar = '[';
	$bar .= '=' x $filled;
	$bar .= ' ' x ($bar_len - $filled);
	$bar .= ']';
	return $bar;
}

sub getTestProgress {
	my ($disk) = @_;

	# IPC::Run3 might be safer here. Possible command injection otherwise.
	my $disk_json = qx(smartctl --capabilities --json $disk);
	my $disk_info = decode_json($disk_json);

	# We'll always get this output
	my $status = $disk_info->{ata_smart_data}->{self_test}->{status};

	# This part changes based on test completion
	if (exists $status->{remaining_percent}) {
		return 100 - $status->{remaining_percent};
	} else {
		return undef;
	}
}

sub usage {
	my ($msg) = @_;
	my $output = $msg ? "$msg\n\n" : "\n";
	$output .= INFO;
	$output .= OPTIONS;

	print ($output);
	exit(!!$msg); # Assume a given message means some error occurred.
}
