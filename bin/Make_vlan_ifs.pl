#!/usr/bin/perl

$debug=0;
my $ver='0.5';
#$VERSION = 0.97;

use Getopt::Long;

#use strict;
use Net::SNMP;
use POSIX qw(strftime);
use DBI();
use locale;

use FindBin '$Bin';
require $Bin . '/../conf/config.pl';
require $Bin . '/../conf/lib.pl';

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
dlog ( SUB => $script_name, DBUG => 1, MESS => "Use BIN directory - $Bin" );


my $dbm = DBI->connect_cached("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'}) or die("connect");
$dbm->do("SET NAMES 'koi8r'");

my %libs = ();
$stm0 = $dbm->prepare("SELECT id, lib FROM models order by id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $libs{$ref0->{'lib'}}=$ref0->{'id'} if defined($ref0->{'lib'});
#    $libctl= "$ref0->{'lib'}Ctl";
}
$stm0->finish();

my %port_status = ();
$stm0 = $dbm->prepare("SELECT id, name FROM port_status order by id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $port_status{$ref0->{'name'}}=$ref0->{'id'} if defined($ref0->{'name'});
}
$stm0->finish();

my %link_type = ();
my @link_types = '';

$stm0 = $dbm->prepare("SELECT id, name FROM link_types order by id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $link_type{$ref0->{'name'}}=$ref0->{'id'} if defined($ref0->{'name'});
    $link_types[$ref0->{'id'}]=$ref0->{'name'} if defined($ref0->{'name'});
}
$stm0->finish();

my @sw_models = '';
my %sw_descr = ();
$stm0 = $dbm->prepare("SELECT id, model, sysdescr FROM models order by id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $sw_models[$ref0->{'id'}]		= $ref0->{'model'}	if defined($ref0->{'model'});
    $sw_descr{$ref0->{'sysdescr'}}	= $ref0->{'id'}		if defined($ref0->{'sysdescr'});
}
$stm0->finish();


my %SW = (
 'type',	'',
 'sw_id',	0,
 'swip',	'',
 'admin',	'admin',
 'adminpass',	'pass',
 'monlogin',	'swmon',
 'monpass',	'monpass',
 'rocomunity',	'public',
 'rwcomunity',	'private',
 'bwfree',	64,
 'uplink',	1,
 'last_port',	1,
 'cli_vlan_num',0,
 'cli_vlan',	'test',
);

my $LIB_action = '';
my $res=0;
my $resport=0;
my $point='';
my $Querry_portfix = '';

sub USAGE {
    print STDERR  "Usage: $script_name ( mkvlanif IP_term <start ID> <stop ID> )\n";
    exit;
}

if (not defined($ARGV[0])) {
    USAGE();
############################################## CHECK SWITCH MODEL & MAC ##############################################
} elsif ( $ARGV[0] eq "mkvlanif" and defined($ARGV[1]) ) {
    USAGE() if ( not ( $ARGV[1] =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/ and $ARGV[2] =~ /\d+/ and $ARGV[3] =~ /\d+/ ) );

    $ipcli = '10.64.0.1';
    my $vlan = $ARGV[2];
    while ( $vlan > $ARGV[2] ) {
	CATIOS_term_l3realnet_add ( IP => '192.168.100.55', LOGIN => 'admin', PASS => 'TkljDbyf', 
	VLAN => $vlan, VLANNAME => "VLAN".$vlan, IPCLI => $ipcli, UP_ACLIN => 161, UP_ACLOUT => 162 );
	$vlan -= 1;
	$ipcli = '10.64.';
	
    }
}

