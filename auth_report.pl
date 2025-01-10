#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'uninitialized';

use feature 'say';

our $VERSION = '1.1';

use English;
use Getopt::Long qw( GetOptions );
use Pod::Usage qw( pod2usage );

use constant DEFAULT_AUTH_FILE => '/var/log/auth.log';

# TODO support things like users-only, filtering by users, filtering by status,
# formatting, etc... All things that will take more careful consideration than I
# have the patience for right now.

my %Args;
GetOptions(
	'i|stdin'   => \$Args{stdin},
	'v|version' => sub { say("Version $VERSION"); exit(0); },
	'h|help'    => sub {
		pod2usage({
			-exitval  => 0,
			-verbose  => 99,
			-sections => [qw( NAME SYNOPSIS OPTIONS )],
		});
	},
) or pod2usage({ -exitval => $ERRNO });

# Each service outputs slightly different lines, so we define separate
# extractors for each of them.
my %extractors = (
	sshd => \&ExtractSshd,
);

my %success;
my %failure;

# Handle multiple files or read from stdin
if (scalar @ARGV > 0) {
	for my $file (@ARGV) {
		ProcessFile($file);
	}
} elsif ($Args{stdin}) {
	while (my $line = <>) {
		ProcessLine($line);
	}
} else {
	ProcessFile(DEFAULT_AUTH_FILE);
}

say('Successful logins:');
PrintUserHash(\%success);
print("\n");
say('Failed logins:');
PrintUserHash(\%failure);

sub PrintUserHash {
	my ($hash) = @_;
	for my $user_name (sort keys %$hash) {
		my $user_hash = $hash->{$user_name};

		say("\t$user_name");

		for my $ip (sort keys %{$user_hash->{IPS}}) {
			my $count = $user_hash->{IPS}->{$ip};

			say("\t\t$ip\t($count)");
		}
	}
}


sub ProcessFile {
	my ($file) = @_;
	open(my $handle, '<', $file) or die("Cannot open $file\n");
	while (my $line = <$handle>) {
		ProcessLine($line);
	}
	close($handle);
}

sub ProcessLine {
	my ($line) = @_;
	my ($line_generic, $line_detail) = split(': ', $line, 2);

	# TODO not using $generic yet, but it's here when we want to.
	# TODO also only currently supporting sshd
	my $generic = ExtractGeneric($line_generic);
	my $detail = ($extractors{$generic->{SERVICE}} // sub {})->($line_detail);

	if ($detail->{ACCEPTED}) {
		$success{$detail->{USER}}->{IPS}->{$detail->{IP}}++;
	}

	if ($detail->{FAILED}) {
		$failure{$detail->{USER}}->{IPS}->{$detail->{IP}}++;
		if ($detail->{INVALID}) {
			$failure{$detail->{USER}}->{INVALID} = 1;
		}
	}
}

# Extracts the generic prefix every line starts with.
sub ExtractGeneric {
	my ($line) = @_;
	my ($date, $host, $service) =
		($line =~ /^(\w{3}  ?\d{1,2} \d{2}:\d{2}:\d{2}) (\w+) ([\w\-]+)\[\d+\]$/);

	return {
		DATE => $date,
		HOST => $host,
		SERVICE => $service,
	};
}

# Extracts info from sshd lines.
sub ExtractSshd {
	my ($line) = @_;
	my ($status, $type, $invalid, $user, $ip) =
		($line =~ /(Accepted|Failed) (\w+) for (invalid user )?(\w+) from ((?:\d{1,3}\.){3}\d{1,3})/);

	unless ($status) {
		return undef;
	}

	my $extracted = {
		TYPE => $type,
		USER => $user,
		IP   => $ip,
	};

	$extracted->{uc($status)} = 1;

	if ($invalid) {
		$extracted->{INVALID} = 1;
	}

	return $extracted;
}

=pod

=head1 NAME

auth_report - Summarizes info from auth.log

=head1 SYNOPSIS

auth_report

auth_report auth.log auth.log.1

cat some.log | auth_report --stdin

=head1 OPTIONS

=over

=item B<-i --stdin>S<   Read input from stdin.>

=item B<-h --help>S<    Outputs this help text and exits.>

=item B<-v --version>S< Outputs script version and exits.>

=back

=head1 LICENSE

GPL-3.0

=cut

