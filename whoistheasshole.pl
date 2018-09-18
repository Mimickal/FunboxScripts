#!/usr/bin/perl

use strict;
use warnings;
no warnings 'uninitialized';

# Get user and cpu usage percentage for every process
my @processlines = `ps ax -o user,%cpu`;

# Throw out the header line
shift @processlines;

# Tally up cpu usage totals
my %usagetotals;
for my $line (@processlines) {
	my ($user, $cpupercent) = $line =~ /(\w+)\D+([\d.]+)/;
	$usagetotals{$user} += $cpupercent;
}

# Find the user with the highest CPU usage
my $hog;
for my $user (keys(%usagetotals)) {
	if ($usagetotals{$user} > $usagetotals{$hog}) {
		$hog = $user;
	}
}

# Yell at the hog
if ($hog eq $ENV{USER}) {
	print "The asshole is YOU, $hog! You're using $usagetotals{$hog}% of the CPU!\n";
}
else {
	print "The asshole is $hog. They're using $usagetotals{$hog} of the CPU!\n";
}

