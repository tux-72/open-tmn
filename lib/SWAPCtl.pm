#!/usr/bin/perl -w

package SWAPCtl;

use strict;
no strict qw(refs);

#use locale;

use POSIX qw(strftime);
use cyrillic qw/cset_factory/;


use DBI();
use SWALLCtl;
use SWDBCtl;
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

$VERSION = 1.7;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw( SW_AP_get SW_AP_tune SW_AP_free SW_AP_linkstate );


my $w2k = cset_factory 1251, 20866;
my $k2w = cset_factory 20866, 1251;

my $debug=1;

use FindBin '$Bin';
require $Bin . '/../conf/config.pl';
my $start_conf = \%SWAPCtl::conf;

dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "Use BIN directory - $Bin" );

############ SUBS ##############

my $res; 
 
my $dbm; 
#$res = DB_mysql_connect(\$dbm, \%conf);
$res = DB_mysql_connect(\$dbm);

if ($res < 1) {
    dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "Connect to MYSQL DB FAILED, RESULT = $res" );
    DB_mysql_check_connect(\$dbm);
}

my $LIB_ACT ='';

my @RES = ( 'PASS', 'DENY', 'UNKNOWN' );

my %link_type = ();
my @link_types = ();
my $stm01 = $dbm->prepare("SELECT ltype_id, ltype_name FROM link_types order by ltype_id");
$stm01->execute();
while (my $ref01 = $stm01->fetchrow_hashref()) {
    $link_type{$ref01->{'ltype_name'}}=$ref01->{'ltype_id'} if defined($ref01->{'ltype_name'});
    $link_types[$ref01->{'ltype_id'}]=$ref01->{'ltype_name'} if defined($ref01->{'ltype_name'});
}
$stm01->finish();

my %headinfo = ();
my $stm = $dbm->prepare( "SELECT t.term_ip, t.zone_id, t.term_grey_ip2, h.ip, m.lib, m.mon_login, m.mon_pass FROM heads t, hosts h, models m ".
" WHERE h.model_id=m.model_id and t.l2sw_id=h.sw_id and t.term_ip is not NULL" );
# and t.head_type=".$link_type{'pppoe'});
$stm->execute();
while (my $ref = $stm->fetchrow_hashref()) {
    $headinfo{'L2LIB_'.   $ref->{'term_ip'}} = $ref->{'lib'};
    $headinfo{'L2IP_'.    $ref->{'term_ip'}} = $ref->{'ip'};
    $headinfo{'MONLOGIN_'.$ref->{'term_ip'}} = $ref->{'mon_login'};
    $headinfo{'MONPASS_'. $ref->{'term_ip'}} = $ref->{'mon_pass'};
    $headinfo{'ZONE_'.    $ref->{'term_ip'}} = $ref->{'zone_id'};
}
$stm->finish();

############ SUBS ##############

