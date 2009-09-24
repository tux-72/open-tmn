#!/usr/bin/perl

$debug=2;
my $ver='0.3';
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
    print STDERR "RUN in DIR => $1\n" if $debug;
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
    $sw_descr{$ref0->{'sysdescr'}}	= $ref0->{'id'}		if defined($ref0->{'sysdescr'});
    $sw_libs{$ref0->{'id'}}		= $ref0->{'lib'}	if defined($ref0->{'lib'});
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
    print STDERR 
    "Usage: get_port_info.pl ( chk_model <hostname|allhosts> | chk_trunk <hostname> | host <hostname> | ip <IP switch> | allhosts )\n"

} elsif ( $ARGV[0] eq "chk_model" ) {
    my $Q_end = '';
    $Q_end = " and h.hostname='".$ARGV[1]."'" if ( $ARGV[1] ne "allhosts" );

    my $stm = $dbm->prepare("SELECT h.hostname, h.hw_mac, h.model, h.id, h.ip, m.rocom FROM hosts h, models m WHERE h.visible>0 and h.model=m.id ".$Q_end );
    $stm->execute();
    while (my $ref = $stm->fetchrow_hashref()) {
	#print STDERR " IP = ".$ref->{'ip'}." Community ".$ref->{'rocom'}."\n"  if $debug;
	$ref->{'rocom'} = $conf{'DEF_COMUNITY'} if not defined($ref->{'rocom'}); my $MAC = '';

	# ------------------------------------
	my($sess, $err) = Net::SNMP->session(	-hostname => $ref->{'ip'},
						-community => $ref->{'rocom'},
						-domain => 'udp/ipv4',
						-version => 'snmpv1',
						-timeout => 2,
						-translate => 0,
					    );

#	unless (defined($sess)) {
#	    die $err;
#	}
	my $Q_update = "UPDATE hosts SET ip='".$ref->{'ip'}."'";

	my($oid_model) = '.1.3.6.1.2.1.1.1.0';
	#my($res) = $sess->get_table(-baseoid => $boid);
	my($res) = $sess->get_request($oid_model);
	#print STDERR "Host model = ".$res->{$oid_model}."\n";
	if (defined($res)) {
	    $sess->close;
	    foreach my $key ( sort keys %sw_descr ) {
		if ( $res->{$oid_model} =~ /$key/ ) {
		    if ( $ref->{'model'} != $sw_descr{$key} ) {
			print STDERR "Change Host = ".$ref->{'hostname'}." model => N".$sw_descr{$key}.", description = '".$sw_models[$sw_descr{$key}].
			", previous model ID is N".$ref->{'model'}."\n" if $debug > 1 ;
			$Q_update .= ", model=".$sw_descr{$key};
			#$ref->{'model'} = $sw_descr{$key};
			#$ref->{'lib'} = $sw_libs{$ref->{'model'}};
		    }
		}
	    }
#	} else {
#	    print $sess->error;
#	    $sess->close;
#	    return undef;
	}
	# ------------------------------------
	open ARPTABLE, "/usr/sbin/arp -na |" or die "Error read ARP table\n";
	while (<ARPTABLE>) {
	    #? (192.168.29.22) at 00:09:6b:8c:2e:e1 on mif0 [vlan]
	    if ( /\((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\)\s+\S+\s+(\w\w\:\w\w\:\w\w\:\w\w\:\w\w\:\w\w)\s+/
	    and "$1" eq $ref->{'ip'} and "$2" ne $ref->{'hw_mac'}) {
		$MAC = $2;
		#print STDERR "\t IP $1 = MAC '".$MAC."' " if $debug;
		$Q_update .= ", hw_mac='".$MAC."'";
	    }
	}
	close ARPTABLE;
	
	#  END check switch parameters -------
	$Q_update .= " WHERE id=".$ref->{'id'};
	if ( $Q_update =~ /\,/ ) {
	    print STDERR "Host = ".$ref->{'hostname'}."\tQuerry = \"".$Q_update."\"\n";
	    $dbm->do($Q_update) if $debug < 2;
	}
    }
    $stm->finish();

} elsif ( $ARGV[0] eq "chk_trunk" ) {
    my $Q_end = '';
    $Q_end = " and h.hostname='".$ARGV[1]."'" if ( $ARGV[1] ne "allhosts" );

    my $stm2 = $dbm->prepare("SELECT h.hostname, h.hw_mac, h.id, h.ip, h.uplink_port, h.uplink_portpref, h.parent, h.parent_portpref".
    ", h.parent_port, m.lib, m.mon_login, m.mon_pass FROM hosts h, models m WHERE h.visible>0 and h.model=m.id ".$Q_end );
    $stm2->execute();
    while (my $ref = $stm2->fetchrow_hashref()) {
	#print STDERR " IP = ".$ref->{'ip'}." Community ".$ref->{'rocom'}."\n"  if $debug;
	$ref->{'rocom'} = $conf{'DEF_COMUNITY'} if not defined($ref->{'rocom'});
	my $LIB_action = ''; my $uplink_portpref = ''; my $uplink_port = 0; my $parent_portpref = ''; my $parent_port = 0;

	# ------- Fix uplink PORT ------------
	my $Q_update = "UPDATE hosts SET ip='".$ref->{'ip'}."'";
	if ( $ref->{'lib'} ) {
	    $LIB_action = $ref->{'lib'}."_fix_macport";
	    ( my $uplink_portpref, my $uplink_port ) = &$LIB_action( IP => $ref->{'ip'}, LOGIN => $ref->{'mon_login'}, PASS => $ref->{'mon_pass'}, MAC => $conf{'CONTROL_HOST_MAC'}, VLAN => $conf{'CONTROL_VLAN'});
	    if ( $uplink_port > 0 ) {
		print STDERR "FIX uplink port = ".$uplink_portpref.$uplink_port."\n";
		$Q_update .= ", uplink_portpref='".$uplink_portpref."'"	if ( "x".$uplink_portpref ne "x".$ref->{'uplink_portpref'} );
		$Q_update .= ", uplink_port=".$uplink_port		if ( "x".$uplink_port 	  ne "x".$ref->{'uplink_port'} );
	    } else {
		print STDERR "Uplink port not fixed :(((\n"; 
	    }
	}

	# -------- Fix parent PORT -----------
	my $stm22 = $dbm->prepare("SELECT h.hostname, h.model, h.ip, m.lib, m.mon_login, m.mon_pass FROM hosts h, models m WHERE h.visible>0 and h.model=m.id and h.id=".$ref->{'parent'} );
	$stm22->execute();
	while (my $ref2 = $stm22->fetchrow_hashref()) {
	    $LIB_action = $ref2->{'lib'}."_fix_macport";
	    if ( $ref2->{'lib'} ) {
		( my $parent_portpref, my $parent_port ) = &$LIB_action( IP => $ref2->{'ip'}, LOGIN => $ref2->{'mon_login'}, PASS => $ref2->{'mon_pass'}, MAC => $ref->{'hw_mac'}, VLAN => $conf{'CONTROL_VLAN'});
		if ( $parent_port > 0 ) {
		    print STDERR "FIX parent downlink port = ".$parent_portpref.$parent_port."\n";
		    $Q_update .= ", parent_portpref='".$parent_portpref."'"	if ( "x".$parent_portpref ne "x".$ref->{'parent_portpref'} );
		    $Q_update .= ", parent_port=".$parent_port			if ( "x".$parent_port 	  ne "x".$ref->{'parent_port'} );
		} else {
		    print STDERR "Parent downlink port not fixed :(((\n"; 
		}
	    }
	}
	$stm22->finish();
	
	#  END check switch parameters -------
	$Q_update .= " WHERE id=".$ref->{'id'};
	if ( $Q_update =~ /\,/ ) {
	    print STDERR "Host = ".$ref->{'hostname'}."\tQuerry = \"".$Q_update."\"\n";
	    $dbm->do($Q_update) if $debug < 2;
	}
    }
    $stm2->finish();
}

