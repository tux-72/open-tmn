#!/usr/bin/perl -w

use cyrillic qw/cset_factory/;
use POSIX qw(strftime);
use DBI();

my $ver = "0.4";
my $debug=0;


use FindBin '$Bin';
require $Bin . '/../conf/config.pl';
require $Bin . '/../conf/libsw.pl';

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
dlog ( SUB => $script_name, DBUG => 1, MESS => "Use BIN directory - $Bin" );

my $dbm = DBI->connect("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'}) or die("connect");
$dbm->do("SET NAMES 'koi8r'");

### MSSQL Connect
my $dbh = DBI->connect("dbi:Sybase:server=".$conf{'MSSQL_host'}.";language=russian", $conf{'MSSQL_user'},$conf{'MSSQL_pass'}) or die "Unable to connect. $DBI::errstr";
$dbh->do("set dateformat ymd set language russian set ansi_null_dflt_on on");
$dbh->func("ISO","_date_fmt");

my %link_type = ();
#my @link_types = '';
$sth0 = $dbm->prepare("SELECT id, name FROM link_types order by id");
$sth0->execute();
while (my $ref0 = $sth0->fetchrow_hashref()) {
    $link_type{$ref0->{'name'}}=$ref0->{'id'} if defined($ref0->{'name'});
#    $link_types[$ref0->{'id'}]=$ref0->{'name'} if defined($ref0->{'name'});
}
$sth0->finish();

my $convert = cset_factory 1251, 20866;
my $convert2 = cset_factory 20866, 1251;

############################ Освобождeние AP
$dbh->do("use usersnet") or die "Exec Error $DBI::errstr";
$sthap = $dbh->prepare("SELECT IdModem FROM InfoModem WHERE FlagClose=1");
die "Unable to prepare $DBI::errstr" unless defined($sthap);
$sthap->execute or die "Exec Error $DBI::errstr";

my %apclose = ();
while (my $refap = $sthap->fetchrow_hashref()) {
    $apclose{$refap->{'IdModem'}} = 1;
}
$sthap->finish;

foreach $ap (sort keys %apclose) {
        $query1 ="UPDATE swports SET autoconf=".$link_type{'free'}." WHERE port_id=".$ap." and link_type>".$conf{'STARTLINKCONF'}." and autoconf<".$conf{'STARTPORTCONF'};
        $query2="UPDATE InfoModem SET FlagClose=0 WHERE IdModem=".$ap;
    if ($debug) {
        dlog ( DBUG => 1, SUB => 'Sync_FREE_AP', MESS => $query1 );
        dlog ( DBUG => 1, SUB => 'Sync_FREE_AP', MESS => $query2 );
    } else {
        dlog ( DBUG => 0, SUB => 'Sync_FREE_AP', MESS => $query1 );
	$dbm->do($query1) or die $dbm->errstr; # Отмечаем порт для освобождения
	$dbh->do($query2) or die $dbh->errstr;	# подтверждаем обработку порта
        dlog ( DBUG => 0, SUB => 'Sync_FREE_AP', MESS => "Closed AP, id N'".$ap."'" );
    }
}

### Синхронизация таблиц коммутаторов
$stmsw = $dbm->prepare("SELECT id, hostname, idhouse FROM hosts WHERE model>0");
die "Unable to prepare $DBI::errstr" unless defined($stmsw);
$stmsw->execute or die "Exec Error $DBI::errstr";

my %swname = ();
my %house = ();
while (my $refsw = $stmsw->fetchrow_hashref()) {
        $swname{$refsw->{'id'}} = &$convert2($refsw->{'hostname'});
        $house{$refsw->{'id'}} = $refsw->{'idhouse'};
}
$stmsw->finish;

foreach $swid (sort keys %swname) {
    $query = "EXECUTE AddUpdateSwitch \@vidswitch=".$swid.", \@vhostname='".$swname{$swid}."', \@vidhouse=".$house{$swid};
    $dbh->do($query) || die $dbh->errstr; # Обновляем инфу о свиче
}

############################ Sync TransportNet State #####
$dbh->do("set dateformat dmy set language russian set ansi_null_dflt_on on");
$dbh->func("ISO","_date_fmt");

dlog ( DBUG => 2, SUB => 'Sync_TransportNet_state', MESS => ">>> -- GET DATA from Billing --" );

my %trsubnet = (); my $subip = '';
my $sth = $dbh->prepare(&$convert2("SELECT ip1, ip2, ip3, ip4, Active FROM vwTransportNetState"));
die "Unable to prepare $DBI::errstr" unless defined($sth);
$sth->execute or die "Exec Error $DBI::errstr";
while (my $trnet = $sth->fetchrow_hashref()) {
    next if $trnet->{'ip1'} == 10;
    $subip = $trnet->{'ip1'}.".".$trnet->{'ip2'}.".".$trnet->{'ip3'}.".".$trnet->{'ip4'}."/30";
    dlog ( DBUG => 2, SUB => 'Sync_TransportNet_state', MESS => "$subip -> ".$trnet->{'Active'} );
    $subip = GET_IP3 ($subip);
    $trsubnet{$subip} = 2 if ( $trnet->{'Active'} == 0);
    $trsubnet{$subip} = 1 if ( $trnet->{'Active'} == 1);
}
$sth->finish;


dlog ( DBUG => 2, SUB => 'Sync_TransportNet_state', MESS => ">>> -- GET DATA from Hardware --" );
my %trnet_real = (); $hw_subip = '';
$stm24 = $dbm->prepare("SELECT port_id, status, set_status, ip_subnet FROM head_link where head_id=4 order by ip_subnet");
die "Unable to prepare $DBI::errstr" unless defined($stm24);
$stm24->execute or die "Exec Error $DBI::errstr";
while (my $ip_sub = $stm24->fetchrow_hashref()) {
    $hw_subip = GET_IP3($ip_sub->{'ip_subnet'});

    if ( defined($trsubnet{$hw_subip}) and ( $ip_sub->{'status'} ne $trsubnet{$hw_subip})) {
	my $Querry_24 =  "UPDATE head_link SET set_status=".$trsubnet{$hw_subip}." WHERE port_id=".$ip_sub->{'port_id'};
	$dbm->do($Querry_24) || die $dbm->errstr;
	dlog ( DBUG => 0, SUB => 'Sync_TransportNet_state', MESS => $Querry_24 );
    } elsif (not defined($trsubnet{$hw_subip})) {
	dlog ( DBUG => 0, SUB => 'Sync_TransportNet_state', MESS => "Transport_net ".$hw_subip." Not defined in Billing!!!" );
    }
    $trnet_real{$hw_subip} = $ip_sub->{'status'};
}
$stm24->finish;

foreach my $net (sort(keys %trsubnet)) {
	dlog ( DBUG => 0, SUB => 'Sync_TransportNet_state', MESS => "Transport_net $net not configured in Hardware!!!\n" ) if ( not defined($trnet_real{$net}) );
}

$dbm->disconnect;
$dbh->disconnect;


sub GET_IP3 {
    $subip3 = shift;
    my @ln = `/usr/local/bin/ipcalc $subip3`;
    foreach (@ln) {
        #if ( /HostMax\:\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+/ and ( $subip3 ne $1."/30") ) {
        if ( /HostMax\:\s+(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\s+/ and  $subip3 ne "$1.$2.$3.$4".'/30' and  $3 < 212 and $1 > 10 ) {
	    dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Change '".$subip3."' to '$1.$2.$3.$4'/30'" );
	    $subip3 = "$1.$2.$3.$4".'/30';
        }
    }
    return $subip3;
}

