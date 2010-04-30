#!/usr/bin/perl -w


use strict;

use FindBin '$Bin';
use lib $Bin.'/../lib';
use SWConf;
use SWFunc;

my $debug = 0;
my %AP = ();
my $dbm;

### GET DATA from PPPoE terminator
#my @ln = IOS_rsh( HOST => '192.168.100.12', CMD => 'sh users', REMOTE_USER => 'admin', LOCAL_USER => 'root' );
my @ln = `/usr/bin/rsh -l admin 192.168.100.12 show users`;
foreach (@ln) {
	#  Vi1489  kogytumdery PPPoE        00:00:00 10.13.72.70
	if ( /Vi\d+\s+(\S+)\s+PPPoE\s+\S+\s+(\d{1,3}\.\d{1,3}\.)(\d{1,3}\.\d{1,3})/ and $2 eq '10.13.' ) {
	    $AP{$1} = 1;
	}
}
undef @ln;

#__END__

### Sync data to DHCP DB
DB_mysql_connect(\$dbm);
my $stm = $dbm->prepare("SELECT login FROM head_link WHERE head_id=3 and pppoe_up=1");
$stm->execute();
while (my $refm = $stm->fetchrow_hashref()) {
    if ( not defined($AP{$refm->{'login'}}) ) {
	my $Q_up = "UPDATE head_link SET pppoe_up=0 WHERE head_id=3 and login='".$refm->{'login'}."'" ;
	print $Q_up."\n" if $debug;
	$dbm->do($Q_up) if not $debug;
    }
}
$stm->finish;

$stm = $dbm->prepare("SELECT login FROM head_link WHERE head_id=3 and pppoe_up=0");
$stm->execute();
while (my $refm = $stm->fetchrow_hashref()) {
    if ( defined($AP{$refm->{'login'}}) ) {
	my $Q_up = "UPDATE head_link SET pppoe_up=1 WHERE head_id=3 and login='".$refm->{'login'}."'" ;
	print $Q_up."\n" if $debug;
	$dbm->do($Q_up) if not $debug;
    }
}
$stm->finish;