sub SW_AP_get {

        dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "--" );
	DB_mysql_check_connect(\$dbm);
        my $fparm = shift;
	my $Fres = 2; my $Fvalue = 'ap_id:-1;';	

	#	$fparm->{ap_id} =
	#	$fparm->{nas_ip} = 192.168.100.30
	#	$fparm->{login} = pppoe
	#	$fparm->{link_type} = 21
	#	$fparm->{mac} = 0017.3156.7fd9

	#	$fparm->{port_rate_ds} = 10000
	#	$fparm->{port_rate_us} = 10000
	#	$fparm->{inet_rate} = 1000
	#	$fparm->{ap_vlan} = 239
	#	$fparm->{ip_addr} = 10.13.64.3

	############ Проверка обязательных параметров
	if ( not ( defined($fparm->{'link_type'}) && $fparm->{'link_type'} =~ /^\d+$/ ) ) {
	    return ( $Fres, "error:not defined or broken parameter 'link_type' => '".$fparm->{'link_type'}."';" );
	} else {
	    $fparm->{'link_type'} = $fparm->{'link_type'}+0;
	}
	if ( not ( defined($fparm->{'login'}) && "x".$fparm->{'login'} ne "x" ) ) {
	    return ( $Fres, "error:not defined or broken parameter 'login' => '".$fparm->{'login'}."';" );
	}
	if ( not ( defined($fparm->{'nas_ip'}) && $fparm->{'nas_ip'} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) ) {
	    return ( $Fres, "error:not defined or broken parameter 'nas_ip' => '".$fparm->{'nas_ip'}."';" );
	}

	if ( not ( defined($fparm->{'mac'}) && "x".$fparm->{'mac'} ne "x" ) ) {
	    return ( $Fres, "error:not defined parameter 'MAC';" );
	}

	if	( $fparm->{'mac'} =~ /^(\w\w)(\w\w)\.(\w\w)(\w\w)\.(\w\w)(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif ( $fparm->{'mac'} =~ /^(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif ( $fparm->{'mac'} =~ /^(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif ( $fparm->{'mac'} =~ /^(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)$/) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} else {
           dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "MAC '".$fparm->{'mac'}."' unknown format, exiting ..." );
	    return ( $Fres, "error: broken format in parameter 'mac' => '".$fparm->{'mac'}."';" );
	}
	$fparm->{'mac_src'} = "$1$2$3$4$5$6";


	###################### normalize port speeds #################
	if ( defined($fparm->{'port_rate_ds'}) ) {
	    if ( "x".$fparm->{'port_rate_ds'} eq 'x0' ) {
		$fparm->{'port_rate_ds'} = -1;
	    } elsif ( "x".$fparm->{'port_rate_ds'} eq 'x' ) {
		delete($fparm->{'port_rate_ds'});
	    } elsif ( not $fparm->{'port_rate_ds'} =~ /^\d+$/ ) {
        	return ( $Fres, "error: broken format in parameter 'port_rate_ds' => '".$fparm->{'port_rate_ds'}."';" );
	    }
	}
	if ( defined($fparm->{'port_rate_us'}) ) {
	    if ( "x".$fparm->{'port_rate_us'} eq 'x0' ) {
		$fparm->{'port_rate_us'} = -1;
	    } elsif ( "x".$fparm->{'port_rate_us'} eq 'x' ) {
		delete($fparm->{'port_rate_us'});
	    } elsif ( not $fparm->{'port_rate_us'} =~ /^\d+$/ ) {
        	return ( $Fres, "error: broken format in parameter 'port_rate_us' => '".$fparm->{'port_rate_us'}."';" );
	    }
	}
	###### чистка пустых необязательных параметров
	if ( defined($fparm->{'ap_vlan'}) && "x".$fparm->{'ap_vlan'} eq "x") {
	    delete($fparm->{'ap_vlan'});
	}
	if ( defined($fparm->{'ip_addr'}) && "x".$fparm->{'ip_addr'} eq "x") {
	    delete($fparm->{'ip_addr'});
	}

	####################### GET ACCESS POINT ####################
	my $Query = ''; my $Query10 = ''; my $Query0 = ''; my $Query1 = ''; my $PreQuery = '';
        my $date = strftime "%Y%m%d%H%M%S", localtime(time);
	my $job_parms = '';

	my %AP = (
	    'trust',	0,
	    'set',	0,
	    'VLAN',	0,
	    'vlan_zone',	-1,
	    'update_db',	0,
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
	    #'lastlogin','1',
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
	    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "User '".$fparm->{'login'}."'".' Access point VLAN is not FIX!!! Trobles connect to ZONE SWITCH???' );
	    $Fres = 2;
	    $Fvalue = 'error:MAC VLAN not fixed... :-(;';
	} else {
		dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "User '".$fparm->{'login'}."'".' Access point VLAN = '.$AP{'VLAN'} );
		if ( $AP{'VLAN'} < $start_conf->{'FIRST_ZONEVLAN'} || $headinfo{'ZONE_'.$fparm->{'nas_ip'}} == -1 ) {
		    $AP{'vlan_zone'} = 1;
		} else {
		    $AP{'vlan_zone'} = $headinfo{'ZONE_'.$fparm->{'nas_ip'}};
		}
		############# GET Switch IP's
		my $stm0 = $dbm->prepare("SELECT h.automanage, h.bw_ctl, h.sw_id, h.ip, h.model_id, h.hostname, st.street_name, h.dom, h.podezd, h.unit, m.lib, ".
		"m.mon_login, m.mon_pass FROM hosts h, streets st, models m WHERE h.model_id=m.model_id and h.street_id=st.street_id and m.lib is not NULL and h.clients_vlan=".
		$AP{'VLAN'}." and h.zone_id=".$AP{'vlan_zone'}." and h.visible>0" );
		$stm0->execute();
		#$swrw  = $stm0->rows;
		if ($stm0->rows>1) { dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "More by one switch in VLAN '".$AP{'VLAN'}."'!!!" ); }

		while (my $ref = $stm0->fetchrow_hashref() and not $AP{'id'}) {
			$AP{'automanage'}=1 if ($ref->{'automanage'} == 1);
			$AP{'bw_ctl'}=1 if ($ref->{'bw_ctl'} == 1);

			$LIB_ACT = $ref->{'lib'}.'_fix_macport';
			( $AP{'portpref'}, $AP{'port'} ) = &$LIB_ACT( IP => $ref->{'ip'}, LOGIN => $ref->{'mon_login'}, PASS => $ref->{'mon_pass'}, MAC => $fparm->{'mac'}, VLAN => $AP{'VLAN'});
			if ($AP{'port'}>0 or $stm0->rows == 1) {
    				$AP{'swid'} = $ref->{'sw_id'}; $AP{'podezd'} = $ref->{'podezd'};
                                $AP{'name'} = "ул. ".$ref->{'street_name'}.", д.".$ref->{'dom'};
				$AP{'name'} .= ", п.".$ref->{'podezd'} if $ref->{'podezd'}>0;
				$AP{'name'} .= ", unit N".$ref->{'unit'} if defined($ref->{'unit'});
			}
			if ($AP{'port'}>0) {
				if ( defined($AP{'portpref'}) and 'x'.$AP{'portpref'} ne 'x' ) {
			    	    $Query10 = "SELECT port_id FROM swports WHERE portpref='".$AP{'portpref'}."' and  port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query0 = "SELECT port_id, communal, ds_speed, us_speed, ltype_id, vlan_id, autoneg, speed, duplex, maxhwaddr FROM swports WHERE portpref='".$AP{'portpref'}."' and  port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query1 = "INSERT into swports  SET  status=1, ltype_id=".$link_type{'free'}.", type=1, ds_speed=64, us_speed=64, portpref='".$AP{'portpref'}."', port='".$AP{'port'}."', sw_id='".$AP{'swid'}."', vlan_id=-1";
				} else {
			    	    $Query10 = "SELECT port_id FROM swports WHERE portpref is NULL and port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query0 = "SELECT port_id, communal, ds_speed, us_speed, ltype_id, vlan_id, autoneg, speed, duplex, maxhwaddr FROM swports WHERE portpref is NULL and port='".$AP{'port'}."' and sw_id=".$AP{'swid'};
			    	    $Query1 = "INSERT into swports  SET status=1, ltype_id=".$link_type{'free'}.", type=1, ds_speed=64, us_speed=64, portpref=NULL, port='".$AP{'port'}."', sw_id='".$AP{'swid'}."', vlan_id=-1";
				}
				my $stm10 = $dbm->prepare($Query10);
				$stm10->execute();
				if (not $stm10->rows) {
			    		$dbm->do($Query1);
					dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "Insert New PORT record in swports" );
				}
				$stm10->finish;
				my $stm1 = $dbm->prepare($Query0);
				$stm1->execute();
			    	while (my $refp = $stm1->fetchrow_hashref()) {
					#$AP{'autoconf'} = $refp->{'autoconf'};
					$AP{'link_type'} = $link_type{'free'};
					$AP{'link_type'} = $refp->{'ltype_id'} if defined($refp->{'ltype_id'});
					#$AP{'lastlogin'} = $refp->{'login'} if defined($refp->{'login'});
					$AP{'id'} = $refp->{'port_id'};
					$AP{'communal'} = $refp->{'communal'};
					$AP{'ds'} = $refp->{'ds_speed'} if defined($refp->{'ds_speed'});
					$AP{'us'} = $refp->{'us_speed'} if defined($refp->{'us_speed'});
					#NEW Parameters    
					$AP{'portvlan'} = $refp->{'vlan_id'} if defined($refp->{'vlan_id'});
					#$AP{'ip_subnet'} = $refp->{'ip_subnet'} if defined($refp->{'ip_subnet'});

			    	}
                                        $AP{'name'} .= ", порт ".$AP{'port'};
					$stm1->finish;
			}
			dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => 
			"CLI_VLAN '".$AP{'VLAN'}."' User: '".$fparm->{'login'}."' AP -> '".$AP{'id'}."', '".$AP{'name'}."'" );
		}
		$stm0->finish;
		if (not $AP{'id'}) {
			dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "FIND PORT VLAN '".$AP{'VLAN'}."' User: '".$fparm->{'login'}."', MAC:'".$fparm->{'mac'}."'" );
			$AP{'DB_portinfo'}=1;
			$stm0 = $dbm->prepare( "SELECT h.automanage, h.bw_ctl, h.ip, h.model_id, h.hostname, st.street_name, h.dom, h.podezd, h.unit,".
			" p.sw_id, p.port_id, p.ltype_id, p.communal, p.portpref, p.port, p.ds_speed, p.us_speed, ".
			" p.vlan_id, p.autoneg, p.speed, p.duplex, p.maxhwaddr FROM hosts h, streets st, swports p ".
			" WHERE h.street_id=st.street_id and p.sw_id=h.sw_id and p.vlan_id=".$AP{'VLAN'}." and h.zone_id=".$AP{'vlan_zone'} );
                    	$stm0->execute();
                    	while (my $ref = $stm0->fetchrow_hashref()) {
			    $AP{'port'} = $ref->{'port'} if not defined($ref->{'portpref'});
			    $AP{'port'} = $ref->{'portpref'}.$ref->{'port'} if defined($ref->{'portpref'});
                            $AP{'swid'} = $ref->{'sw_id'}; $AP{'podezd'} = $ref->{'podezd'};

                            $AP{'name'} = "ул. ".$ref->{'street_name'}.", д.".$ref->{'dom'};
                            $AP{'name'} .= ", п.".$ref->{'podezd'} if $ref->{'podezd'}>0;
                            $AP{'name'} .= ", unit N".$ref->{'unit'} if defined($ref->{'unit'});
                            $AP{'name'} .= ", порт ".$AP{'port'};

			    $AP{'link_type'} = $link_type{'free'};
			    $AP{'link_type'} = $ref->{'ltype_id'} if defined($ref->{'ltype_id'});
			    #$AP{'autoconf'} = $ref->{'autoconf'};

			    #$AP{'lastlogin'} = $ref->{'login'}  if defined($ref->{'login'});
			    $AP{'automanage'}=1 if ($ref->{'automanage'} == 1);
			    $AP{'bw_ctl'}=1 if ($ref->{'bw_ctl'} == 1);

			    $AP{'ds'} = $ref->{'ds_speed'} if defined($ref->{'ds_speed'});
			    $AP{'us'} = $ref->{'us_speed'} if defined($ref->{'us_speed'});
			    #NEW Parameters
			    $AP{'portvlan'} = $ref->{'vlan_id'} if defined($ref->{'vlan_id'});
			    #$AP{'ip_subnet'} = $ref->{'ip_subnet'} if defined($ref->{'ip_subnet'});

			    if ($AP{'id'}) {
				dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "MULTI TD's!!! = '".$AP{'id'}."' and '".$ref->{'port_id'}."'" );
				$AP{'id'} = 0; $AP{'swid'} = 0; $AP{'podezd'}=0; $AP{'name'}=''; $AP{'port'}=0;
				last;
			    }
			    $AP{'id'} = $ref->{'port_id'};
			    $AP{'communal'} = $ref->{'communal'};
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => 
			    "VLAN '".$AP{'VLAN'}."' User: '".$fparm->{'login'}."' AP -> '".$AP{'id'}."', '".$AP{'name'}."'" );
			}
			    $stm0->finish;
		}

		################### Если выяснили AP_ID ######################
		if ($AP{'id'}) {
			$Fres = 1;
			$Fvalue = 'ap_id:'.$AP{'id'}.';ap_name:'.&$k2w($AP{'name'}).';bw_ctl:'.$AP{'bw_ctl'}.';ap_swid:'.$AP{'swid'}.';ap_communal:'.$AP{'communal'}.';';
			if ( $fparm->{'ap_id'} and $fparm->{'ap_id'} == $AP{'id'} ) {
			    $Fres = 0; $AP{'trust'}=1;

    			    if ( ( $AP{'link_type'} != $fparm->{'link_type'}
				|| ( 'x'.$fparm->{'port_rate_us'} ne 'x' and $AP{'us'} != $fparm->{'port_rate_us'} )
				|| ( 'x'.$fparm->{'port_rate_ds'} ne 'x' and $AP{'ds'} != $fparm->{'port_rate_ds'} )
				#|| ( defined($fparm->{'vlan_id'}) and $AP{'portvlan'} != $fparm->{'vlan_id'} )
			    ) and ! $AP{'communal'} ) {
				$AP{'set'} = 1;
			    }
			    #if ($AP{'communal'}) { $AP{'set'} = 0; } 

                            dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS =>
			    "AP_set = '".$AP{'set'}."', AP_DS = '".$fparm->{'port_rate_ds'}."', AP_US = '".$fparm->{'port_rate_us'}."'" );
			} else {
			    $AP{'trust'} = 0; $AP{'set'} = 0
			}
			$Query = "INSERT INTO ap_login_info SET trust=".$AP{'trust'}.", login='".$fparm->{'login'}."', start_date='".$date."', last_date='".$date."'";
			$Query .= ", hw_mac='".$fparm->{'mac'}."', vlan_id='".$AP{'VLAN'}."', port_id='".$AP{'id'}."', ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."'";
			$Query .= " ON DUPLICATE KEY UPDATE trust=".$AP{'trust'}.", ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."', last_date='".$date."', vlan_id='".$AP{'VLAN'}."'";
			$dbm->do("$Query");
			#### TEMP SET
			#$AP{'lastlogin'} = '';
			# SET PARMS!!!
			#if ($AP{'set'} and $AP{'automanage'} and !( $fparm->{'login'} =~ /^(jur|com)test\d+$/ )) {
		######################## SET JOB PARAMETERS
			if ( $AP{'set'} and $AP{'automanage'} ) {
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "Access Point parm change" );
			    $AP{'update_db'}=1;
		    	    $Query = "INSERT INTO bundle_jobs SET port_id=".$AP{'id'};
			    $job_parms  = 'login:'.$fparm->{'login'}.';hw_mac:'.$fparm->{'mac_src'}.';';
			    $job_parms .= 'ds_speed:'.$fparm->{'port_rate_ds'}.';' if defined($fparm->{'port_rate_ds'});
			    $job_parms .= 'us_speed:'.$fparm->{'port_rate_us'}.';' if defined($fparm->{'port_rate_us'});

			    ########  VPN  VLAN  ########
			    if ( $fparm->{'link_type'} == $link_type{'l2link'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
				if ( "x".$fparm->{'vlan_id'} eq "x" and $AP{'link_type'} != $link_type{'l2link'} ) {
				    ( $fparm->{'vlan_id'}, $AP{'link_head'} ) = VLAN_VPN_get ( PORT_ID => $AP{'id'}, 
				    LINK_TYPE => $link_type{'l2link'}, ZONE => $AP{'vlan_zone'} );
				    if ( $fparm->{'vlan_id'} > 1 ) {
					$Fvalue .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
		    			$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
		    			$job_parms .= 'link_head:'.$AP{'link_head'}.';'  if ( $AP{'link_head'} > 1 );
				    }
				} elsif ("x".$fparm->{'vlan_id'} ne "x"  and $AP{'link_type'} != $link_type{'l2link'}) {
		    		    $job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
				}
			    }
			    ######## Transport Net ############
		    	    if ( defined($fparm->{'ip_addr'}) and $fparm->{'link_type'} == $link_type{'l3net4'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
				$job_parms .= 'ip_subnet:'.$fparm->{'ip_addr'}.'/30;';
			    }

			    # Проверка изменений link_type
			    ## Если порт был свободен и задействуется под PPPoE
			    if ( $AP{'link_type'} == $link_type{'free'} and $fparm->{'link_type'} == $start_conf->{'CLI_VLAN_LINKTYPE'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
		    		$job_parms .= 'vlan_id:'.$AP{'VLAN'}.';';
			    ## Иначе если порт был свободен и задействуется под другие типы подключений  
			    } elsif ( $AP{'link_type'} == $link_type{'free'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
		    		$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';' if ( $fparm->{'vlan_id'} > 1 );
			    ## Иначе если порт занят под такой же тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $fparm->{'link_type'}+0 == $AP{'link_type'}+0 ) {
				$Query .= ", ltype_id=".$link_type{'setparms'};
		    		$job_parms .= 'vlan_id:'.$AP{'VLAN'}.';';
			    ## Иначе если порт ЗАНЯТ! и задействуется под другой тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $fparm->{'link_type'}+0 != $AP{'link_type'}+0  ) {
				$PreQuery .= "INSERT INTO bundle_jobs SET port_id=".$AP{'id'}.", ltype_id=".$link_type{'free'}.' ON DUPLICATE KEY UPDATE date_insert=NULL';

				$Query .= ", ltype_id=".$fparm->{'link_type'};
		    		$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';' if ( $fparm->{'vlan_id'} > 1 );
			    } else {
				$AP{'update_db'}=0;
			    }

			    if ( $AP{'update_db'} ) {
				if ("x".$PreQuery ne "x" ) { $dbm->do($PreQuery); }
				$Query .= ", parm='".$job_parms."', archiv=0 ON DUPLICATE KEY UPDATE date_insert=NULL, parm='".$job_parms."'";
                    		dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "Update port DB parameters info" );
				$dbm->do($Query) or dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', 
				MESS => "ERROR change table 'Bundle_jobs' Querry --".$Query."--" );
			    } else {
				dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', 
				MESS => "Error: Different link_types, possible PORT type is FREE?" );
			    }
			}

			if ( not $AP{'trust'} ) {
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "'".$fparm->{'login'}."' access point not agree !!!" );
	    		    $Fres = 1;
			    $Fvalue = 'ap_id:'.$AP{'id'}.';ap_name:'.&$k2w($AP{'name'}).';bw_ctl:'.$AP{'bw_ctl'}.';ap_swid:'.$AP{'swid'}.';ap_communal:'.$AP{'communal'}.';';
			}

		} elsif ( $AP{'VLAN'} ) {
		    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "AP ID '".$fparm->{'login'}."' in VLAN ".$AP{'VLAN'}." not fixed!!!" );
		    $Fres = 2;
	            $Fvalue = 'error:MAC found in VLAN '.$AP{'VLAN'}.'. Access point not fixed... :-(;';
		}
	}
        dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => 
	"QUERY: Login  = '".$fparm->{'login'}."', MAC = '".$fparm->{'mac'}."', NAS_IP = ".$fparm->{'nas_ip'}."\n".
	"AP_CHECK: ".$RES[$Fres].'('.$Fres.')'.", Login = '".$fparm->{'login'}."', AP_ID = '".$AP{'id'}."', '".$AP{'name'}.", ZONE = ".$AP{'vlan_zone'}.", VLAN = ".$AP{'VLAN'}."'\n".
	"REPLY: ".$Fres.", '".&$w2k($Fvalue)."'" );

	return ($Fres+0, $Fvalue);
}


