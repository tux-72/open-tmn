#!/usr/local/bin/perl -w

use DBI;
use cyrillic qw/cset_factory/;

my $debug = 1; 
$pipeaddnum=1000;

my $PROG=$0;
if ( $PROG =~ /(\S+)\/(\S+)$/ ) {
    $DIR=$1.'/data';
    print STDERR "USE DATA DIRECTORY => $1/data\n\n" if $debug;
} else {
    $DIR="/usr/local/switch-control/SHAPER/data";
    print STDERR "SET DATA DIRECTORY => $1/data\n\n";
}
#$DIR="/usr/local/switch-control/SHAPER/data";

$ipfwcmd	= $DIR."/1reload-pipetables.sh";

$pipes		= $DIR."/pipes.list";
$priority	= $DIR."/priority.list";
$shaper		= $DIR."/shaper.list";
$shaperdiff	= $DIR."/shaper.list.change";

$shapertmp	= $DIR."/shaper.list.tmp";

########################################################
my %speedpipe = ();
my %pipe = ();
my %priority = ();
my %onlinepipe = ();

my %pipeold = ();

open(PIPES,	"> $pipes");
open(PRIORITY,	"> $priority");
open(SHAPER,	"> $shaper");
open(SHAPER_DIFF,"> $shaperdiff");


open(IPFW_CMD,		"> $ipfwcmd");

system('/usr/bin/ssh datasync@77.239.208.17 sudo /sbin/ipfw table 10 list > '.$shapertmp);

open(REAL_LIST, "$shapertmp" );

while (<REAL_LIST>) {
    if (/^(\d+\.\d+\.\d+\.\d+)\/32\s+(\d+)/) {
	$pipeold{$1}=$2;
    } elsif (/^(\d+\.\d+\.\d+\.\d+\/\d+)\s+(\d+)/) {
	$pipeold{$1}=$2;
    }
}

#while (<SHAPER_OLD>) {
#    if (/^(\d+\.\d+\.\d+\.\d+)\/\d+\s+(\d+)/) {
#	$pipeold{$1}=$2;
#    }
#}

my $dbh = DBI->connect("dbi:Sybase:server=StatServer;language=russian", "cisco", "cisco") or die "Unable to connect. $DBI::errstr";
my $mydata = "";
my $dberror = 0;

$dbh->do("set dateformat dmy set language russian set ansi_null_dflt_on on");
$dbh->func("ISO","_date_fmt");

my $sth = $dbh->prepare("exec UserCheckInetSpeed");

die "Unable to prepare $DBI::errstr" unless defined($sth);
$sth->execute or die "Exec Error $DBI::errstr";


while (my @d = $sth->fetchrow_array) {
	#my $pid=0;
	my $pri = 1;
	# d[0]	d[1]	d[2]	d[3]	d[4]		d[5]		d[6]
	# IP1	IP2	IP3	IP4	InetSpeed	IDCategory	Online
	if ( defined($d[6]) ) {
	    my $IP = $d[0].'.'.$d[1].'.'.$d[2].'.'.$d[3];
	    # нормализуем мегабиты и pipe id для скоростей после мегабита
	    $d[4] = int($d[4]/1000)*1000 if ($d[4] > 999 );
	    # нормализуем pipe id
	    #$pipe{$IP} = int(int($d[4]/100)*100/10)+$d[5]*$pipeaddnum;
	    $pipe{$IP} = int(int($d[4]/100)*100/10)+$pipeaddnum;
	    #$pipe{$IP} = int(int($d[4]/100)*100/10);
	    $pri = 3 if ($d[5]-1 > 0);
	    if ($d[4] > 3099) {
		$priority{$IP} = $pri*20+int($d[4]/1000)*5; 
	    } elsif ($d[4] > 1100) {
		$priority{$IP} = $pri*20+int($d[4]/500)*4;
	    } elsif ($d[4] > 900) {
		$priority{$IP} = $pri*20+int($d[4]/200)*3;
	    } elsif ($d[4] > 400) {
		$priority{$IP} = $pri*20+int($d[4]/100)*2;
	    } elsif ($d[4] > 200) {
		$priority{$IP} = $pri*20+int($d[4]/100)*4;
	    } else {
		$priority{$IP} = $pri*20+int($d[4]/100)*3;
	    }
	    $priority{$IP} = 90 if ($priority{$IP} > 90 );
	    $speedpipe{$pipe{$IP}} = $d[4];
	    $onlinepipe{$pipe{$IP}} += $d[6];
	    print SHAPER	$IP." ".$pipe{$IP}." ".($pipe{$IP}+1)."\n";
	    print SHAPER_DIFF	$IP." ".$pipe{$IP}." ".($pipe{$IP}+1)."\n"  if  ((not defined($pipeold{$IP})) || $pipe{$IP} != $pipeold{$IP});
#	    print PRIORITY	$IP." ".$priority{$IP}." ".$d[5]." ".$speedpipe{$pipe{$IP}}."\n";
	    print PRIORITY	$pri." ".$d[5]." ".$speedpipe{$pipe{$IP}}." ".$priority{$IP}." ".$IP."\n";
	}
}

print IPFW_CMD '#!/bin/sh'."\n\n".'fwcmd="/sbin/ipfw"'."\n\n";

foreach $pipe (sort keys %speedpipe) {
    print PIPES $pipe." ".$speedpipe{$pipe}."\n";
    my $pipeout= $pipe+1;
    print IPFW_CMD '#${fwcmd} pipe '.$pipe.' delete; ${fwcmd} pipe '.$pipeout.' delete'."\n".
    '${fwcmd} pipe '.$pipe.' config buckets 512 mask dst-ip 0xffffffff bw '.$speedpipe{$pipe}.'Kbit queue 100 gred 0.002/10/30/0.1'."\n".
    '${fwcmd} pipe '.$pipeout.' config buckets 512 mask src-ip 0xffffffff bw '.$speedpipe{$pipe}.'Kbit queue 100 gred 0.002/10/30/0.1'."\n";
}
print IPFW_CMD "\n".'. /etc/SHAPER/0ch_shaper_tables.sh'."\n";

close SHAPER;
close SHAPER_DIFF;
close PRIORITY;
close IPFW_CMD;

chmod 0755, "$ipfwcmd";

system('/usr/bin/scp '.$shaper.' '.$shaperdiff.' '.$ipfwcmd.' datasync@77.239.208.17:/etc/SHAPER');
system('/usr/bin/ssh datasync@77.239.208.17 sudo /etc/SHAPER/1reload-pipetables.sh');

rename $pipes,	 $pipes.".old";
rename $shaper,	 $shaper.".old";
rename $priority,$priority.".old";
