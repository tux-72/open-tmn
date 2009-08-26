#!/bin/sh

PATH=/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin

DT=`date +%Y%m%d_%H-%M`

/usr/local/cron/nagios/make_nagios.pl

CHG=`diff /usr/local/cron/nagios/config-db /usr/local/etc/nagios/config-db | wc | awk '{print $1}'`

if [ $CHG -gt 0 ]; then
    echo "NAGIOS config change"
    mv /usr/local/etc/nagios/config-db/switchnet.cfg	/usr/local/etc/nagios/backups/config-db/switchnet.cfg.${DT}
    mv /usr/local/etc/nagios/config-db/port-info.cfg	/usr/local/etc/nagios/backups/config-db/port-info.cfg.${DT}
    mv /usr/local/etc/nagios/config-db/switch-info.cfg	/usr/local/etc/nagios/backups/config-db/switch-info.cfg.${DT}

    cp -p /usr/local/cron/nagios/config-db/* /usr/local/etc/nagios/config-db

    echo "NAGIOS Reload"
    /usr/local/etc/rc.d/nagios reload
fi

/var/service/tinydns/root/0-make_dnsdata.sh