sub SW_AP_free {

    DB_mysql_check_connect(\$dbm);

    my $Q_free; my $Fres = 0; my $Fvalue = '';

    my $fparm = shift;
    #	$fparm->{ap_id} = 1234
    if  ( not ( defined($fparm->{'ap_id'}) && $fparm->{'ap_id'} =~ /^\d+$/ ) ) {
        return ( $Fres, "error:not defined parameter 'ap_id';" );
    }
    ############################ Освобождeние AP

    $Q_free = "INSERT INTO bundle_jobs SET port_id=".$fparm->{'ap_id'}.", ltype_id=".$link_type{'free'}.' ON DUPLICATE KEY UPDATE date=NULL';

    if ( $debug > 1 ) {
        dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "DEBUG mode, Query '".$Q_free."'" );
	$Fres = 2;
	$Fvalue = "error: AP_free info in debug mode not update;";;
    } else {
	dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => $Q_free );
	$dbm->do($Q_free) or $Fres = 1;
	if ($Fres) {
	    $Fvalue = "error:Error update AP_free info Query '".$Q_free."';";;
	    dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "ERROR update AP_free info Querry '".$Q_free."'" ) 
	} else {
	    dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "Closed AP, id N'".$fparm->{'ap_id'}."'" );
	}
    }
    return ($Fres+0, $Fvalue );
}


