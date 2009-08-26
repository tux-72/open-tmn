#!/usr/local/bin/perl -w

use cyrillic qw/cset_factory/;
use POSIX qw(strftime);
use DBI();

my $ver = "0.4";
my $debug=0;


my $PROG=$0;
if ( $PROG =~ /(\S+)\/(\S+)$/ ) {
    require $1.'/conf/config.pl';
    print STDERR "USE PROGRAMM DIRECTORY => $1\n\n" if $debug ;
} else {
    print STDERR "USE STANDART PROGRAMM DIRECTORY\n\n";
    require '/usr/local/swctl/conf/config.pl';
}

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

my $mydata = "";
my $dberror = 0;

############################ Синхронизация справочника домов
$dbh->do("use handbook") or die "Exec Error $DBI::errstr";
$sth = $dbh->prepare("select namestreet, idstreet, namehouse, idhouse from vwhouse where idhouse>0");
die "Unable to prepare $DBI::errstr" unless defined($sth);
$sth->execute or die "Exec Error $DBI::errstr";
my %streetname = ();
my %streetid = ();
my %domname = ();
while (my $ref = $sth->fetchrow_hashref()) {
        $streetname{$ref->{'idstreet'}} = &$convert($ref->{'namestreet'});
        $domname{$ref->{'idhouse'}} = &$convert($ref->{'namehouse'});
        $streetid{$ref->{'idhouse'}} = $ref->{'idstreet'};
}
$sth->finish;

## ----------------------------------------------------------------------
foreach $nstreet (sort keys %streetname) {
        $query="INSERT into streets SET name='".$streetname{$nstreet}."', idstreet='".$nstreet."' ON DUPLICATE KEY UPDATE name='".$streetname{$nstreet}."'";
        $dbm->do($query) or die $dbh->errstr;
}

foreach $ndom (sort keys %domname) {
        $query="INSERT into houses SET street='".$streetname{$streetid{$ndom}}."', idstreet='".$streetid{$ndom}."', dom='".$domname{$ndom}."', idhouse='".$ndom."' ON DUPLICATE KEY UPDATE street='".$streetname{$streetid{$ndom}}."', idstreet='".$streetid{$ndom}."', dom='".$domname{$ndom}."'";
        $dbm->do($query) or die $dbh->errstr;
}

$dbm->disconnect;
$dbh->disconnect;
