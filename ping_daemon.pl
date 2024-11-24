#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'uninitialized';

use feature 'say';

our $VERSION = '1.3';

use Getopt::Long qw( GetOptions );
use English;
use Net::Ping;
use Pod::Usage qw( pod2usage );
use Try::Tiny qw( try );

$OUTPUT_AUTOFLUSH = 1;

use constant DEFAULT_INTERVAL => 10;
use constant DISCONNECTED => 'disconnected';
use constant CONNECTED => 'connected';

my %Args;
GetOptions(
	'i|interval:i' => \($Args{interval} = DEFAULT_INTERVAL),
	'v|version'    => sub { say("Version $VERSION"); exit(0); },
	'h|help'       => sub {
		pod2usage({
			-exitval  => 0,
			-verbose  => 99,
			-sections => [qw( DESCRIPTION EXAMPLE SYNOPSIS OPTIONS )],
		});
	},
) or pod2usage({ -exitval => $ERRNO });

$Args{destination} = $ARGV[0];
pod2usage({ -exitval => 1 }) unless ($Args{destination});

my $ping = Net::Ping->new({
	proto => 'tcp',
	port => scalar(getservbyname('https', 'tcp')),
	timeout => $Args{interval},
}) or die 'Failed to create Net::Ping';

$SIG{INT} = sub {
	logMsg('Stopping');
	$ping->close;
	exit(0);
};

logMsg('Starting');

my $status;
while (1) {
	my $resp;
	try {
		$resp = $ping->ping($Args{destination});
	};

	if ($resp) {
		if ($status ne CONNECTED) {
			$status = CONNECTED;
			logMsg('Connected');
		}
	} else {
		if ($status ne DISCONNECTED) {
			$status = DISCONNECTED;
			logMsg('Disconnected');
		}
	}

	sleep($Args{interval});
}

sub logMsg {
	my ($msg) = @_;

	my ($sec, $min, $hour, $mday, $mon, $year) = localtime;
	my $timestamp = sprintf(
		"%04d-%02d-%02d %02d:%02d:%02d",
		$year + 1900, $mon + 1, $mday, $hour, $min, $sec
	);

	say("$timestamp $msg");
}

=pod

=head1 NAME

ping_daemon - Long-running daemon for detecting a service uptime.

=head1 SYNOPSIS

ping_daemon [options] <destination>

=head1 EXAMPLE

ping_daemon www.somewebsite.com

ping_daemon www.somewebsite.com | tee --append network.log

=head1 DESCRIPTION

Periodically pings the given URL. If the destination becomes unreachable for any
reason, this script prints "Disconnected". When a connection is (re)established,
this script prints" Connected".

The secret secondary function of this script is to detect when the client itself
loses connection. This is useful to generate a log of internet outages  if, for
example, your ISP lies and tells you your connection is perfectly fine when it
I<clearly fucking isn't>.

=head1 OPTIONS

=over

=item B<-i --interval>S<    How often to check the destination.>

(Seconds, Default = 10)

=item B<-h --help>S<        Output this help text and exit.>

=item B<-v --version>S<     Output script version and exit.>

=back

=head1 LICENSE

GPL-3.0

=cut

