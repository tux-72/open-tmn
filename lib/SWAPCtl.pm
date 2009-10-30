#!/usr/bin/perl

package SWAPCtl;

#use strict;
#use locale;

use POSIX qw(strftime);
use cyrillic qw/cset_factory/;


use DBI();
use SWALLCtl;
#use SWDBCtl;
use C73Ctl;
use CATIOSCtl;
use CAT2950Ctl;
use CATOSCtl;
use DESCtl;
use ESCtl;
use GSCtl;
use BPSCtl;
use TCOM4500Ctl;


use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();

@ISA = qw(Exporter);

@EXPORT_OK = qw();
@EXPORT_TAGS = ();

@EXPORT = qw(	SW_AP_get SW_AP_tune SW_AP_free
	    );

$VERSION = 1.3;

my $w2k = cset_factory 1251, 20866;
my $k2w = cset_factory 20866, 1251;

my $debug=1;

### LOG 
my $logfile='/var/log/dispatcher/ap_ctl.log';

use FindBin '$Bin';
require $Bin . '/../conf/config.pl';
dlog_ap ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS => "Use BIN directory - $Bin" );

############ SUBS ##############

#my $dbm; $res = DB_mysql_connect(\$dbm);
#if ($res < 1) {
#    dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "Connect to DB FAILED, RESULT = $res" );
#    exit;
#}

#my $dbm = DBI->connect("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'})
#or dlog_ap ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS => "Unable to connect MYSQL DB host ".$conf{'MYSQL_host'}."$DBI::errstr" );
#$dbm->do("SET NAMES 'koi8r'");

my $dbm = DBI->connect_cached("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'})
or dlog_ap ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS => "Unable to connect MYSQL DB host ".$conf{'MYSQL_host'}."$DBI::errstr" );
$dbm->do("SET NAMES 'koi8r'");


my $LIB_ACT ='';

%link_type = ();
my @link_types = '';
my $stm01 = $dbm->prepare("SELECT id, name FROM link_types order by id");
$stm01->execute();
while (my $ref01 = $stm01->fetchrow_hashref()) {
    $link_type{$ref01->{'name'}}=$ref01->{'id'} if defined($ref01->{'name'});
    $link_types[$ref01->{'id'}]=$ref01->{'name'} if defined($ref01->{'name'});
}
$stm01->finish();

%headinfo = ();
my $stm = $dbm->prepare( "SELECT t.term_ip, t.vlan_zone, t.term_grey_ip2, h.ip, m.lib, m.mon_login, m.mon_pass FROM heads t, hosts h, models m ".
" WHERE h.model=m.id and t.l2sw_id=h.id and t.term_ip is not NULL" );
# and t.head_type=".$link_type{'pppoe'});
$stm->execute();
while (my $ref = $stm->fetchrow_hashref()) {
    $headinfo{'L2LIB_'.   $ref->{'term_ip'}} = $ref->{'lib'};
    $headinfo{'L2IP_'.    $ref->{'term_ip'}} = $ref->{'ip'};
    $headinfo{'MONLOGIN_'.$ref->{'term_ip'}} = $ref->{'mon_login'};
    $headinfo{'MONPASS_'. $ref->{'term_ip'}} = $ref->{'mon_pass'};
    $headinfo{'ZONE_'.    $ref->{'term_ip'}} = $ref->{'vlan_zone'};
}
$stm->finish();

############ SUBS ##############

