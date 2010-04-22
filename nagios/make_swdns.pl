#!/usr/bin/perl

use strict;
use POSIX qw(strftime);
use DBI();

my $DB_host='192.168.29.20';
my $DB_base='vlancontrol';
my $DB_user='swgen';
my $DB_pass='SWgeneRatE';

#my $dbhost="localhost";

my $fconfig = "/var/service/tinydns/root/sw-net.data";
open (CNFG, "> $fconfig");

my $dbh = DBI->connect("DBI:mysql:database=".$DB_base.";host=".$DB_host,$DB_user,$DB_pass) or die("connect");
$dbh->do("SET NAMES 'koi8r'");

my $sth = $dbh->prepare("SELECT hostname, ip FROM hosts ORDER BY ip");
$sth->execute();
#my %hosts = ();
while (my $ref = $sth->fetchrow_hashref()) {
    #$hosts{$ref->{'ip'}} = $ref->{'hostname'};
    #=dhcp-1-net128.sw:192.168.128.1:86400
    print CNFG "=".$ref->{'hostname'}.".sw:".$ref->{'ip'}.":86400\n";
}

close CNFG;

$sth->finish();
$dbh->disconnect();

print "SWITCH DNS zone BUILD complete\n";

