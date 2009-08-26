#!/bin/sh

PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin

IDX=1
MAXIDX=600
COMUNITY="DfA3tKlvNmEk7"
file="/usr/local/cron/nagios/generic.cfg"
file1="/usr/local/cron/nagios/generic1.cfg"

cat $file1 > $file

while [ $IDX -lt $MAXIDX ]; do
    echo "define command {" >> $file
    echo "	command_name    SNMP-${IDX}" >> $file
    echo "	command_line    \$USER1\$/check_snmp -H \$HOSTADDRESS\$ -o 1.3.6.1.2.1.2.2.1.8.${IDX} -c 1 -C ${COMUNITY}" >> $file
    echo "}" >> $file
    echo  >> $file

    IDX=$(($IDX+1))
done