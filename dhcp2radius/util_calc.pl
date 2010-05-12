#!/usr/bin/perl -w


use strict;

use FindBin '$Bin';
use lib $Bin.'/../lib';
use SWConf;
use SWFunc;

my $onlyfiz = 1;

$onlyfiz = 0 if ( $ARGV[0] eq 'all' );
#########################

my %AP = ();
my $dbm;

DB_mysql_connect(\$dbm);
my @speed = ( 512, 1000, 2000, 3000, 4000, 5000 );
foreach my $inet_speed ( @speed ) {
    my $stm = $dbm->prepare("SELECT COUNT(*) as users FROM head_link WHERE head_id=3 and inet_shape=".$inet_speed );
    $stm->execute();
    while (my $refm = $stm->fetchrow_hashref()) {
	print "Speed = ".$inet_speed.", users = ".$refm->{'users'}."\n";
    }
    $stm->finish;
}

my $IPUnnum_vlans = '10,33';
my $prev_vlan = '';
my $range = 0;

my $Query = "SELECT distinct vlan_id FROM head_link WHERE communal=0 and head_id=3";
$Query .= " and inet_priority=1" if $onlyfiz ;
$Query .= " order by vlan_id";

my $stm1 = $dbm->prepare($Query);
$stm1->execute();
while (my $ref1 = $stm1->fetchrow_hashref()) {
    if ( $prev_vlan ) {
	if ( $prev_vlan+1 == $ref1->{'vlan_id'}+0 ) {
	    if (not $range ) {
		$IPUnnum_vlans .= ",".$prev_vlan;
	    }
	    $range += 1;
	} else {
	    if ( $range > 1 ) {
		$IPUnnum_vlans .= "-".$prev_vlan;
	    } else  {
		if ( $IPUnnum_vlans ) {
		    $IPUnnum_vlans .= ",".$prev_vlan;
		} else {
		    $IPUnnum_vlans .= $prev_vlan;
		}
	    }
	    $range = 0;
	}
    }
	 $prev_vlan = $ref1->{'vlan_id'};

}
if ( $range > 1 ) {
    $IPUnnum_vlans .= "-".$prev_vlan;
} else {
    $IPUnnum_vlans .= ",".$prev_vlan;
}
$stm1->finish;


print "IPUnnum_vlans:\n".$IPUnnum_vlans."\n";