sub SW_AP_tune {

    DB_mysql_check_connect(\$dbm);

    my $Q_tune; my $Q_parm = ''; my $Fres = 0; my $Fvalue = ''; my $parmset = 0;

    my $fparm = shift;
    #	$fparm->{ap_id} = 
    #	$fparm->{port_rate_ds} = 10000
    #	$fparm->{port_rate_us} = 10000
    if  ( not ( defined($fparm->{'ap_id'}) && $fparm->{'ap_id'} =~ /^\d+$/ ) ) {
        return ( $Fres, "error:not defined or broken parameter 'ap_id';" );
    }
    if ( defined($fparm->{'port_rate_ds'}) ) {
	if ( "x".$fparm->{'port_rate_ds'} eq 'x0' ) {
	    $fparm->{'port_rate_ds'} = -1;
	} elsif ( "x".$fparm->{'port_rate_ds'} eq 'x' ) {
	    delete($fparm->{'port_rate_ds'});
	} elsif ( not $fparm->{'port_rate_ds'} =~ /^\d+$/ ) {
	    return ( $Fres, "error: broken format in parameter 'port_rate_ds' => '".$fparm->{'port_rate_ds'}."';" );
	}
    }
    if ( defined($fparm->{'port_rate_us'}) ) {
	if ( "x".$fparm->{'port_rate_us'} eq 'x0' ) {
	    $fparm->{'port_rate_us'} = -1;
	} elsif ( "x".$fparm->{'port_rate_us'} eq 'x' ) {
	    delete($fparm->{'port_rate_us'});
	} elsif ( not $fparm->{'port_rate_us'} =~ /^\d+$/ ) {
    	    return ( $Fres, "error: broken format in parameter 'port_rate_us' => '".$fparm->{'port_rate_us'}."';" );
	}
    }


    if ( defined($fparm->{'port_rate_ds'}) ) { $Q_parm .= 'ds_speed:'.$fparm->{'port_rate_ds'}.';'; $parmset += 1; }
    if ( defined($fparm->{'port_rate_us'}) ) { $Q_parm .= 'us_speed:'.$fparm->{'port_rate_us'}.';'; $parmset += 1; }

    $Q_tune = "INSERT INTO bundle_jobs SET port_id=".$fparm->{'ap_id'}.", ltype_id=".$link_type{'setparms'}.", parm='".
    $Q_parm."' ON DUPLICATE KEY UPDATE date=NULL, parm='".$Q_parm."'";

    if ( $debug > 1 ) {
        dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "DEBUG mode, Query '".$Q_tune."'" );
	#$Fres = 2;
	#$Fvalue = "error: ap_free info in debug mode not update;";
    } elsif (not $parmset) {
	$Fres = 2;
	$Fvalue = "error: not found change parameters;";
    } else {
        $dbm->do($Q_tune) or $Fres = 1;
        if ($Fres) {
    	    $Fvalue = "error:Error update AP info Query '".$Q_tune."';";
    	    dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "ERROR update AP info Querry '".$Q_tune."'" ) 
        } else {
    	    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "UPDATED AP tune info, id N'".$fparm->{'ap_id'}."'" );
	}
    }
    return ($Fres+0, $Fvalue );
}