sub SW_AP_get {

        my $mysql_life = $dbm->ping;

        my $fparm = shift;
#	$fparm->{ap_id} =
#	$fparm->{nas_ip} = 192.168.100.30
#	$fparm->{login} = pppoe
#	$fparm->{ip_addr} = 10.13.64.3

#	$fparm->{port_rate_ds} = 10000
#	$fparm->{port_rate_us} = 10000
#	$fparm->{inet_rate} = 1000
	
	####################### ACCESS POINT ####################
	my $Query = ""; my $Query0 = ""; my $Query1 = ""; my $ip =''; my $Fres = 2; my $Fvalue = 'ap_id:-1;';
	my $VZONE = -1;
        my $date = strftime "%Y%m%d%H%M%S", localtime(time);


	if      ( $fparm->{'mac'} =~ /^(\w\w)(\w\w)\.(\w\w)(\w\w)\.(\w\w)(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif ( $fparm->{'mac'} =~ /^(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif ( $fparm->{'mac'} =~ /^(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif (! $fparm->{'mac'} =~ /^(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)$/) {
           dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "MAC '".$fparm->{'mac'}."' unknown format, exiting ..." );
	    return ( $Fres, $Fvalue );
	}

	my %AP = (
	    'trust',	0,
	    'set',	0,
	    'VLAN',	0,
	    'DB_portinfo',	0,
	    'MAC',	$fparm->{'mac'},
	    'id',	0,
	    'name',	'',
	    'swid',	0,
	    'house',	0,
	    'podezd',	0,
	    'portpref',	'',
	    'port',	0,
	    'ds_db',	0,
	    'us_db',	0,
	    'autoconf',	0,
	    'bw_ctl',	0,
	    'lastlogin','1',
	    'portvlan',	0,
	    'ip_subnet', '',
	    'autoneg', 1,
	    'speed', 100,
	    'duplex', 1,
	    'maxhwaddr', -1,
	);

	####### Start FIX Access Point (TD) #######
	$LIB_ACT =  $headinfo{'L2LIB_'.$fparm->{'nas_ip'}}.'_fix_vlan';
	$AP{'VLAN'} = &$LIB_ACT( IP => $headinfo{'L2IP_'.$fparm->{'nas_ip'}}, LOGIN => $headinfo{'MONLOGIN_'.$fparm->{'nas_ip'}},
	PASS => $headinfo{'MONPASS_'.$fparm->{'nas_ip'}}, MAC => $fparm->{'mac'});
	
	if ( $AP{'VLAN'} < 1) {
	    dlog_ap ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => "User '".$fparm->{'login'}."'".' Access point VLAN is not FIX!!! Trobles connect to ZONE SWITCH???' );
	    $Fres = 2;
	    $Fvalue = 'error:MAC VLAN not fixed... :-(;';
	} else {
		if ( $AP{'VLAN'} < $conf{'FIRST_ZONEVLAN'} || $headinfo{'ZONE_'.$fparm->{'nas_ip'}} == -1 ) {
		    $VZONE = 1;
		} else {
		    $VZONE = $headinfo{'ZONE_'.$fparm->{'nas_ip'}};
		}
		############# GET Switch IP's
		$stm0 = $dbm->prepare("SELECT s.automanage, s.bw_ctl, s.id, s.ip, s.model, s.hostname, s.idhouse, s.podezd, s.unit, h.idhouse, h.street, h.dom, m.lib, ".
		"m.mon_login, m.mon_pass FROM hosts s, houses h, models m WHERE s.model=m.id and s.idhouse=h.idhouse and m.lib is not NULL and s.clients_vlan=".
		$AP{'VLAN'}." and s.vlan_zone=".$VZONE );
		$stm0->execute();
		#$swrw  = $stm0->rows;
		dlog_ap ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => "Greater by one switches in VLAN '".$AP{'VLAN'}."'!!!" ) if $stm0->rows>1;

		while ($ref = $stm0->fetchrow_hashref() and not $AP{'id'}) {
			$AP{'autoconf'}=1 if ($ref->{'automanage'} == 1);
			$AP{'bw_ctl'}=1 if ($ref->{'bw_ctl'} == 1);

			$LIB_ACT = $ref->{'lib'}.'_fix_macport';
			( $AP{'portpref'}, $AP{'port'} ) = &$LIB_ACT( IP => $ref->{'ip'}, LOGIN => $ref->{'mon_login'}, PASS => $ref->{'mon_pass'}, MAC => $fparm->{'mac'}, VLAN => $AP{'VLAN'});
			if ($AP{'port'}>0 or $stm0->rows == 1) {
    				$AP{'swid'} = $ref->{'id'}; $AP{'house'} = $ref->{'idhouse'}; $AP{'podezd'} = $ref->{'podezd'};
                                $AP{'name'} = "ул. ".$ref->{'street'}.", д.".$ref->{'dom'};
				$AP{'name'} .= ", п.".$ref->{'podezd'} if $ref->{'podezd'}>0;
				$AP{'name'} .= ", unit N".$ref->{'unit'} if defined($ref->{'unit'});
			}
			if ($AP{'port'}>0) {
				if ( defined($AP{'portpref'}) and 'x'.$AP{'portpref'} ne 'x' ) {
			    	    $Query10 = "SELECT port_id FROM swports WHERE portpref='".$AP{'portpref'}."' and  port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query0 = "SELECT autoconf, port_id, communal_port, ds_speed, us_speed, link_type, login, portvlan, ip_subnet, autoneg, speed, duplex, maxhwaddr FROM swports WHERE portpref='".$AP{'portpref'}."' and  port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query1 = "INSERT into swports  SET  status=1, link_type=".$link_type{'free'}.", type=1, ds_speed=64, us_speed=64, portpref='".$AP{'portpref'}."', port='".$AP{'port'}."', sw_id='".$AP{'swid'}."', portvlan=-1";
				} else {
			    	    $Query10 = "SELECT port_id FROM swports WHERE portpref is NULL and port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query0 = "SELECT autoconf, port_id, communal_port, ds_speed, us_speed, link_type, login, portvlan, ip_subnet, autoneg, speed, duplex, maxhwaddr FROM swports WHERE portpref is NULL and port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query1 = "INSERT into swports  SET status=1, link_type=".$link_type{'free'}.", type=1, ds_speed=64, us_speed=64, portpref=NULL, port='".$AP{'port'}."', sw_id='".$AP{'swid'}."', portvlan=-1";
				}
				my $stm10 = $dbm->prepare($Query10);
				$stm10->execute();
				if (not $stm10->rows) {
			    		$dbm->do($Query1);
					dlog_ap ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => "Insert New PORT record in swports" );
				}
				$stm10->finish;
				my $stm1 = $dbm->prepare($Query0);
				$stm1->execute();
			    	while (my $refp = $stm1->fetchrow_hashref()) {
					$AP{'db_autoconf'} = $refp->{'autoconf'};
					$AP{'db_link_type'} = $link_type{'free'};
					$AP{'db_link_type'} = $refp->{'link_type'} if defined($refp->{'link_type'});
					$AP{'lastlogin'} = $refp->{'login'} if defined($refp->{'login'});
					$AP{'id'} = $refp->{'port_id'};
					$AP{'communal'} = $refp->{'communal_port'};
					$AP{'ds'} = $refp->{'ds_speed'} if defined($refp->{'ds_speed'});
					$AP{'us'} = $refp->{'us_speed'} if defined($refp->{'us_speed'});
					#NEW Parameters    
					$AP{'portvlan'} = $refp->{'portvlan'} if defined($refp->{'portvlan'});
					$AP{'ip_subnet'} = $refp->{'ip_subnet'} if defined($refp->{'ip_subnet'});

			    	}
                                        $AP{'name'} .= ", порт ".$AP{'port'};
					$stm1->finish;
			}
			dlog_ap ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => 
			"CLI_VLAN '".$AP{'VLAN'}."' User: '".$fparm->{'login'}."' AP -> '".$AP{'id'}."', '".$AP{'name'}."'" );
		}
		$stm0->finish;
		if (not $AP{'id'}) {
			dlog_ap ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => "FIND PORT VLAN '".$AP{'VLAN'}."' User: '".$fparm->{'login'}."', MAC:'".$fparm->{'mac'}."'" );
			$AP{'DB_portinfo'}=1;
			$stm0 = $dbm->prepare( "SELECT s.automanage, s.bw_ctl, s.id, s.ip, s.model, s.hostname, s.idhouse, s.podezd, s.unit, h.idhouse, ".
			"h.street, h.dom, p.sw_id, p.autoconf, p.port_id, p.link_type, p.communal_port, p.portpref, p.port, p.ds_speed, p.us_speed, p.login, ".
			"p.portvlan, p.ip_subnet, p.autoneg, p.speed, p.duplex, p.maxhwaddr FROM hosts s, houses h, swports p ".
			"WHERE s.idhouse=h.idhouse and p.sw_id=s.id and p.portvlan=".$AP{'VLAN'}." and s.vlan_zone=".$VZONE );
                    	$stm0->execute();
                    	while ($ref = $stm0->fetchrow_hashref()) {
			    $AP{'port'} = $ref->{'port'} if not defined($ref->{'portpref'});
			    $AP{'port'} = $ref->{'portpref'}.$ref->{'port'} if defined($ref->{'portpref'});
                            $AP{'swid'} = $ref->{'sw_id'}; $AP{'house'} = $ref->{'idhouse'}; $AP{'podezd'} = $ref->{'podezd'};

                            $AP{'name'} = "ул. ".$ref->{'street'}.", д.".$ref->{'dom'};
                            $AP{'name'} .= ", п.".$ref->{'podezd'} if $ref->{'podezd'}>0;
                            $AP{'name'} .= ", unit N".$ref->{'unit'} if defined($ref->{'unit'});
                            $AP{'name'} .= ", порт ".$AP{'port'};

			    $AP{'db_link_type'} = $link_type{'free'};
			    $AP{'db_link_type'} = $ref->{'link_type'} if defined($ref->{'link_type'});
			    $AP{'db_autoconf'} = $ref->{'autoconf'};

			    $AP{'lastlogin'} = $ref->{'login'}  if defined($ref->{'login'});
			    $AP{'autoconf'}=1 if ($ref->{'automanage'} == 1);
			    $AP{'bw_ctl'}=1 if ($ref->{'bw_ctl'} == 1);

			    $AP{'ds'} = $ref->{'ds_speed'} if defined($ref->{'ds_speed'});
			    $AP{'us'} = $ref->{'us_speed'} if defined($ref->{'us_speed'});
			    #NEW Parameters
			    $AP{'portvlan'} = $ref->{'portvlan'} if defined($ref->{'portvlan'});
			    $AP{'ip_subnet'} = $ref->{'ip_subnet'} if defined($ref->{'ip_subnet'});

			    if ($AP{'id'}) {
				dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "MULTI TD's!!! = '".$AP{'id'}."' and '".$ref->{'port_id'}."'" );
				$AP{'id'} = 0; $AP{'swid'} = 0; $AP{'house'}=0; $AP{'podezd'}=0; $AP{'name'}=''; $AP{'port'}=0;
				last;
			    }
			    $AP{'id'} = $ref->{'port_id'};
			    $AP{'communal'} = $ref->{'communal_port'};
			    dlog_ap ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => 
			    "VLAN '".$AP{'VLAN'}."' User: '".$fparm->{'login'}."' AP -> '".$AP{'id'}."', '".$AP{'name'}."'" );
			}
			    $stm0->finish;
		}

		#	$fparm->{ap_id} =
		#	$fparm->{nas_ip} = 192.168.100.30
		#	$fparm->{login} = pppoe
		#	$fparm->{link_type} = 21
		#	$fparm->{mac} = 0017.3156.7fd9
		#	$fparm->{ip_addr} = 10.13.64.3

		#	$fparm->{port_rate_ds} = 10000
		#	$fparm->{port_rate_us} = 10000
		#	$fparm->{inet_rate} = 1000
		#	$fparm->{ap_vlan} = 239

		if ($AP{'id'}) {
			$Fres = 1;
			$Fvalue = 'ap_id:'.$AP{'id'}.';ap_name:'.&$k2w($AP{'name'}).';bw_ctl:'.$AP{'bw_ctl'}.';ap_swid:'.$AP{'swid'}.';ap_communal:'.$AP{'communal'}.';';
			if ( $fparm->{'ap_id'} and $fparm->{'ap_id'} == $AP{'id'} ) {
			    $Fres = 0;
			    # normalize port speed
			    if ( defined($fparm->{'port_rate_ds'}) and $fparm->{'port_rate_ds'} == 0 ) {
				$fparm->{'port_rate_ds'} = -1;
			    }
			    if ( defined($fparm->{'port_rate_us'}) and $fparm->{'port_rate_us'} == 0 ) {
				$fparm->{'port_rate_us'} = -1;
			    }

			    # добавил коммунальное условие!!!
    			    if ( ( $AP{'db_link_type'} != $fparm->{'link_type'}
				|| $AP{'us'} != $fparm->{'port_rate_us'}
				|| $AP{'ds'} != $fparm->{'port_rate_ds'}
				|| ( defined($fparm->{'vlan_id'}) and $AP{'portvlan'}  != $fparm->{'vlan_id'} )
			    ) and not $AP{'communal'} ) { 
				$AP{'set'} = 1;
			    }
			    #$AP{'inet_rate'}	= $fparm->{'inet_rate'} 	if defined($fparm->{'inet_rate'});
			    $AP{'ds'} 		= $fparm->{'port_rate_ds'} 	if defined($fparm->{'port_rate_ds'});
			    $AP{'us'} 		= $fparm->{'port_rate_us'} 	if defined($fparm->{'port_rate_us'});
			    #NEW Parameters
			    # Костылик
			    $AP{'link_type'}	= $link_type{'pppoe'};
			    $AP{'link_type'}	= $fparm->{'link_type'} if ( defined($fparm->{'link_type'}) and "x".$fparm->{'link_type'} ne "x");
			    $AP{'portvlan'}	= $fparm->{'vlan_id'}	if ( defined($fparm->{'vlan_id'})   and "x".$fparm->{'vlan_id'} ne "x" );
			    $AP{'ip_subnet'}	= $fparm->{'ip_addr'}	if ( defined($fparm->{'ip_addr'})   and "x".$fparm->{'ip_addr'} ne "x" );

                            dlog_ap ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS =>
			    "TD_set = '".$AP{'set'}."', AP_DS = '".$AP{'ds'}."', AP_US = '".$AP{'us'}."'" );
			    $AP{'trust'}=1;
			} else {
			    $AP{'trust'}=0;
			    $AP{'set'} = 0
			}
			$Query = "INSERT INTO user_mac_port SET trust=".$AP{'trust'}.", login='".$fparm->{'login'}."', start_date='".$date."', last_date='".$date."', mac='".$fparm->{'mac'}."', vlan='".$AP{'VLAN'}."', td='".$AP{'id'}."'";
			$Query .= ", td_name='".$AP{'name'}."', idhouse='".$AP{'house'}."', podezd='".$AP{'podezd'}."', sw_id='".$AP{'swid'}."', port='".$AP{'port'}."' ON DUPLICATE KEY UPDATE trust=".$AP{'trust'};
			$Query .= ", td_name='".$AP{'name'}."', idhouse='".$AP{'house'}."', podezd='".$AP{'podezd'}."', sw_id='".$AP{'swid'}."', last_date='".$date."', vlan='".$AP{'VLAN'}."'";
			$dbm->do("$Query");
			#### TEMP SET
			#$AP{'lastlogin'} = '';
			if ($AP{'set'} and $AP{'autoconf'} and !($fparm->{'login'} =~ /^(jur|com)test\d+$/ )) {
		    	    $Query = "UPDATE swports SET start_date='".$date."', login='".$fparm->{'login'}."', mac_port='".$fparm->{'mac'}."', ds_speed=".$AP{'ds'}.", us_speed=".$AP{'us'};
			    ########  VPN  VLAN  ########
			    if ( $fparm->{'link_type'} == $link_type{'l2link'} ) {
				if ( "x".$fparm->{'vlan_id'} eq "x" and $AP{'db_autoconf'} != $link_type{'l2link'} ) {
				    ( $fparm->{'vlan_id'}, $AP{'link_head'} ) = VLAN_VPN_get ( PORT_ID => $AP{'id'}, LINK_TYPE => $link_type{'l2link'}, ZONE => $VZONE ); 
				    $Fvalue .= 'vlan_id:'.$fparm->{'vlan_id'}.';' if ( $fparm->{'vlan_id'} > 1 );
		    		    $Query .= ", link_head=".$AP{'link_head'}   if ( $AP{'link_head'} > 1 );
				}
		    		$Query .= ", portvlan=".$fparm->{'vlan_id'} if ( $fparm->{'vlan_id'} > 1 );
			    } elsif (not $AP{'DB_portinfo'}) {
		    		$Query .= ", portvlan=".$AP{'VLAN'};
			    }
		    	    $Query .= ", ip_subnet='".$AP{'ip_subnet'}."/30'" if $AP{'link_type'} == $link_type{'l3net4'};
			    if ( $AP{'db_link_type'} == $link_type{'free'} ) {
				$Query .= ", autoconf=".$AP{'link_type'}." WHERE port_id=".$AP{'id'}." and link_type=".$link_type{'free'};
			    } elsif ( $AP{'link_type'}>$conf{'STARTLINKCONF'} ) {
				$Query .= ", autoconf=".$link_type{'setparms'}." WHERE port_id=".$AP{'id'};
			    }

                    	    dlog_ap ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => "Update port DB parameters info" );
			    $dbm->do($Query) or dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "ERROR update speed fields in table SWPORTS Querry '".$Query );
			} elsif ($AP{'trust'} and ("x".$fparm->{'login'} ne "x".$AP{'lastlogin'} ) and !($fparm->{'login'} =~ /^(jur|com)test\d+$/ )) {
			    $Query = "UPDATE swports SET start_date='".$date."', login='".$fparm->{'login'}."', mac_port='".$fparm->{'mac'}."'";
			    if ( not $AP{'DB_portinfo'} )  { $Query .= ", portvlan=".$AP{'VLAN'}; }
			    $Query .= " WHERE port_id=".$AP{'id'}." and link_type>".$conf{'STARTLINKCONF'};
                	    dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "Update port login DB info" );
			    $dbm->do($Query) or dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "ERROR update LOGIN in table SWPORTS Query '".$Query );
			}

			if ( not $AP{'trust'} ) {
			    dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "'".$fparm->{'login'}."' access point not agree !!!" );
	    		    $Fres = 1;
			    $Fvalue = 'ap_id:'.$AP{'id'}.';ap_name:'.&$k2w($AP{'name'}).';bw_ctl:'.$AP{'bw_ctl'}.';ap_swid:'.$AP{'swid'}.';ap_communal:'.$AP{'communal'}.';';
			}

		} elsif ( $AP{'VLAN'} ) {
		    dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "AP ID '".$fparm->{'login'}."' in VLAN ".$AP{'VLAN'}." not fixed!!!" );
		    $Fres = 2;
	            $Fvalue = 'error:MAC found in VLAN '.$AP{'VLAN'}.'. Access point not fixed... :-(;';
		}
	}

        dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "Return Res = '".$Fres."', Val = '".$Fvalue."', ZONE = ".$VZONE );
	return ($Fres+0, $Fvalue);
}

