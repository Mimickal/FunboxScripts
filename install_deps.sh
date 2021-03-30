#!/bin/bash
# This is an "easy setup" script that installs all the crap Funbox depends on
# for our variety of nonsense to work.
# Would Docker be better? Yes. Will we use it? No.

# Version 1.0

# These are third-party Perl libraries our scripts depend on
cpan install \
	File::Find::Rule \
	Getopt::Long     \
	IPC::Run3

