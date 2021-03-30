#!/usr/bin/perl
use strict;
use warnings;

use English;
use IPC::Run3 qw( run3 );

our $VERSION = '1.0';

my $jail = $ARGV[0];
die 'Specify jail' unless $jail;

my $stdout;
run3(
	['/usr/bin/fail2ban-client', 'status', $jail],
	undef, \$stdout, undef
);
exit(1) if $CHILD_ERROR;

my ($iplist) = ($stdout =~ /Banned IP list:\s*([^\n]*)/);
my @ips = split(/ /, $iplist);

for my $ip (@ips) {
	print "$ip\n";
}