sub SW_AP_free {

    my $mysql_life = $dbm->ping;

    my $fparm = shift;
    #	$fparm->{ap_id} = 1234
    ############################ Освобождeние AP
    my $Q_free; my $Fres = 0; my $Fvalue = '';

    $Q_free ="UPDATE swports SET autoconf=".$link_type{'free'}." WHERE port_id=".$fparm{'ap_id'}." and link_type>".$conf{'STARTLINKCONF'}.
    " and autoconf<".$conf{'STARTPORTCONF'}." and type>0 and communal_port=0" ;
    if ( $debug > 1 ) {
        dlog_ap ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS => "DEBUG mode, Query '".$Q_free."'" );
	$Fres = 2;
	$Fvalue = "error: AP_free info in debug mode not update;";;
    } else {
	dlog_ap ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => $Q_free );
	$dbm->do($Q_free) or $Fres = 1;
	if ($Fres) {
	    $Fvalue = "error:Error update AP_free info Query '".$Q_free."';";;
	    dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "ERROR update AP_free info Querry '".$Q_tune."'" ) 
	} else {
	    dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "Closed AP, id N'".$fparm->{'ap_id'}."'" );
	}
    }
    return ($Fres+0, $Fvalue );
}


sub SW_AP_tune {

    my $mysql_life = $dbm->ping;

    my $fparm = shift;
    #	$fparm->{ap_id} = 
    #	$fparm->{port_rate_ds} = 10000
    #	$fparm->{port_rate_us} = 10000
    my $Q_tune; my $Fres = 0; my $Fvalue = '';

    $Q_tune = "UPDATE swports SET autoconf=".$link_type{'setparms'};

    if ( defined($fparm->{'port_rate_ds'}) ) {
	$fparm->{'port_rate_ds'} = -1 if ( $fparm->{'port_rate_ds'} == 0 );
	$Q_tune .= ", ds_speed=".$fparm->{'port_rate_ds'} if ( "x".$fparm->{'port_rate_ds'} ne "x" );
    }
    if ( defined($fparm->{'port_rate_us'}) ) {
	$fparm->{'port_rate_us'} = -1 if ( $fparm->{'port_rate_us'} == 0 );
	$Q_tune .= ", us_speed=".$fparm->{'port_rate_us'} if ( "x".$fparm->{'port_rate_us'} ne "x" );
    }

    $Q_tune .= " WHERE port_id=".$fparm->{'ap_id'}." and communal_port=0 and type>0";
    if ( $debug > 1 ) {
        dlog_ap ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS => "DEBUG mode, Query '".$Q_tune."'" );
        $Fres = 2;
        $Fvalue = "error: AP_free info in debug mode not update;";;
    } else {
        $dbm->do($Q_tune) or $Fres = 1;
        if ($Fres) {
    	    $Fvalue = "error:Error update AP info Query '".$Q_tune."';";
    	    dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "ERROR update AP info Querry '".$Q_tune."'" ) 
        } else {
    	    dlog_ap ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => "UPDATED AP tune info, id N'".$fparm->{'ap_id'}."'" );
	}
    }
    return ($Fres+0, $Fvalue );
}


