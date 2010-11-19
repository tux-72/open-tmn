#!/usr/bin/perl -w

use strict;

use FindBin '$Bin';
use lib $Bin.'/../../lib';
use SWConf;
use SWFunc;

my $debug = 1;

my $nas_conf = \%SWConf::aaa_conf;

my %AP = ();
my $dbm;

### GET DATA from PPPoE terminator
#my @ln = IOS_rsh( HOST => $nas_conf->{'pppoe_server'}, CMD => 'sh users', REMOTE_USER => 'admin', LOCAL_USER => 'root' );
my @ln = `/usr/bin/rsh -l admin $nas_conf->{'pppoe_server'} show users`;
foreach (@ln) {
	#  Vi1489  user1 PPPoE        00:00:00 10.10.1.2
	if ( /Vi\d+\s+(\S+)\s+PPPoE\s+\S+\s+(\d{1,3}\.\d{1,3}\.)(\d{1,3}\.\d{1,3})/ ) {
	    print $_ if $debug > 1;
	    $AP{$1} = 1;
	}
}
undef @ln;

### Sync data to DHCP DB
DB_mysql_connect(\$dbm);

### Clear oblosete RRRoE session Flag
my $stm = $dbm->prepare("SELECT login FROM head_link WHERE head_id=".$nas_conf->{'DHCP_HEAD_ID'}." and pppoe_up=1");
$stm->execute();
while (my $refm = $stm->fetchrow_hashref()) {
    if ( not defined($AP{$refm->{'login'}}) ) {
	my $Q_up = "UPDATE head_link SET pppoe_up=0 WHERE head_id=".$nas_conf->{'DHCP_HEAD_ID'}." and login='".$refm->{'login'}."'" ;
	print $Q_up."\n" if $debug;
	$dbm->do($Q_up) if $debug < 2;
    }
}
$stm->finish;

### SET current RRRoE session Flag
$stm = $dbm->prepare("SELECT login FROM head_link WHERE head_id=".$nas_conf->{'DHCP_HEAD_ID'}." and pppoe_up=0");
$stm->execute();
while (my $refm = $stm->fetchrow_hashref()) {
    if ( defined($AP{$refm->{'login'}}) ) {
	my $Q_up = "UPDATE head_link SET pppoe_up=1 WHERE head_id=".$nas_conf->{'DHCP_HEAD_ID'}." and login='".$refm->{'login'}."'" ;
	print $Q_up."\n" if $debug;
	$dbm->do($Q_up) if $debug < 2;
    }
}
$stm->finish;
