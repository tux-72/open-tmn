#!/usr/bin/perl

use strict;

package SWConf;

our $debug = 1;

our %dbconf = (
    'MYSQL_host'        => 'localhost',
    'MYSQL_base'        => 'vlancontrol',
    'MYSQL_user'        => 'swctl',
    'MYSQL_pass'        => 'GlaikMincy',

    'MSSQL_server'      => 'BILLING',
    'MSSQL_base'        => 'UsersNet',
    'MSSQL_user'        => 'cisco',
    'MSSQL_pass'        => 'cisco',
);

our %aaa_conf = (
    'FAKE_QUOTE'        => 600,
    'FAKE_DNS'          => '77.239.208.22',
    'DNS_IP1'           => '77.239.208.17',
    'DNS_IP2'           => '77.239.208.5',
    'mail_server'       => 'MAIL18',
    'pppoe_server'      => '192.168.100.12',
    'pod_port'          => 1700,
    'pod_secret'        => 'secret',

    'DHCP_HEAD_ID'      => 3,
    'DHCP_USE'          => 1,
    'DHCP_PRI'          => 1,
    'DHCP_WINDOW'       => 3600,
    'DHCP_POOLTYPE'     => 2,

    'DHCP_ACCOUNT'      => 0,
    'DHCP_NAS_IP'       => '192.168.100.20',
    'DHCP_ACC_HOST'     => '192.168.100.20',
    'DHCP_ACC_PORT'     => 1813,
    'DHCP_ACC_SECRET'   => 'DirWupEw123',
    'DHCP_ACC_USERPREF' => 'DHCP-',

);

our %conf = (

    'def_swip'          => '172.20.20.200',
    'BLOCKPORT_VLAN'    => 4094,
    'STARTPORTCONF'     => 10,
    'STARTLINKCONF'     => 20,
    'CLI_VLAN_LINKTYPE' => 21,
    'MAXPARENTS'        => 10,
    'CYCLE_SLEEP'       => 30,
    'FIRST_ZONEVLAN'    => 4094,
    'DEF_COMUNITY'      => 'DfA3tKlvNmEk7',
    'CHECK_PPPOE_UP'    => 0,

);

our %conflog = (
    'LOGDFLT'           => '/var/log/swctl/switch-control.log',
    'LOGDISP'           => '/var/log/swctl/ap_ctl.log',
    'LOGAPFIX'          => '/var/log/swctl/ap_fix.log',
);

1;
