#!/usr/bin/perl -w


use strict;
use DBI;

use FindBin '$Bin';
use lib $Bin.'/../lib';
use SWConf;
use SWFunc;

my $dbm; 

my $debug=0;

my $Q_addip = '';
my %pool = ();

#$pool{'pool_id'}=1;
#$pool{'start_ip'}="77.239.208.130";
#$pool{'end_ip'}="77.239.208.254";
#gen_pool();

#$pool{'pool_id'}=2;
#$pool{'start_ip'}="77.239.216.2";
#$pool{'end_ip'}="77.239.223.254";
#gen_pool();

## For blocked users
$pool{'pool_id'}=101;
$pool{'start_ip'}="10.32.240.0";
$pool{'end_ip'}="10.32.255.254";
gen_pool();

sub gen_pool {
    DB_mysql_connect(\$dbm);
    my $current_ip=$pool{'start_ip'};
    my $end_ip = ip_inc($pool{'end_ip'});
    while ( $current_ip ne $end_ip ) {
	$Q_addip = "INSERT INTO dhcp_addr SET pool_id=".$pool{'pool_id'}.", ip='".$current_ip."'";
	$Q_addip .= " ON DUPLICATE KEY UPDATE pool_id=".$pool{'pool_id'};
	print $Q_addip."\n" if $debug;
	$dbm->do($Q_addip) if not $debug;
	$current_ip = ip_inc($current_ip);
    }
}

sub ip_inc {
    my $ip = shift;
    my $i = 1 + unpack("N", pack("C4", split( /\./, $ip)));
    my (@d);
    $d[0]=int($i/256/256/256);
    $d[1]=int(($i-$d[0]*256*256*256)/256/256);
    $d[2]=int(($i-$d[0]*256*256*256-$d[1]*256*256)/256);
    $d[3]=int($i-$d[0]*256*256*256-$d[1]*256*256-$d[2]*256);
    return "$d[0].$d[1].$d[2].$d[3]";
}

#*******************************************************************
# Convert integer value to ip
# int2ip($i);
#*******************************************************************
sub int2ip {
my $i = shift;
my (@d);
$d[0]=int($i/256/256/256);
$d[1]=int(($i-$d[0]*256*256*256)/256/256);
$d[2]=int(($i-$d[0]*256*256*256-$d[1]*256*256)/256);
$d[3]=int($i-$d[0]*256*256*256-$d[1]*256*256-$d[2]*256);
 return "$d[0].$d[1].$d[2].$d[3]";
}


#*******************************************************************
# Convert ip to int
# ip2int($ip);
#*******************************************************************
sub ip2int($){
  my $ip = shift;
  return unpack("N", pack("C4", split( /\./, $ip)));
}