sub VLAN_VPN_get {

        my $mysql_life = $dbm->ping;

        my %arg = (
            @_,         # список пар аргументов
        );
	# PORT_ID LINK_TYPE ZONE
	my $head = GET_Terminfo ( TYPE => $arg{'LINK_TYPE'}, ZONE => $arg{'ZONE'} );

	my $increment = 1; my $res = -1;

	my %vlanuse = ();
	my $Qr_range = "SELECT vlan_id FROM vlan_list WHERE vlan_id>=".$head->{'VLAN_MIN'}." and vlan_id<=".$head->{'VLAN_MAX'}." and zone_id=".$head->{'VLAN_ZONE'};
        $stm35 = $dbm->prepare($Qr_range);
        $stm35->execute();
	while (my $ref35 = $stm35->fetchrow_hashref()) {
	    $vlanuse{$ref35->{'vlan_id'}} = 1;
	}
	$stm35->finish();
		
	my $vlan_id=0; 
	if ($increment) {
	    $vlan_id = $head->{'VLAN_MIN'};
	    while ( $res < 1 and $vlan_id <= $head->{'VLAN_MAX'} ) {
		dlog_ap ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS =>  "PROBE VLAN N".$vlan_id." VLANDB -> '".( defined($vlanuse{$vlan_id}) ? 'found' : 'none' )."'" );
		$res = $vlan_id if not defined($vlanuse{$vlan_id});
		$vlan_id += 1;
	    }
	} else {
	    $vlan_id = $head->{'VLAN_MAX'};
	    while ( $res < 1 and $vlan_id >= $head->{'VLAN_MIN'} ) {
		dlog_ap ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS => "PROBE VLAN N".$vlan_id." VLANDB -> '".( defined($vlanuse{$vlan_id}) ? 'found' : 'none' )."'" );
		$res = $vlan_id if not defined($vlanuse{$vlan_id});
		$vlan_id -= 1;
	    }
	}

	$dbm->do("INSERT into vlan_list SET info='AUTO INSERT VLAN record from vlan range', vlan_id=".$res.", zone_id=".$head->{'VLAN_ZONE'}.
	", port_id=".$arg{'PORT_ID'}.", link_type=".$arg{'LINK_TYPE'}." ON DUPLICATE KEY UPDATE info='AUTO UPDATE VLAN record', port_id=".
	$arg{'PORT_ID'}.", link_type=".$arg{'LINK_TYPE'}) if ($res > 0 and $debug < 2);
	return ( $res, $head->{'HEAD_ID'} ) ;
}

