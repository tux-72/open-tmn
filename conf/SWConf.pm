#!/usr/bin/perl

use strict;

package SWConf;

our $debug = 2;

our %dbconf = (
    'MYSQL_host',       'localhost',
    'MYSQL_base',       'vlancontrol',
    'MYSQL_user',       'swctl',
    'MYSQL_pass',       'GlaikMincy',
);

our %conf = (
    'def_swip'		=>	'172.20.20.200',
    'CONTROL_VLAN'	=>	1,
    'CONTROL_HOST_MAC'	=>	'00:09:3d:12:c6:58',
    'BLOCKPORT_VLAN'	=>	4094,
    'STARTPORTSTATE'	=>	1,
    'STARTPORTCONF'	=>	10,
    'STARTLINKCONF'	=>	20,
    'CLI_VLAN_LINKTYPE'	=>	21,
    'CLI_DFLT_TERM'	=>	1,
    'MAXPARENTS'	=>	10,
    'CYCLE_SLEEP'	=>	30,
    'FIRST_ZONEVLAN'	=>	4094,
    'DEF_COMUNITY'	=>	'DfA3tKlvNmEk7',
);

our %checkmac = (
    '1'		=>	'00:09:3d:12:c6:58',
    '10'	=>	'00:09:3d:12:c6:59',
    '870'	=>	'00:09:3d:12:c6:58',
    '409'	=>	'00:09:3d:12:c6:58',
);

our %conflog = (
    'LOGDFLT',     '/var/log/swctl/switch-control.log',
#    'LOGPORT',     '/var/log/swctl/change_port.log',
#    'LOGTERM',     '/var/log/swctl/change_term.log',
#    'LOGLINK',     '/var/log/swctl/change_link.log',
    'LOGDISP',     '/var/log/dispatcher/ap_ctl.log',
);

#print STDERR "Config CLI_VLAN_LINKTYPE = " , $SWConf::conf{'CLI_VLAN_LINKTYPE'}, "\n";

1;
