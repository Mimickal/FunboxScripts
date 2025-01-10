#!/usr/bin/perl
use strict;
use warnings;
no warnings 'uninitialized';

use feature 'say';

our $VERSION = '1.2';

use English;
use Getopt::Long qw( GetOptions );
use JSON::PP qw( decode_json );
use List::Util qw( any first );
use Pod::Usage qw( pod2usage );

my %Args;
GetOptions(
	'b|bar'     => \($Args{bar}),
	'd|disks:s' => \($Args{disks}),
	'v|version' => sub { say("Version $VERSION"); exit(0); },
	'h|help'    => sub {
		pod2usage({
			-exitval  => 0,
			-verbose  => 99,
			-sections => [qw( DESCRIPTION SYNOPSIS OPTIONS )],
		});
	},
) or pod2usage({ -exitval => $ERRNO });

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
	my $progress = getTestProgress($disk);

	print("$disk\t");

	unless (defined $progress) {
		print("Complete / Not running\n");
		next;
	}

	my ($cur, $max) = @$progress{qw( CUR MAX )};

	if ($Args{bar}) {
		print(makeProgressBar($cur, $max));
		print(' ');
	}

	if (defined $max) {
		my $percent = int($cur / $max * 100);
		print("$percent%\t($cur / $max)");
	} else {
		print("$cur%");
	}
	print("\n");
}

sub makeProgressBar {
	my ($cur, $max) = @_;
	$max //= 100;

	my $bar_len = 40;
	my $filled = int($cur / $max * $bar_len);

	my $bar = '[';
	$bar .= '=' x $filled;
	$bar .= ' ' x ($bar_len - $filled);
	$bar .= ']';
	return $bar;
}

sub getTestProgress {
	my ($disk) = @_;

	# IPC::Run3 might be safer here. Possible command injection otherwise.
	# FIXME smartctl can hang sometimes, which we should catch

	# First, let's try to get fine-grained progress
	my $disk_json = qx(smartctl --log selective --json $disk);
	my $disk_info = decode_json($disk_json);

	my $test_table = $disk_info->{ata_smart_selective_self_test_log}->{table};
	my $in_progress_test = first {
		$_->{status}->{string} eq 'Self_test_in_progress'
	} @$test_table;

	if (defined $in_progress_test) {
		return {
			MAX => $in_progress_test->{lba_max},
			CUR => $in_progress_test->{current_lba_min},
		};
	}

	# If that didn't work, fall back on coarse test percentage
	$disk_json = qx(smartctl --capabilities --json $disk);
	$disk_info = decode_json($disk_json);
	my $status = $disk_info->{ata_smart_data}->{self_test}->{status};

	if (exists $status->{remaining_percent}) {
		return {
			CUR => 100 - $status->{remaining_percent},
		};
	}

	# Test probably isn't running, or we suck at reading progress
	return undef;
}

=pod

=head1 NAME

smartctl_test_monitor - Outputs smartctl test progress.

=head1 SYNOPSIS

sudo smartctl_test_monitor

sudo watch -n 60 smartctl_test_monitor --bar

=head1 DESCRIPTION

Outputs smartctl test progress for selected drives.

For fine-grained reporting, start your test like this:
C<smartctl --test select,0-max>

NOTE: Disk tests can take a long time. If pairing this script with C<watch>, use
a reasonably long polling interval for the type of test you're watching.
(e.g. for a long test, you could poll every 10 minutes using C<--interval 600>).

=head1 OPTIONS

=over

=item B<-b --bar>S<     Display progress bar in addition to percent.>

Useful in combination with C<watch>.

=item B<-d --disks>S<   Comma-separated list of disks to get test progress for.>

If not provided, checks all disks.

=item B<-h --help>S<    Outputs this help text and exits.>

=item B<-v --version>S< Outputs script version and exits.>

=back

=head1 LICENSE

GPL-3.0

=cut

