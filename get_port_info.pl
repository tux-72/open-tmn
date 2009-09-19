#!/usr/bin/perl

$debug=1;
my $ver='0.2';
#$VERSION = 0.97;

use Getopt::Long;

#use strict;
use Net::SNMP;
use POSIX qw(strftime);
use DBI();
use locale;


my $PROG=$0;
if ( $PROG =~ /(\S+)\/(\S+)$/ ) {
    require $1.'/conf/config.pl';
    print STDERR "USE PROGRAMM DIRECTORY => $1\n\n" if $debug;
} else {
    require '/usr/local/swctl/conf/config.pl';
    print STDERR "USE STANDART PROGRAMM DIRECTORY\n\n";
}

my $dbm = DBI->connect("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'}) or die("connect");
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
    $sw_descr{$ref0->{'sysdescr'}}	= $ref0->{'id'} 	if defined($ref0->{'sysdescr'});
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

if (not defined($ARGV[0])) {
    print STDERR "Usage: get_port_info.pl ( chk_model <hostname|allhosts> | chk_trunk <hostname> | host <hostname> | ip <IP switch> | allhosts )\n"

} elsif ( $ARGV[0] eq "chk_model" ) {
    my $Q_end = ' and h.info is NULL ';
    $Q_end = " and h.hostname='".$ARGV[1]."'" if ( $ARGV[1] ne "allhosts" );

    my $stm = $dbm->prepare("SELECT h.model, h.id, h.ip, m.rocom FROM hosts h, models m WHERE h.visible>0 and h.model=m.id ".$Q_end );
    $stm->execute();
    while (my $ref = $stm->fetchrow_hashref()) {
	print STDERR " IP = ".$ref->{'ip'}." Community ".$ref->{'rocom'}."\n"  if $debug;
	$ref->{'rocom'} = $conf{'DEF_COMUNITY'} if not defined($ref->{'rocom'});

	my($sess, $err) = Net::SNMP->session(	-hostname => $ref->{'ip'},
						-community => $ref->{'rocom'},
						-domain => 'udp/ipv4',
						-version => 'snmpv1',
						-timeout => 5,
						-translate => 0,
					    );

#	unless (defined($sess)) {
#	    die $err;
#	}

	my($oid_model) = '.1.3.6.1.2.1.1.1.0';
	#my($res) = $sess->get_table(-baseoid => $boid);
	my($res) = $sess->get_request($oid_model);
	#print STDERR "Host model = ".$res->{$oid_model}."\n";
	if (defined($res)) {
	    $sess->close;
	    foreach my $key ( sort keys %sw_descr ) {
		if ( $res->{$oid_model} =~ /$key/ ) {
		    $model = $sw_descr{$key};
		    print STDERR "Host model N".$sw_descr{$key}.", description = '".$sw_models[$sw_descr{$key}]."'\n" if $debug;
		    if ( $ref->{'model'} != $sw_descr{$key} ) {
			print STDERR "Change host model to ID N".$sw_descr{$key}.", previous model ID is N".$ref->{'model'}."\n" if $debug;
			$dbm->do("UPDATE hosts SET model=".$sw_descr{$key}." WHERE id=".$ref->{'id'} );
			#$dbm->do("UPDATE hosts SET info='".$sw_descr{$key}."' WHERE id=".$ref->{'id'} );
		    }
		}
	    }
#	} else {
#	    print $sess->error;
#	    $sess->close;
#	    return undef;
	}

    }
    $stm->finish();

} elsif ( $ARGV[0] eq "chk_trunk" ) {
    
#    my $stm = $dbm->prepare("SELECT h.id, h.hw_mac, h.ip, h.parent, h.parent_portpref, h.parent_port, h.uplink_port, h.uplink_port ".
#    ", p.id, h.hw_mac, h.ip, h.parent, h.parent_portpref, h.parent_port, h.uplink_port, h.uplink_port ".
#    " FROM swports p, head_link l WHERE l.set_status>0 and l.port_id=p.port_id ORDER BY l.head_id");
#    $stm->execute();

} 

