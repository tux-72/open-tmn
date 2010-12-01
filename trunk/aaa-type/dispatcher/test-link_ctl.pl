#!/usr/bin/perl -w


my $debug=1;

$VERSION = 0.1;

use strict;
no strict qw(refs);

use FindBin '$Bin';
use lib $Bin.'/../../lib';

use SWConf;
use SWFunc;
use SWFuncAAA;
use SWFuncDisp;

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
#print STDERR  "Use BIN directory - $Bin\n";

my ($ap_res, $ap_val);

#my $check_sub = 'ap_link_state';
#my $check_sub = 'ap_free';
#my $check_sub = 'ap_tune';
my $check_sub = 'ap_get';

if ($check_sub eq 'ap_tune') {
  my %param = (
    'ap_id'		=> '4577',
    'port_rate_ds' 	=> '10000',
    'port_rate_us' 	=> '10000',
  );
  ($ap_res, $ap_val) = SW_AP_tune (\%param);

} elsif ($check_sub eq 'ap_get') {
  my %param = (
    'ap_id'		=> '4825',
    'inet_priority'	=> 1,
    'ip_addr' 		=> '10.13.100.1',
    'nas_ip' 		=> '192.168.100.12',
    'inet_rate' 	=> '2000',
    'vlan_id'		=> '',
    'login' 		=> 'comtest1',
    'link_type'		=> '21',
    'port_rate_ds' 	=> '5000',
    'port_rate_us' 	=> '1000',
    'mac' 		=> '0017.3156.7fd9',
#    'mac' 		=> '0021.913f.d52f',
#    'mac' 		=> '00e0.4c02.4ecf',
  );
  ($ap_res, $ap_val) = SW_AP_get (\%param);

} elsif ($check_sub eq 'ap_link_state') {

  my %param = (
    'ap_id'		=> '34',
    'state' 		=> 'unlock',
  );

  ($ap_res, $ap_val) = SW_AP_linkstate (\%param);

} elsif ($check_sub eq 'ap_free') {

  my %param = (
    'ap_id'		=> '4577',
  );

  ($ap_res, $ap_val) = SW_AP_free (\%param);

}

print STDERR "Result = '$ap_res', VALUE = '$ap_val' \n";

#return ($ap_res, $ap_val);

