#!/bin/sh

/usr/local/swctl/dhcp2radius/update_dhcplist.pl

su datasync -c /usr/local/swctl/SHAPER/CheckInetSpeed.pl
