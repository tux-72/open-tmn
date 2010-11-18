#!/usr/bin/perl -w

use strict;

use FindBin '$Bin';
use lib $Bin.'/../lib';
use SWConf;
use SWFunc;

my $debug = 1; 
my $DIR='';
my $PROG=$0;
my $pri=20;
my $change = 0;

if ( $PROG =~ /(\S+)\/(\S+)$/ ) {
    $DIR=$1.'/data';
    print STDERR "USE DATA DIRECTORY => $DIR\n" if $debug;
} else {
    $DIR="/usr/local/swctl/SHAPER/data";
    print STDERR "SET DATA DIRECTORY => $DIR\n";
}

my $shaper	= $DIR."/shaper.list";
my $shaperdiff	= $DIR."/shaper.list.change";
my $shapertmp	= $DIR."/shaper.list.tmp";

my %pipeold = ();

open(REAL_LIST, '/usr/bin/ssh datasync@77.239.208.17 sudo /sbin/ipfw table 10 list |' );
while (<REAL_LIST>) {
    if (/^(\d+\.\d+\.\d+\.\d+)\/32\s+(\d+)/) {
	$pipeold{$1}=$2;
    } elsif (/^(\d+\.\d+\.\d+\.\d+\/\d+)\s+(\d+)/) {
        $pipeold{$1}=$2;
    }
}
close REAL_LIST;

open(SHAPER,	"> $shaper");
open(SHAPER_DIFF,"> $shaperdiff");


my $dbm;

DB_mysql_connect(\$dbm);

my $stm = $dbm->prepare( "SELECT login, ip_subnet, inet_shape, inet_priority FROM head_link WHERE ip_subnet is not NULL order by ip_subnet" );
$stm->execute();
while (my $refm = $stm->fetchrow_hashref()) {
    if (defined($refm->{'ip_subnet'})) {
	if ( $refm->{'ip_subnet'} =~ /^77\.239\.21[01]\.\d{1,3}\/30$/ ) {
	    $refm->{'ip_subnet'} = GET_IP3($refm->{'ip_subnet'});
	}
	( $refm->{'inet_shape'}, $pri ) = PRI_calc ( $refm->{'inet_shape'}, $refm->{'inet_priority'});
	print SHAPER rspaced($refm->{'ip_subnet'},20)." ".(GET_pipeid($refm->{'inet_shape'}))."\t ".(GET_pipeid($refm->{'inet_shape'})+1)."\t".$pri."\t".($refm->{'login'}||'none')."\n";
	if (( not defined($pipeold{$refm->{'ip_subnet'}}) ) || ( $pipeold{$refm->{'ip_subnet'}}+0 != GET_pipeid($refm->{'inet_shape'})+0 ) ) {
	    $change +=1;
	    print SHAPER_DIFF "login:".($refm->{'login'}||'none').";inet_priority:".$refm->{'inet_priority'}.";inet_rate:".$refm->{'inet_shape'}.
	    ";ip_addr:".$refm->{'ip_subnet'}.";\n";
	}
    }
}
$stm->finish;

$stm = $dbm->prepare("SELECT l.login, a.ip, l.inet_shape, l.pppoe_up, l.inet_priority FROM head_link l, dhcp_addr a WHERE a.login=l.login and a.end_lease>now()" );
$stm->execute();
while (my $refd = $stm->fetchrow_hashref()) {
	( $refd->{'inet_shape'}, $pri ) = PRI_calc ( $refd->{'inet_shape'}, $refd->{'inet_priority'} );
	print SHAPER rspaced($refd->{'ip'},20)." ".(GET_pipeid($refd->{'inet_shape'}))."\t ".(GET_pipeid($refd->{'inet_shape'})+1)."\t".$pri."\tIPU_".($refd->{'login'}||'none')."\n";
	if ( $refd->{'pppoe_up'} ) {  $refd->{'inet_shape'} = 64; }
	if ( ( not defined($pipeold{$refd->{'ip'}})) || ( $pipeold{$refd->{'ip'}}+0 !=  GET_pipeid($refd->{'inet_shape'})+0 ) ) {
	    $change +=1;
	    print SHAPER_DIFF "login:IPU_".($refd->{'login'}||'none').";inet_priority:".$refd->{'inet_priority'}.";inet_rate:".$refd->{'inet_shape'}.
	    ";ip_addr:".$refd->{'ip'}.";\n";
	}
}
$stm->finish;

########################################################

close SHAPER;
close SHAPER_DIFF;

if ($change) {
    system('cat '.$shaperdiff.' | /usr/bin/ssh  datasync@77.239.208.17 /opt/dispatcher/check_shape.pl ssh');
}
rename $shaper, $shaper.".old";

