#!/usr/bin/perl

package SWAPCtl;

#use strict;
#use locale;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use cyrillic qw/cset_factory/;

$VERSION = 1.2;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
@EXPORT_TAGS = ();

@EXPORT = qw(	SW_AP_get
	    );

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

my $w2k = cset_factory 1251, 20866;
my $k2w = cset_factory 20866, 1251;

my $debug=1;

### LOG 
my $logfile='/var/log/dispatcher/ap_get.log';

use FindBin '$Bin';
require $Bin . '/../conf/config.pl';
dlog_ap_get ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS => "Use BIN directory - $Bin" );

############ SUBS ##############

#my $dbm; $res = DB_mysql_connect(\$dbm);
#if ($res < 1) {
#    dlog_ap_get ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "Connect to DB FAILED, RESULT = $res" );
#    exit;
#}

my $dbm = DBI->connect("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'})
or die dlog_ap_get ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS => "Unable to connect MYSQL DB host ".$conf{'MYSQL_host'}."$DBI::errstr" );
$dbm->do("SET NAMES 'koi8r'") or die return -1;


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
}
$stm->finish();

############ SUBS ##############

sub SW_AP_get {
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
        my $date = strftime "%Y%m%d%H%M%S", localtime(time);


	if      ( $fparm->{'mac'} =~ /^(\w\w)(\w\w)\.(\w\w)(\w\w)\.(\w\w)(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif ( $fparm->{'mac'} =~ /^(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif ( $fparm->{'mac'} =~ /^(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif (! $fparm->{'mac'} =~ /^(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)$/) {
           dlog_ap_get ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "MAC '".$fparm->{'mac'}."' unknown format, exiting ..." );
	    return ( $Fres, $Fvalue );
	}

	my %AP = (
	    'trust',	0,
	    'set',	0,
	    'VLAN',	0,
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
	    dlog_ap_get ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => "User '".$fparm->{'login'}."'".' Access point VLAN is not FIX!!! Trobles connect to ZONE SWITCH???' );
	    $Fres = 2;
	    $Fvalue = 'error:MAC VLAN not fixed... :-(;';
	} else {
		############# GET Switch IP's 
		$stm0 = $dbm->prepare("SELECT s.automanage, s.bw_ctl, s.id, s.ip, s.model, s.hostname, s.idhouse, s.podezd, s.unit, h.idhouse, h.street, h.dom, m.lib, ".
		"m.mon_login, m.mon_pass FROM hosts s, houses h, models m WHERE s.model=m.id and s.idhouse=h.idhouse and m.lib is not NULL and s.clients_vlan='".$AP{'VLAN'}."'");
		$stm0->execute();
		#$swrw  = $stm0->rows;
		dlog_ap_get ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => "Greater by one switches in VLAN '".$AP{'VLAN'}."'!!!" ) if $stm0->rows>1;

		while ($ref = $stm0->fetchrow_hashref() and not $AP{'id'}) {
			$AP{'autoconf'}=1 if ($ref->{'automanage'} == 1);
			$AP{'bw_ctl'}=1 if ($ref->{'bw_ctl'} == 1);

			$LIB_ACT = $ref->{'lib'}.'_fix_macport';
			( $AP{'portpref'}, $AP{'port'} ) = &$LIB_ACT( IP => $ref->{'ip'}, LOGIN => $ref->{'mon_login'}, PASS => $ref->{'mon_pass'}, MAC => $fparm->{'mac'}, VLAN => $AP{'VLAN'});
			if ($AP{'port'}>0 or $stm0->rows == 1) {
    				$AP{'swid'} = $ref->{'id'}; $AP{'house'} = $ref->{'idhouse'}; $AP{'podezd'} = $ref->{'podezd'};
                                $AP{'name'} = "ул. ".$ref->{'street'}.", д.".$ref->{'dom'};
				$AP{'name'} .= ", п.".$ref->{'podezd'} if $ref->{'podezd'}>0;
				$AP{'name'} .= ", unit N".$ref->{'unit'} if defined($ref->{'podezd'});
			}
			if ($AP{'port'}>0) {
				if ( defined($AP{'portpref'}) and 'x'.$AP{'portpref'} ne 'x' ) {
			    	    $Query10 = "SELECT port_id FROM swports WHERE portpref='".$AP{'portpref'}."' and  port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query0 = "SELECT port_id, ds_speed, us_speed, link_type, login, portvlan, ip_subnet, autoneg, speed, duplex, maxhwaddr FROM swports WHERE portpref='".$AP{'portpref'}."' and  port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query1 = "INSERT into swports  SET  status=1, link_type=".$link_type{'free'}.", type=1, ds_speed=64, us_speed=64, portpref='".$AP{'portpref'}."', port='".$AP{'port'}."', sw_id='".$AP{'swid'}."', portvlan=".$AP{'VLAN'};
				} else {
			    	    $Query10 = "SELECT port_id FROM swports WHERE portpref is NULL and port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query0 = "SELECT port_id, ds_speed, us_speed, link_type, login, portvlan, ip_subnet, autoneg, speed, duplex, maxhwaddr FROM swports WHERE portpref is NULL and port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query1 = "INSERT into swports  SET status=1, link_type=".$link_type{'free'}.", type=1, ds_speed=64, us_speed=64, portpref=NULL, port='".$AP{'port'}."', sw_id='".$AP{'swid'}."', portvlan=".$AP{'VLAN'};
				}
				my $stm10 = $dbm->prepare($Query10);
				$stm10->execute();
				if (not $stm10->rows) {
			    		$dbm->do($Query1);
					dlog_ap_get ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => "Insert New PORT record in swports" );
				}
				$stm10->finish;
				my $stm1 = $dbm->prepare($Query0);
				$stm1->execute();
			    	while (my $refp = $stm1->fetchrow_hashref()) {
					$AP{'db_link_type'} = $link_type{'free'};
					$AP{'db_link_type'} = $refp->{'link_type'} if defined($refp->{'link_type'});
					$AP{'lastlogin'} = $refp->{'login'} if defined($refp->{'login'});
					$AP{'id'} = $refp->{'port_id'};
					$AP{'ds'} = $refp->{'ds_speed'} if defined($refp->{'ds_speed'});
					$AP{'us'} = $refp->{'us_speed'} if defined($refp->{'us_speed'});
					#NEW Parameters    
					$AP{'portvlan'} = $refp->{'portvlan'} if defined($refp->{'portvlan'});
					$AP{'ip_subnet'} = $refp->{'ip_subnet'} if defined($refp->{'ip_subnet'});

			    	}
                                        $AP{'name'} .= ", порт ".$AP{'port'};
					$stm1->finish;
			}
			dlog_ap_get ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => 
			"CLI_VLAN '".$AP{'VLAN'}."' User: '".$fparm->{'login'}."' AP -> '".$AP{'id'}."', '".$AP{'name'}."'" );
		}
		$stm0->finish;
		if (not $AP{'id'}) {
			$AP{'DB_portinfo'}=1;
			$stm0 = $dbm->prepare("SELECT s.automanage, s.bw_ctl, s.id, s.ip, s.model, s.hostname, s.idhouse, s.podezd, s.unit, h.idhouse, ".
			"h.street, h.dom, p.sw_id, p.port_id, p.portpref, p.link_type, p.port, p.ds_speed, p.us_speed, p.login, ".
			"p.portvlan, p.ip_subnet, p.autoneg, p.speed, p.duplex, p.maxhwaddr FROM hosts s, houses h, swports p ".
			"WHERE s.idhouse=h.idhouse and p.sw_id=s.id and p.portvlan=".$AP{'VLAN'});
                    	$stm0->execute();
                    	while ($ref = $stm0->fetchrow_hashref()) {
			    $AP{'port'} = $ref->{'port'} if not defined($ref->{'portpref'});
			    $AP{'port'} = $ref->{'portpref'}.$ref->{'port'} if defined($ref->{'portpref'});
                            $AP{'swid'} = $ref->{'sw_id'}; $AP{'house'} = $ref->{'idhouse'}; $AP{'podezd'} = $ref->{'podezd'};

                            $AP{'name'} = "ул. ".$ref->{'street'}.", д.".$ref->{'dom'};
                            $AP{'name'} .= ", п.".$ref->{'podezd'} if $ref->{'podezd'}>0;
                            $AP{'name'} .= ", unit N".$ref->{'unit'} if defined($ref->{'podezd'});
                            $AP{'name'} .= ", порт ".$AP{'port'};

			    $AP{'db_link_type'} = $link_type{'free'};
			    $AP{'db_link_type'} = $ref->{'link_type'} if defined($ref->{'link_type'});

			    $AP{'lastlogin'} = $ref->{'login'}  if defined($ref->{'login'});
			    $AP{'autoconf'}=1 if ($ref->{'automanage'} == 1);
			    $AP{'bw_ctl'}=1 if ($ref->{'bw_ctl'} == 1);
			    $AP{'ds'} = $ref->{'ds_speed'} if defined($ref->{'ds_speed'});
			    $AP{'us'} = $ref->{'us_speed'} if defined($ref->{'us_speed'});
			    #NEW Parameters
			    $AP{'portvlan'} = $ref->{'portvlan'} if defined($ref->{'portvlan'});
			    $AP{'ip_subnet'} = $ref->{'ip_subnet'} if defined($ref->{'ip_subnet'});

			    if ($AP{'id'}) {
				dlog_ap_get ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "MULTI TD's!!! = '".$AP{'id'}."' and '".$ref->{'port_id'}."'" );
				$AP{'id'} = 0; $AP{'swid'} = 0; $AP{'house'}=0; $AP{'podezd'}=0; $AP{'name'}=''; $AP{'port'}=0;
				last;
			    }
			    $AP{'id'} = $ref->{'port_id'};
			    dlog_ap_get ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => 
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

		if ($AP{'id'}) {
			$Fres = 1;
			$Fvalue = 'ap_id:'.$AP{'id'}.';ap_name:'.&$k2w($AP{'name'}).';bw_ctl:'.$AP{'bw_ctl'}.';ap_swid:'.$AP{'swid'}.';';
			if ( $fparm->{ap_id} and $fparm->{ap_id} == $AP{'id'} ) {
			    $Fres = 0;
    			    if ( $AP{'db_link_type'} != $fparm->{'link_type'}
				|| $AP{'us'} != $fparm->{'port_rate_us'}
				|| $AP{'ds'} != $fparm->{'port_rate_ds'}
				|| ( defined($fparm->{'portvlan'}) and $AP{'portvlan'}  != $fparm->{'portvlan'} )
				|| ( defined($fparm->{'ip_addr'})  and $AP{'ip_subnet'} ne $fparm->{'ip_addr'} )
			    ) { 
				$AP{'set'} = 1;
			    } 
			    $AP{'inet_rate'}	= $fparm->{'inet_rate'} 	if defined($fparm->{'inet_rate'});
			    $AP{'ds'} 		= $fparm->{'port_rate_ds'} 	if defined($fparm->{'port_rate_ds'});
			    $AP{'us'} 		= $fparm->{'port_rate_us'} 	if defined($fparm->{'port_rate_us'});
			    #NEW Parameters
			    # Костылик
			    $AP{'link_type'}	= $link_type{'pppoe'};
			    $AP{'link_type'}	= $fparm->{'link_type'} if defined($fparm->{'link_type'});
			    $AP{'portvlan'}	= $fparm->{'portvlan'}	if defined($fparm->{'portvlan'});
			    $AP{'ip_subnet'}	= $fparm->{'ip_addr'}	if defined($fparm->{'ip_addr'});

                            dlog_ap_get ( SUB => (caller(0))[3], DBUG => 2, LOGFILE => $logfile, MESS =>
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
		    	    $Query .= ", portvlan=".$AP{'VLAN'} if not $AP{'DB_portinfo'};
		    	    $Query .= ", ip_subnet='".$AP{'ip_subnet'} if $AP{'link_type'} == $link_type{'l3net4'};
			    $Query .= ", autoconf=".$AP{'link_type'}." WHERE port_id=".$AP{'id'}." and link_type=".$link_type{'free'} if $AP{'db_link_type'} == $link_type{'free'};
			    $Query .= ", autoconf=".$link_type{'setparms'}." WHERE port_id=".$AP{'id'} if $AP{'link_type'}>$conf{'STARTLINKCONF'};

                    	    dlog_ap_get ( SUB => (caller(0))[3], DBUG => 1, LOGFILE => $logfile, MESS => "Update port DB parameters info" );
			    $dbm->do($Query) or dlog_ap_get ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "ERROR update speed fields in table SWPORTS '".$fparm->{'login'}.
			    "' '".$fparm->{'mac'}."' '".$AP{'id'}."' '".$AP{'ds'}."' '".$AP{'us'}."'" );
			} elsif ($AP{'trust'} and ("x".$fparm->{'login'} ne "x".$AP{'lastlogin'} ) and !($fparm->{'login'} =~ /^(jur|com)test\d+$/ )) {
			    $Query = "UPDATE swports SET start_date='".$date."', login='".$fparm->{'login'}."', mac_port='".$fparm->{'mac'}."'";
			    $Query .= ", portvlan=".$AP{'VLAN'} if not $AP{'DB_portinfo'};
			    $Query .= " WHERE port_id=".$AP{'id'}." and link_type>".$conf{'STARTLINKCONF'};
                	    dlog_ap_get ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "Update port login DB info" );
			    $dbm->do($Query) or dlog_ap_get ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "ERROR update LOGIN in table SWPORTS '".
			    $fparm->{'login'}."' '".$fparm->{'mac'}."' '".$AP{'id'}."'" );
			}

			if ( not $AP{'trust'} ) {
			    dlog_ap_get ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "'".$fparm->{'login'}."' access point not agree !!!" );
	    		    $Fres = 1;
			    $Fvalue = 'ap_id:'.$AP{'id'}.';ap_name:'.&$k2w($AP{'name'}).';bw_ctl:'.$AP{'bw_ctl'}.';ap_swid:'.$AP{'swid'}.';';
			}

		} elsif ( $AP{'VLAN'} ) {
		    dlog_ap_get ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "AP ID '".$fparm->{'login'}."' in VLAN ".$AP{'VLAN'}." not fixed!!!" );

		    $Query_vl = "INSERT INTO user_mac_port SET login='".$fparm->{'login'}."', start_date='".$date."', last_date='".$date."', mac='".$fparm->{'mac'}."', vlan=".
		    $AP{'VLAN'}.", td=0, td_name='".$AP{'name'}."', idhouse=".$AP{'house'}.", podezd='".$AP{'podezd'}."', sw_id=".$AP{'swid'}.
		    ", port=NULL ON DUPLICATE KEY UPDATE td_name='".$AP{'name'}."', idhouse=".$AP{'house'}.", podezd='".$AP{'podezd'}."', sw_id=".$AP{'swid'}.
		    ",last_date='".$date."', vlan=".$AP{'VLAN'} ;

		    $dbm->do("$Query_vl") || dlog_ap_get ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => 
		     "ERROR INSERT INTO user_mac_port Querry: ".$Query_vl );

		    $Fres = 2;
	            $Fvalue = 'error:MAC found in VLAN '.$AP{'VLAN'}.'. Access point not fixed... :-(;';
		}
	}

        dlog_ap_get ( SUB => (caller(0))[3], DBUG => 0, LOGFILE => $logfile, MESS => "Return Res = '".$Fres."', Val = '".$Fvalue."'" );
	return ($Fres, $Fvalue);
}


1;
