#!/bin/sh

exit 0
tooldir=/usr/local/open-tmn/tools/sync

${tooldir}/update_dhcplist.pl

su datasync -c ${tooldir}/InetSpeed2ipfw.pl