sub GET_Terminfo {

    my $mysql_life = $dbm->ping;

    dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => 'GET Terminator info (debug)' );
    my %arg = (
        @_,         # список пар аргументов
    );
    # TYPE ZONE TERM_ID
    my %headinfo; my $res = 0;
    $Querry_start = "SELECT * FROM heads WHERE ";
    if ( defined($arg{'TERM_ID'}) and $arg{'TERM_ID'} > 0 ) {
	$Querry_start .= " head_id=".$arg{'TERM_ID'};
    } else {
	$Querry_start .= " head_type=".$arg{'TYPE'};
	$Querry_end = " and vlan_zone=".$arg{'ZONE'};
    }
    my $stm31 = $dbm->prepare($Querry_start.$Querry_end);
    $stm31->execute();
    if (not $stm31->rows) {
	$stm31->finish();
	$Querry_end = " and vlan_zone = -1";
	$stm31 = $dbm->prepare($Querry_start.$Querry_end);
	$stm31->execute();
    }
    if ($stm31->rows == 1) {
	while (my $ref31 = $stm31->fetchrow_hashref()) {
    	    $headinfo{'HEAD_ID'} = $ref31->{'head_id'};
	    $headinfo{'L2SW_ID'} = $ref31->{'l2sw_id'};
	    $headinfo{'L2SW_PORT'} = $ref31->{'l2sw_port'};
	    $headinfo{'L2SW_PORTPREF'} = $ref31->{'l2sw_portpref'};
	    $headinfo{'TERM_USE'} = $ref31->{'term_use'};
	    $headinfo{'TERM_LIB'} = $ref31->{'term_lib'};
	    $headinfo{'TERM_ID'} = $ref31->{'term_id'};
	    $headinfo{'TERM_IP'} = $ref31->{'term_ip'};
	    $headinfo{'TERM_PORT'} = $ref31->{'term_port'};
	    $headinfo{'TERM_PORTPREF'} = $ref31->{'term_portpref'};
	    $headinfo{'TERM_LOGIN1'} = $ref31->{'login1'};
	    $headinfo{'TERM_LOGIN2'} = $ref31->{'login2'};
	    $headinfo{'TERM_PASS1'} = $ref31->{'pass1'};
	    $headinfo{'TERM_PASS2'} = $ref31->{'pass2'};
	    $headinfo{'VLAN_MIN'} = $ref31->{'vlan_min'};
	    $headinfo{'VLAN_MAX'} = $ref31->{'vlan_max'};
	    $headinfo{'UP_ACLIN'} = $ref31->{'up_acl-in'};
	    $headinfo{'UP_ACLOUT'} = $ref31->{'up_acl-out'};
	    $headinfo{'DOWN_ACLIN'} = $ref31->{'down_acl-in'};
	    $headinfo{'DOWN_ACLOUT'} = $ref31->{'down_acl-out'};
	    $headinfo{'LOOP_IF'} = $ref31->{'loop_if'};
	    $headinfo{'VLAN_ZONE'} = $ref31->{'vlan_zone'};
	}
	$res = 1;
	#$stm31->finish();
	#return \%headinfo;
    } elsif ($stm31->rows > 1)  {
	dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "MULTI TERMINATOR! 8-), count = ".$stm31->rows );
    } else {
	dlog_ap ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => 'TERMINATOR NOT FOUND :-(' );
    }
    $stm31->finish();
    return \%headinfo if ($res > 0);
}

1;
