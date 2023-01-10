#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'uninitialized';

use English;
use File::Basename qw( fileparse );
use Getopt::Long qw( GetOptions );

our $VERSION = '1.0';
my $scriptname;
BEGIN {
	($scriptname) = fileparse($PROGRAM_NAME);
}

use constant INFO => qq(Summarizes info from auth.log\n);
use constant USAGE => qq(
Usage:
	$scriptname
	$scriptname auth.log auth.log.1
	cat some.log | $scriptname --stdin

Options:
  -i --stdin    Read input from stdin.
  -h --help     Outputs this help text and exits.
  -v --version  Outputs script version and exits.
);

use constant DEFAULT_AUTH_FILE => '/var/log/auth.log';

# TODO support things like users-only, filtering by users, filtering by status,
# formatting, etc... All things that will take more careful consideration than I
# have the patience for right now.

my %Args;
GetOptions(
	'i|stdin'   => \$Args{stdin},
	'h|help'    => sub { Usage() },
	'v|version' => sub { print("Version $VERSION\n"); exit(0); },
) or die Usage($OS_ERROR);

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

print("Successful logins:\n");
PrintUserHash(\%success);
print("\n");
print("Failed logins:\n");
PrintUserHash(\%failure);

sub PrintUserHash {
	my ($hash) = @_;
	for my $user_name (sort keys %$hash) {
		my $user_hash = $hash->{$user_name};

		print("\t$user_name\n");

		for my $ip (sort keys %{$user_hash->{IPS}}) {
			my $count = $user_hash->{IPS}->{$ip};

			print("\t\t$ip\t($count)\n");
		}
	}
}


sub ProcessFile {
	my ($file) = @_;
	open(my $handle, '<', $file) or die "Cannot open $file\n";
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

sub Usage {
	my ($msg) = @_;

	my $output = $msg ? "$msg\n\n" : "\n";
	$output .= INFO;
	$output .= USAGE;

	print($output);
	exit(!!$msg); # Assume a given message means some error occurred.
}

