#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';

our $VERSION = '1.0';

my $running = grep { $_ =~ /deluged/ } split(/\n/, `ps x`);
say('Deluge daemon is ' . ($running ? "\e[32m" : "\e[33mNOT ") . "running\e[0m");

