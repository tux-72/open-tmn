#!/usr/bin/perl

$debug=1;
my $ver='0.5';
#$VERSION = 0.97;

use Getopt::Long;

#use strict;
use Net::SNMP;
use POSIX qw(strftime);
use DBI();
use locale;


my $PROG=$0;
my $script_name=$0;
if ( $PROG =~ /(\S+)\/(\S+)$/ ) {
    require $1.'/conf/config.pl';
    $script_name="$2";
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
    "Usage: $script_name ( chk_model|chk_trunk  <hostname|ip|allhosts> )\n"

############################################## CHECK SWITCH MODEL & MAC ##############################################
} elsif ( $ARGV[0] eq "chk_model" and defined($ARGV[1]) ) {
    my $Q_end = " order by h.hostname" ;
    if ( $ARGV[1] ne "allhosts" ) {
	if ( $ARGV[1] =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
	    $Q_end = " and h.ip='".$ARGV[1]."'";
	} else {
	    $Q_end = " and h.hostname='".$ARGV[1]."'";
	}
    }

    my $stm = $dbm->prepare("SELECT h.hostname, h.hw_mac, h.model, h.id, h.ip, m.rocom FROM hosts h, models m WHERE h.visible>0 and h.model=m.id ".$Q_end );
    $stm->execute();
    dlog ( SUB =>'chk_model', DBUG => 0, MESS => "Not found switches for input parameters" ) if ($stm->rows < 1 );

    while (my $ref = $stm->fetchrow_hashref()) {

	$ref->{'rocom'} = $conf{'DEF_COMUNITY'} if not defined($ref->{'rocom'}); 
	my $fix_rez = ''; my $MAC = '';

	$fix_rez = "-------- HOST '".$ref->{'hostname'}."' --------\n\n"; 
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
	my($res) = $sess->get_request($oid_model);
	#my($res) = $sess->get_table(-baseoid => $boid);
	if (defined($res)) {
	    $sess->close;
	    foreach my $key ( sort keys %sw_descr ) {
		if ( $res->{$oid_model} =~ /$key/ ) {
		    $fix_rez .= "FIX model ID = ".lspaced($sw_descr{$key},2)."  '".rspaced($sw_models[$sw_descr{$key}]."'",20);
		    if ( $ref->{'model'} != $sw_descr{$key} ) {
			$fix_rez .= ", OLD model (".$ref->{'model'}.") is WRONG!!!" if $debug > 1 ;
			$Q_update .= ", model=".$sw_descr{$key};
		    }
		}
	    }
#	} else {
#	    print $sess->error;
#	    $sess->close;
	}
	# ------------------------------------
	open ARPTABLE, "/usr/sbin/arp -na |" or die "Error read ARP table\n";
	while (<ARPTABLE>) {
	    #? (192.168.29.22) at 00:09:6b:8c:2e:e1 on mif0 [vlan]
	    if ( /\((\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\)\s+\S+\s+(\w\w\:\w\w\:\w\w\:\w\w\:\w\w\:\w\w)\s+/
	    and "$1" eq $ref->{'ip'} ) {
		$MAC = $2;
		$fix_rez .= "\nFIX switch MAC = '".$MAC."'";
		$Q_update .= ", hw_mac='".$MAC."'" if ( $ref->{'hw_mac'} ne $MAC );
	    }
	}
	close ARPTABLE;
	
	dlog ( SUB =>'chk_model', DBUG => 1, MESS => $fix_rez );
	#  END check switch parameters -------
	$Q_update .= " WHERE id=".$ref->{'id'};
	#$Q_update .= ";";
	if ( $Q_update =~ /\,/ ) {
	    dlog ( SUB =>'chk_model', DBUG => 2, MESS => "$Q_update");
	    $dbm->do($Q_update) if $debug < 2;
	}
    }
    $stm->finish();


############################################## CHECK & UPDATE TRUNK PORTS ##############################################
} elsif ( $ARGV[0] eq "chk_trunk" and defined($ARGV[1])) {
    my $Q_end = " order by h.hostname" ;
    if ( $ARGV[1] ne "allhosts" ) {
	if ( $ARGV[1] =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/) {
	    $Q_end = " and h.ip='".$ARGV[1]."'";
	} else {
	    $Q_end = " and h.hostname='".$ARGV[1]."'";
	}
    }

    my $stm2 = $dbm->prepare("SELECT h.hostname, h.model, h.hw_mac, h.id, h.ip, h.uplink_port, h.uplink_portpref, h.parent, h.parent_portpref".
    ", h.parent_port, h.control_vlan, m.lib, m.mon_login, m.mon_pass FROM hosts h, models m WHERE h.visible>0 and h.model=m.id and h.control_vlan>0 ".$Q_end);
    $stm2->execute();
    #print STDERR "Not found switches for input parameters\n" if ($stm2->rows < 1 );
    #dlog ( SUB =>'chk_trunk', DBUG => 1, MESS =>  );
    dlog ( SUB =>'chk_trunk', DBUG => 0, MESS => "Not found switches for input parameters" ) if ($stm2->rows < 1 ) ;

    while (my $ref = $stm2->fetchrow_hashref()) {
	if ($ref->{'parent'} < 1 ) {
	    dlog ( SUB =>'chk_trunk', DBUG => 0, MESS => "NOT found PARENT switch for '".$ref->{'hostname'} );
	    #print STDERR "NOT found PARENT switch for '".$ref->{'hostname'}."'\n";
	    next;
	}
	my $LIB_action = ''; my $uplink_portpref = ''; my $uplink_port = 0; my $parent_portpref = ''; my $parent_port = 0; my $fix_rez = '';
	my $downtype = 1; my $uptype = 1;

	# ------- Fix uplink PORT ------------
	my $Q_update = "UPDATE hosts SET model='".$ref->{'model'}."'";
	my $Q_downlink = ''; $Q_uplink = '';

	if ( $ref->{'lib'} ) {
	    $fix_rez = "-------- HOST '".$ref->{'hostname'}."' --------\n"; 
	    $LIB_action = $ref->{'lib'}."_fix_macport";
	    ( $uplink_portpref, $uplink_port ) = &$LIB_action( IP => $ref->{'ip'}, LOGIN => $ref->{'mon_login'}, PASS => $ref->{'mon_pass'}, MAC => $checkmac{$ref->{'control_vlan'}}, VLAN => $ref->{'control_vlan'} );
	    if ( $uplink_port > 0 ) {
		$fix_rez .= "FIX uplink port = ".lspaced($uplink_portpref.$uplink_port,6).", \t";
		$Q_update .= ", uplink_portpref='".$uplink_portpref."'"	if ( "x".$uplink_portpref ne "x".$ref->{'uplink_portpref'} );
		$Q_update .= ", uplink_port=".$uplink_port		if ( "x".$uplink_port 	  ne "x".$ref->{'uplink_port'} );
	    } else {
		$fix_rez .=  "Uplink port not fixed :(((\t"; 
	    }
	}

	# -------- Fix parent PORT -----------
	my $stm22 = $dbm->prepare("SELECT h.hostname, h.model, h.ip, h.id, m.lib, m.mon_login, m.mon_pass FROM hosts h, models m WHERE h.visible>0 and h.model=m.id and h.id=".$ref->{'parent'} );
	$stm22->execute();
	while (my $ref2 = $stm22->fetchrow_hashref()) {
	    $LIB_action = $ref2->{'lib'}."_fix_macport";
	    if ( $ref2->{'lib'} ) {
		( $parent_portpref, $parent_port ) = &$LIB_action( IP => $ref2->{'ip'}, LOGIN => $ref2->{'mon_login'}, PASS => $ref2->{'mon_pass'}, MAC => $ref->{'hw_mac'}, VLAN => $ref->{'control_vlan'});
		if ( $parent_port > 0 ) {
		    $fix_rez .= "FIX parent '".$ref2->{'hostname'}."' downlink = ".$parent_portpref.$parent_port;
		    $Q_update .= ", parent_portpref='".$parent_portpref."'"	if ( "x".$parent_portpref ne "x".$ref->{'parent_portpref'} );
		    $Q_update .= ", parent_port=".$parent_port			if ( "x".$parent_port 	  ne "x".$ref->{'parent_port'} );
		    if ( $parent_portpref eq "Po" ) {
		        $downtype = 0;
		    } else {
		        $downtype = 1;
		    }
		    if ( CHECK_port_exists( SWID => $ref2->{'id'}, PORTPREF => $parent_portpref, PORT => $parent_port, TYPE => $downtype ) < 0 ) {
			$Q_downlink = "INSERT INTO swports SET info='Downlink to ".$ref->{'hostname'}."', sw_id=".$ref2->{'id'}.", link_type=".$link_type{'trunk'}.
			", type=".$downtype.", portvlan=".$ref->{'control_vlan'}.", port=".$parent_port;
			$Q_downlink .= ", portpref='".$parent_portpref."'" if ("x".$parent_portpref ne "x" );
			#$Q_downlink .= " ON DUPLICATE KEY UPDATE link_type=".$link_type{'trunk'}.", info='Downlink to ".$ref->{'hostname'}."'";
		    } else {
			$Q_downlink = "UPDATE swports SET link_type=".$link_type{'trunk'}.", info='Downlink to ".$ref->{'hostname'}.
			"' WHERE sw_id=".$ref2->{'id'}." and type=".$downtype." and port=".$parent_port;
			if ( "x".$parent_portpref ne "x" ) {
			    $Q_downlink .= " and portpref='".$parent_portpref."'";
			} else {
			    $Q_downlink .= " and portpref is NULL";
			}
		    }
		} else {
		    $fix_rez .= " Parent host '".$ref2->{'hostname'}."' downlink not fixed :(((\t";
		}
	    }
	    if ( $uplink_port > 0 ) {
		if ( $uplink_portpref eq "Po" ) {
		    $uptype = 0;
		} else {
		    $uptype = 1;
		}
		if ( CHECK_port_exists( SWID => $ref->{'id'}, PORTPREF => $uplink_portpref, PORT => $uplink_port, TYPE => $uptype ) < 0 ) {
		    $Q_uplink = "INSERT INTO swports SET info='Uplink to ".$ref2->{'hostname'}."', sw_id=".$ref->{'id'}.", link_type=".$link_type{'uplink'}.
		    ", type=".$uptype.", portvlan=".$ref->{'control_vlan'}.", port=".$uplink_port;
		    $Q_uplink .= ", portpref='".$uplink_portpref."'" if ("x".$uplink_portpref ne "x" );
		    #$Q_uplink .= " ON DUPLICATE KEY UPDATE link_type=".$link_type{'uplink'}.", info='Uplink to ".$ref2->{'hostname'}."'";
                } else {
		    $Q_uplink = "UPDATE swports SET link_type=".$link_type{'uplink'}.", info='Uplink to ".$ref2->{'hostname'}.
		    "' WHERE sw_id=".$ref->{'id'}." and type=".$uptype." and port=".$uplink_port;
		    if ( "x".$uplink_portpref ne "x" ) {
			$Q_uplink .= " and portpref='".$uplink_portpref."'";
		    } else {
			$Q_uplink .= " and portpref is NULL";
		    }
		}
	    }
	}
	$stm22->finish();
	dlog ( SUB =>'chk_trunk', DBUG => 1, MESS => $fix_rez." " );
	dlog ( SUB =>'chk_trunk', DBUG => 2, MESS => $Q_uplink.";" );
	dlog ( SUB =>'chk_trunk', DBUG => 2, MESS => $Q_downlink.";" );

	if ( $ARGV[1] ne "allhosts" and $debug < 2 ) {
	    $dbm->do($Q_uplink);
	    $dbm->do($Q_downlink);
	}

	# ------ END check switch parameters -------
	$Q_update .= " WHERE id=".$ref->{'id'};
	if ( $Q_update =~ /\,/ ) {
	    dlog ( SUB =>'chk_trunk', DBUG => 2, MESS => $Q_update.";" );
	    $dbm->do($Q_update) if ( $ARGV[1] ne "allhosts" and $debug < 2 );
	}
    }
    $stm2->finish();
}


sub CHECK_port_exists {
        my %arg = (
            @_,
        );
        #  SWID PORTPREF PORT TYPE 
	my $Q_chk  = "SELECT port_id FROM swports WHERE sw_id=".$arg{'SWID'}." and port=".$arg{'PORT'}." and type=".$arg{'TYPE'};
	if ( "x".$arg{'PORTPREF'} ne "x" ) {
	    $Q_chk .= " and portpref='".$arg{'PORTPREF'}."'";
	} else {
	    $Q_chk .= " and portpref is NULL";
	}
	#print "\n--------------\"$Q_chk\"\n" if $debug > 1;
	my $stmchk = $dbm->prepare($Q_chk);
	$stmchk->execute();
	if ( $stmchk->rows < 1 ) {
	    # записи для порта не найдено
	    return -1;
	} else {
	    # запись для порта существует
	    return 1;
	}
}

