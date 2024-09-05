#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'uninitialized';

use feature 'say';

use English;
use File::Slurp qw( read_file );
use Getopt::Long qw( GetOptions );
use LWP::Simple qw( get );
use Pod::Usage qw( pod2usage );

our $VERSION = '1.0';

use constant URL_ROOT => 'https://freedns.afraid.org/dynamic/update.php?';

my %Args;
GetOptions(
	'e|error-no-change'   => \($Args{error}),
	's|silent'            => \($Args{silent}),
	'se|silent-no-change' => \($Args{silent_error}),
	'su|silent-update'    => \($Args{silent_update}),
	't|token:s'           => \($Args{token}),
	'v|version'           => sub { say("Version $VERSION"); exit(0); },
	'h|help'              => sub {
		pod2usage({
			-exitval => 0,
			-verbose => 99,
			-sections => [qw( DESCRIPTION SYNOPSIS OPTIONS )],
		});
	},
) or pod2usage({ -exitval => $ERRNO });

# Figure out the most appropriate place to load a token from.
my $token;
if ($ARGV[0]) {
	$token = ReadFile($ARGV[0]) // $ARGV[0];
} elsif ($Args{token}) {
	$token = ReadFile($Args{token}) // $Args{token};
} elsif ($EFFECTIVE_USER_ID == 0) {
	$token = ReadFile('/etc/freedns/token');
} elsif ($ENV{HOME}) {
	$token = ReadFile("$ENV{HOME}/.freedns_token");
}

# Process the token into something usable.
$token =~ s/\Q@{[URL_ROOT]}\E//;

unless ($token) {
	pod2usage({
		-msg => "No token found!\n",
		-exitval => 1,
		-verbose => 99,
		-sections => [qw( SYNOPSIS DESCRIPTION )],
	});
}

# Make the request. This updates the DNS record.
my $response = get("@{[URL_ROOT]}$token");
chomp($response);

if ($response =~ /^Updated/) {
	say($response) unless ($Args{silent} || $Args{silent_update});
	exit(0);
} elsif($response =~ /^ERROR: Address .+ has not changed\.$/) {
	say($response) unless ($Args{silent} || $Args{silent_error});
	exit($Args{error} ? 2 : 0);
} else {
	say($response);
	exit(1);
}

# Helpers
sub ReadFile {
	my ($filename) = @_;
	return unless (-f $filename);

	my $token = read_file($filename);
	chomp($token);
	return $token;
}

=pod

=head1 SYNOPSIS

freedns_update [your token]

freedns_update --token <your token>

=head1 DESCRIPTION

Updates a L<freedns.afraid.org> dynamic DNS record using an update token.

The update token is the part at the end of the "Direct URL" link for your domain
on L<https://freedns.afraid.org/dynamic/>. For example, if your update link is
L<https://freedns.afraid.org/dynamic/update.php?123ABC>,
your update token is C<123ABC>.

A token is read from the following, ordered by descending priority:

=over 4

=item 1) C<stdin>

=item 2) C<--token>

=item 3) S<From file>

S<    as root:     F</etc/freedns/token>>
S<    other users: F<$HOME/.freedns_token>>

=back

=back

Any of the above can be provided as the token itself, or a file containing the
token. Your token should be considered private information (anyone who has it
can change your DNS IP), so it is recommended you put your token in an
access-restricted file.

=head1 OPTIONS

=over 4

=item B<-e --error-no-change>

FreeDNS returns error text when a dynamic DNS record is unchanged.
In some cases (e.g. cron jobs) this error is I<expected>.
By default, this script exits with code 0 even when this error comes back.

Specifying this flag makes this script exit with code 2 for this error instead.

=item B<-s --silent>

Don't print successful FreeDNS response messages.
Equivalent to C<--silent-no-change --silent-update>.
Unsuccessful messages (such as "Invalid update URL") will still print.

=item B<-se --silent-no-change>

Don't print FreeDNS response messages like C<ERROR: Address x has not changed.>

=item B<-su --silent-update>

Don't print FreeDNS response messages like C<Updated x host(s)...>

=item B<-t --token>

Use this update token.
This can be either a token, or a file containing the token.

Note: A token provided via C<stdin> takes priority over this flag.

=item B<-h --help>S<     Output this help text and exit.>

=item B<-v --version>S<  Output version and exit.>

=back

=head1 LICENSE

GPL-3.0

=cut