sub SW_AP_linkstate {
    DB_mysql_check_connect(\$dbm);
    my $Fres = 2; my $Fvalue = 'error:unknown error...;';
    my %state = (   'lock' 	=> 2,
		    'unlock'	=> 1,
		);

    my $fparm = shift;
    #	$fparm->{ap_id} = 1234
    #	$fparm->{state}=lock
    #	$fparm->{state}=unlock
    if		( not ( defined($fparm->{'ap_id'}) && $fparm->{'ap_id'} =~ /^\d+$/ ) ) {
	return ( $Fres, "error:not defined parameter 'ap_id';" );
    } elsif	( not ( defined($fparm->{'state'}) && $fparm->{'state'} =~ /^(unl|l)ock$/ ) ) {
	return ( $Fres, "error:not defined or broken parameter 'state';" );
    }
    my $stm_state = $dbm->prepare( "SELECT status FROM head_link where port_id=".$fparm->{'ap_id'} );
    $stm_state->execute or $Fres = 1;
    if ( $Fres == 1 || not $stm_state->rows == 1 ) {
	$Fres = 2;
	$Fvalue = 'error:AP head link not found;';
    } else {
	$dbm->do( "UPDATE head_link SET set_status=".$state{$fparm->{'state'}}." WHERE port_id=".$fparm->{'ap_id'}." and status<>".$state{$fparm->{'state'}} ) or $Fres = 1;
	if ( $Fres == 1 ) {
	    $Fvalue = 'error:Error update AP state info;';
	} else {
	    $Fres = 0;
	    $Fvalue = 'result:state sync success;';
	}
    }
    return ( $Fres+0, $Fvalue );
}


