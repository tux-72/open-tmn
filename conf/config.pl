#!/usr/local/bin/perl -w 

%conf = (
    'def_swip',	'172.20.20.200',
    'CONTROL_VLAN',	1,
    'STARTPORTSTATE',	1,
    'STARTPORTCONF',	10,
    'STARTLINKCONF',	20,
    'CLI_VLAN_LINKTYPE',21,
    'CLI_DFLT_TERM',	1,
    'MAXPARENTS',	7,
    'MYSQL_host',	'localhost',
    'MYSQL_base',	'switchnet',
    'MYSQL_user',	'swgen',
    'MYSQL_pass',	'SWgeneRatE',

    'MSSQL_host',	'StatServer',
    'MSSQL_base',	'inet',
    'MSSQL_user',	'cisco',
    'MSSQL_pass',	'cisco',

#    '',		,
);

use lib '/usr/local/swctl/lib';
use C73Ctl;
use CATIOSCtl;
use CAT2950Ctl;
#use CAT3508GCtl;
use CATOSCtl;
use DESCtl;
use ESCtl;
use GSCtl;
use BPSCtl;
use TCOM4500Ctl;
