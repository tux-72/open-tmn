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

if ( $PROG =~ /(\S+)\/(\S+)$/ ) {
    $DIR=$1.'/data';
    print STDERR "USE DATA DIRECTORY => $DIR\n" if $debug;
} else {
    $DIR="/usr/local/swctl/SHAPER/data";
    print STDERR "SET DATA DIRECTORY => $DIR\n";
}

my $shaper	= $DIR."/shaper.list";
my $shaperdiff	= $DIR."/shaper.list.diff";
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

my %pipeid = (
    '128'	=> 1010,
    '256'	=> 1020,
    '512'	=> 1050,
    '1000'	=> 1100,
    '2000'	=> 1200,
    '3000'	=> 1300,
    '4000'	=> 1400,
    '5000'	=> 1500,
    '6000'	=> 1600,
    '7000'	=> 1700,
    '8000'	=> 1800,
    '9000'	=> 1900,
    '10000'	=> 2000,
);

my %pipespeed = (
    '1010'	=> 128,
    '1020'	=> 256,
    '1050'	=> 512,
    '1100'	=> 1000,
    '1200'	=> 2000,
    '1300'	=> 3000,
    '1400'	=> 4000,
    '1500'	=> 5000,
    '1600'	=> 6000,
    '1700'	=> 7000,
    '1800'	=> 8000,
    '1900'	=> 9000,
    '2000'	=> 10000,
);

my $dbm;

DB_mysql_connect(\$dbm);

my $stm = $dbm->prepare( "SELECT login, ip_subnet, inet_shape, inet_priority FROM head_link WHERE ip_subnet is not NULL order by ip_subnet" );
$stm->execute();
while (my $refm = $stm->fetchrow_hashref()) {
    if (defined($refm->{'ip_subnet'})) {
	if ( $refm->{'ip_subnet'} =~ /^77\.239\.21[01]\.\d{1,3}\/30$/ ) {
	    $refm->{'ip_subnet'} = GET_IP3($refm->{'ip_subnet'});
	}
	($refm->{'inet_shape'}, $pri ) = PRI_CALC ( $refm->{'inet_shape'}, $refm->{'inet_priority'});
	print SHAPER rspaced($refm->{'ip_subnet'},20)." ".$pipeid{$refm->{'inet_shape'}}."\t ".($pipeid{$refm->{'inet_shape'}}+1)."\t".$pri."\t".($refm->{'login'}||'none')."\n";
	if (( not defined($pipeold{$refm->{'ip_subnet'}}) ) || ( $pipeold{$refm->{'ip_subnet'}}+0 != $pipeid{$refm->{'inet_shape'}}+0 ) ) {
	    # inet_priority = 1, ip_addr = 10.13.48.114, inet_rate = 2000, login = yuriy
	    print SHAPER_DIFF "login:".($refm->{'login'}||'none').";inet_priority:".$refm->{'inet_priority'}.";inet_rate:".$refm->{'inet_shape'}.
	    ";ip_addr:".$refm->{'ip_subnet'}.";\n";
	}
    }
}
$stm->finish;

$stm = $dbm->prepare("SELECT l.login, a.ip, l.inet_shape, l.inet_priority FROM head_link l, dhcp_addr a WHERE a.login=l.login and a.end_lease>now()" );
$stm->execute();
while (my $refd = $stm->fetchrow_hashref()) {
    if ( defined($refd->{'ip'}) ) {
	($refd->{'inet_shape'}, $pri ) = PRI_CALC ( $refd->{'inet_shape'}, $refd->{'inet_priority'});
	print SHAPER rspaced($refd->{'ip'},20)." ".$pipeid{$refd->{'inet_shape'}}."\t ".($pipeid{$refd->{'inet_shape'}}+1)."\t".$pri."\tIPUnnum_".($refd->{'login'}||'none')."\n";
	if ( ( not defined($pipeold{$refd->{'ip'}})) || ( $pipeold{$refd->{'ip'}}+0 !=  $pipeid{$refd->{'inet_shape'}}+0 ) ) {
	    # inet_priority = 1, ip_addr = 10.13.48.114, inet_rate = 2000, login = yuriy
	    print SHAPER_DIFF "login:IPUnnum_".($refd->{'login'}||'none').";inet_priority:".$refd->{'inet_priority'}.";inet_rate:".$refd->{'inet_shape'}.
	    ";ip_addr:".$refd->{'ip'}.";\n";
	}
    }
}
$stm->finish;

########################################################

close SHAPER;
close SHAPER_DIFF;

system('cat '.$shaperdiff.' | /usr/bin/ssh  datasync@77.239.208.17 /opt/dispatcher/check_shape.pl ssh');

rename $shaper, $shaper.".old";

sub GET_IP3 {
    my $subip3 = shift;
    my @ln = `/usr/local/bin/ipcalc $subip3`;
    foreach (@ln) {
        if ( /HostMax\:\s+(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\s+/ ) {
            #dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Change '".$subip3."' to '$1.$2.$3.$4'" );
            $subip3 = "$1.$2.$3.$4";
        }
    }
    return $subip3;
}

sub PRI_CALC {
    my $rate = shift;
    my $pri  = shift;
    my $priority = 20;
    # Normalise megabits for rate > 999 Kbits
    $rate = int($rate/1000)*1000 if ($rate > 999 );

    if ($rate > 3100)      {
        $priority = $pri*20+int($rate/1000)*5;
    } elsif ($rate > 1100) {
        $priority = $pri*20+int($rate/500)*4;
    } elsif ($rate > 900)  {
        $priority = $pri*20+int($rate/200)*3;
    } elsif ($rate > 400)  {
        $priority = $pri*20+int($rate/100)*2;
    } elsif ($rate > 200)  {
        $priority = $pri*20+int($rate/100)*4;
    } else {
        $priority = $pri*20+int($rate/100)*3;
    }
    $priority   = 80 if ($priority > 80 );
    return ($rate, $priority)
}