sub VLAN_VPN_get {

	DB_mysql_check_connect(\$dbm);

        my %arg = (
            @_,         # список пар аргументов
        );
	# PORT_ID LINK_TYPE ZONE
	my $head = GET_Terminfo ( TYPE => $arg{'LINK_TYPE'}, ZONE => $arg{'ZONE'} );

	my $increment = 1; my $res = -1;

	my %vlanuse = ();
	my $Qr_range = "SELECT vlan_id FROM vlan_list WHERE vlan_id>=".$head->{'VLAN_MIN'}." and vlan_id<=".$head->{'VLAN_MAX'}." and zone_id=".$head->{'VLAN_ZONE'};
        my $stm35 = $dbm->prepare($Qr_range);
        $stm35->execute();
	while (my $ref35 = $stm35->fetchrow_hashref()) {
	    $vlanuse{$ref35->{'vlan_id'}} = 1;
	}
	$stm35->finish();
		
	my $vlan_id=0; 
	if ($increment) {
	    $vlan_id = $head->{'VLAN_MIN'};
	    while ( $res < 1 and $vlan_id <= $head->{'VLAN_MAX'} ) {
		dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS =>  "PROBE VLAN N".$vlan_id." VLANDB -> '".( defined($vlanuse{$vlan_id}) ? 'found' : 'none' )."'" );
		$res = $vlan_id if not defined($vlanuse{$vlan_id});
		$vlan_id += 1;
	    }
	} else {
	    $vlan_id = $head->{'VLAN_MAX'};
	    while ( $res < 1 and $vlan_id >= $head->{'VLAN_MIN'} ) {
		dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "PROBE VLAN N".$vlan_id." VLANDB -> '".( defined($vlanuse{$vlan_id}) ? 'found' : 'none' )."'" );
		$res = $vlan_id if not defined($vlanuse{$vlan_id});
		$vlan_id -= 1;
	    }
	}

	if ($res > 0 and $debug < 2) { 
	    $dbm->do("INSERT into vlan_list SET info='AUTO INSERT VLAN record from vlan range', vlan_id=".$res.", zone_id=".$head->{'VLAN_ZONE'}.
	    ", port_id=".$arg{'PORT_ID'}.", link_type=".$arg{'LINK_TYPE'}." ON DUPLICATE KEY UPDATE info='AUTO UPDATE VLAN record', port_id=".
	    $arg{'PORT_ID'}.", link_type=".$arg{'LINK_TYPE'}); 
	}
	return ( $res, $head->{'HEAD_ID'} ) ;
}

sub GET_Terminfo {

    DB_mysql_check_connect(\$dbm);

    my %headinfo; my $res = 0; my $Querry_start; my $Querry_end;

    dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => 'GET Terminator info (debug)' );
    my %arg = (
        @_,         # список пар аргументов
    );
    # TYPE ZONE TERM_ID

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
    } elsif ($stm31->rows > 1) {
	dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "MULTI TERMINATOR! 8-), count = ".$stm31->rows );
    } else {
	dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => 'TERMINATOR NOT FOUND :-(' );
    }
    $stm31->finish();
    return \%headinfo if ($res > 0);
}

1;
