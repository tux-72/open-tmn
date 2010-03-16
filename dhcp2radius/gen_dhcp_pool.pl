#!/usr/bin/perl -w


use strict;
use DBI;


my %conf = (
    'MYSQL_host'	=> 'localhost',
    'MYSQL_base'	=> 'vlancontrol',
    'MYSQL_user'	=> 'swctl',
    'MYSQL_pass'	=> 'GlaikMincy',
);

my $dbm; my $res = DB_mysql_connect(\$dbm, \%conf);
if ($res < 1) {
    #dlog ( SUB => (caller(0))[3], DBUG => 0, LOGTYPE => 'LOGRADIUS', MESS => "Connect to MYSQL DB FAILED, RESULT = $res" );
    DB_mysql_check_connect(\$dbm, \%conf);
}

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

$pool{'pool_id'}=3;
$pool{'start_ip'}="10.32.0.2";
$pool{'end_ip'}="10.32.15.254";
gen_pool();


sub gen_pool {
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


sub DB_mysql_connect {
    $dbm = DBI->connect_cached("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'})
    or die dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MYSQL DB host ".$conf{'MYSQL_host'}."$DBI::errstr" );
    $dbm->do("SET NAMES 'koi8r'") or die return -1;
    return 1;
}


sub DB_mysql_check_connect {
    my $db_ping = $dbm->ping;
    #dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DB PING = $db_ping" );
    if ( $db_ping != 1 ) {
        dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DB PING = $db_ping, MYSQL connect lost! RECONNECT to DB host ".$conf{'MYSQL_host'} );
        $dbm->disconnect;
        $dbm = DBI->connect_cached("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'})
        or dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MYSQL DB host ".$conf{'MYSQL_host'}."$DBI::errstr" );
        $dbm->do("SET NAMES 'koi8r'");
    }
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

