#!/bin/bash
#################################################
# Donut Feb 03, 2016
#
# Sets up iptables rules to completely block
# traffic from any ip listed in the files in
# the BLOCKDIR directory
#
# Because we're really fucking sick of 20,000+
# daily hacking attempts from China
################################################

VERSION=1

BLOCKDIR='/etc/blocked-ips'
LISTNAME='blocked-ips'
REASON="Block Script"

# Clear out old rules, otherwise these get appended
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -t raw -F
iptables -t raw -X

# Add all the IPs to an iptables list
echo "Beginning mass IP block"
iptables -N $LISTNAME
for file in $BLOCKDIR/*
do
	cat $file | while read ip
	do
		printf .
#		iptables -A $LISTNAME -s $ip -j LOG --log-prefix "$REASON"
		iptables -A $LISTNAME -s $ip -j DROP
	done;
done;

# Now block everything
iptables -I INPUT -j $LISTNAME
iptables -I OUTPUT -j $LISTNAME
iptables -I FORWARD -j $LISTNAME

exit 0;

