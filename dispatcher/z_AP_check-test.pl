#!/usr/bin/perl -w


my $debug=1;

$VERSION = 0.1;

#use strict;

use FindBin '$Bin';
require $Bin . '/../conf/libap.pl';

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
print STDERR  "Use BIN directory - $Bin\n";


my %param = (
    'login' 		=> 'pppoe',
    'ap_id'		=> 1234,
    'mac' 		=> '0017.3156.7fd9',
    'nas_ip' 		=> '192.168.100.12',
    'ip_addr' 		=> '10.13.64.3',
    'port_rate_ds' 	=> 10000,
    'port_rate_us' 	=> 10000,
    'inet_rate' 	=> 1000,
);

my ($ap_res, $ap_val) = SW_AP_get (\%param);

print STDERR "Result = '$ap_res', VALUE = '$ap_val' \n";

#return ($ap_res, $ap_val);

