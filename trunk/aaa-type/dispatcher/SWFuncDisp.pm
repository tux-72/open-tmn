#!/usr/bin/perl

my $debug=1;

package SWFuncDisp;

use strict;

#use locale;
use POSIX qw(strftime);
use DBI();
use FindBin '$Bin';
use lib $Bin.'/../../lib';

use SWConf;
use SWFunc;
use SWFuncAAA;

use Authen::Radius;
Authen::Radius->load_dictionary();

use Data::Dumper;

use Encode;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();

$VERSION = 1.0;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw( SW_AP_get SW_AP_tune SW_AP_free SW_AP_linkstate SW_send_pod
);

my $start_conf	= \%SWConf::conf;
my $dbi		= \%SWConf::dbconf;
my $nas_conf	= \%SWConf::aaa_conf;

my $Querry_start = '';
my $Querry_end = '';
my $res;
my $dbm;

DB_mysql_connect(\$dbm);

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

our %headinfo = ();
my $stm = $dbm->prepare( "SELECT t.linked_head, t.term_ip, t.zone_id, t.term_grey_ip2, h.ip, m.lib, m.mon_login, m.mon_pass FROM heads t, hosts h, models m ".
" WHERE t.ltype_id<>".$link_type{'l3net4'}." and h.model_id=m.model_id and t.l2sw_id=h.sw_id and t.term_ip is not NULL order by head_id desc" );
$stm->execute();
while (my $ref = $stm->fetchrow_hashref()) {
    $headinfo{'L2LIB_'.   $ref->{'term_ip'}} = $ref->{'lib'};
    $headinfo{'L2IP_'.    $ref->{'term_ip'}} = $ref->{'ip'};
    $headinfo{'MONLOGIN_'.$ref->{'term_ip'}} = $ref->{'mon_login'};
    $headinfo{'MONPASS_'. $ref->{'term_ip'}} = $ref->{'mon_pass'};
    $headinfo{'ZONE_'.    $ref->{'term_ip'}} = $ref->{'zone_id'};
    $headinfo{'LHEAD_'.   $ref->{'term_ip'}} = $ref->{'linked_head'} if $ref->{'linked_head'};
}
$stm->finish();

############ SUBS ##############

sub SW_AP_get {

	dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "--" );
	DB_mysql_connect(\$dbm);
	my $fparm = shift; my %sw_arg = ();
	my $Fres = 2; my $Fvalue = 'ap_id:-1;';	

        #       $fparm->{login} = pppoe
        #       $fparm->{link_type} = 21
        #       $fparm->{ap_vlan} = 239
        #       $fparm->{nas_ip} = 192.168.100.30
        #       $fparm->{nas_port_id} = '0/0/1/0'
        #       $fparm->{mac} = 0017.3156.7fd9

        #       $fparm->{ap_id} =
        #       $fparm->{port_rate_ds} = 10000
        #       $fparm->{port_rate_us} = 10000
        #       $fparm->{inet_rate} = 1000
        #       $fparm->{ip_addr} = 10.13.64.3

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
	my $Query = ''; my $Q_upd = ''; my $PreQuery = '';
        my $date = strftime "%Y%m%d%H%M%S", localtime(time);
	my $job_parms = '';

	my %AP = (
	    'id',	0,
	    'trust',	0,
	    'set',	0,
	    'callsub',	'PPPoE2Dispatcher',
	    'vlan_zone', 1,
	    'update_db', 0,
	    'DB_portinfo',	0,
	    'vlan_id',	0,
	    'hw_mac',	$fparm->{'mac'},
	    'pri',	$fparm->{'inet_priority'},
	    'trust_id',	$fparm->{'ap_id'},
	    'name',	'',
	    'swid',	0,
	    'bw_ctl',	0,
	);

	####### Start FIX VLAN ID) ########### 
	%sw_arg = (
	    LIB => $headinfo{'L2LIB_'.$fparm->{'nas_ip'}}, ACT => 'fix_vlan', IP => $headinfo{'L2IP_'.$fparm->{'nas_ip'}}, 
	    LOGIN => $headinfo{'MONLOGIN_'.$fparm->{'nas_ip'}},	PASS => $headinfo{'MONPASS_'.$fparm->{'nas_ip'}}, MAC => $fparm->{'mac'},
	);
	$AP{'vlan_id'} = SW_ctl ( \%sw_arg );

	if ( $AP{'vlan_id'} < 1) {
	    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "User '".$fparm->{'login'}."'".' Access point VLAN is not FIX!!! Trobles connect to ZONE SWITCH???' );
	    $Fres = 2;
	    $Fvalue = 'error:MAC VLAN not fixed... :-(;';
	} else {
		dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "User '".$fparm->{'login'}."'".' Access point VLAN = '.$AP{'vlan_id'} );
		########### Start FIX Access Point (AP) ########### 
		$AP{'trust_id'}	= $fparm->{'ap_id'};
		$AP{'nas_ip'}	= $fparm->{'nas_ip'};
		$AP{'login'}	= $fparm->{'login'};
		SW_AP_fix( \%AP );
		################### Если выяснили AP_ID ######################
		if ($AP{'id'}) {
			$Fres = 1;
			$AP{'name_ms'} = $AP{'name'};
			Encode::from_to($AP{'name_ms'}, "koi8r", "cp1251");
			$Fvalue = 'ap_id:'.$AP{'id'}.';ap_name:'.$AP{'name_ms'}.';bw_ctl:'.$AP{'bw_ctl'}.';ap_swid:'.$AP{'swid'}.';ap_communal:'.$AP{'communal'}.';';
			if ( $fparm->{'ap_id'} and $fparm->{'ap_id'} == $AP{'id'} ) {
			    $Fres = 0; $AP{'trust'}=1;

    			    if ( ( $AP{'link_type'} != $fparm->{'link_type'}
				|| ( 'x'.$fparm->{'port_rate_us'} ne 'x' and $AP{'us'} != $fparm->{'port_rate_us'} )
				|| ( 'x'.$fparm->{'port_rate_ds'} ne 'x' and $AP{'ds'} != $fparm->{'port_rate_ds'} )
			    ) and ! $AP{'communal'} ) {
				$AP{'set'} = 1;
			    }

                            dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS =>
			    "AP_set = '".$AP{'set'}."', AP_DS = '".$fparm->{'port_rate_ds'}."', AP_US = '".$fparm->{'port_rate_us'}."'" );
			} else {
			    $AP{'trust'} = 0; $AP{'set'} = 0
			}
			$Query = "INSERT INTO ap_login_info SET trust=".$AP{'trust'}.", login='".$fparm->{'login'}."', start_date='".$date."', last_date='".$date."'";
			$Query .= ", hw_mac='".$fparm->{'mac'}."', vlan_id='".$AP{'vlan_id'}."', port_id='".$AP{'id'}."', ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."'";
			$Query .= ", ip_addr='".$fparm->{'ip_addr'}."'" if ( not $fparm->{'ip_addr'} =~ /^10\.13\.2[45][0-9]\.\d{1,3}$/ );
			$Query .= " ON DUPLICATE KEY UPDATE trust=".$AP{'trust'}.", ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."', last_date='".$date."', vlan_id='".$AP{'vlan_id'}."'";
			$Query .= ", ip_addr='".$fparm->{'ip_addr'}."'" if ( not $fparm->{'ip_addr'} =~ /^10\.13\.2[45][0-9]\.\d{1,3}$/ );
			$dbm->do("$Query");

			## HEAD_LINK inserting data
			if ( $AP{'trust'} and $fparm->{'link_type'} == $link_type{'pppoe'} ) {
			    if ( $fparm->{'ip_addr'} =~ /^10\./ ) { 
				$AP{'pri'} = $fparm->{'inet_priority'}||1;
			    } else {
				$AP{'pri'} = 3;
			    }
			    $Query = "INSERT INTO head_link SET port_id=".$AP{'id'}.", status=1, white_static_ip=0, dhcp_use=".$nas_conf->{'DHCP_USE'}.", ";
			    $Q_upd = " vlan_id=".$AP{'vlan_id'}.", login='".$fparm->{'login'}."', hw_mac='".$fparm->{'mac'}."', communal=".$AP{'communal'}.
			    ", inet_shape=".$fparm->{'inet_rate'}.", inet_priority=".$AP{'pri'}.", stamp=NULL, ip_subnet='".$fparm->{'ip_addr'}."'".
			    ", head_id=".$headinfo{'LHEAD_'.$fparm->{'nas_ip'}}.", pppoe_up=1";
			    $Query .= $Q_upd." ON DUPLICATE KEY UPDATE ".$Q_upd;
			    $dbm->do("$Query") or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => "$Query \n$DBI::errstr" );
			}
		######################## SET JOB PARAMETERS
			# Если необходимо делать изменения на порту - $AP{'set'} и коммутатор управляется
			if ( $AP{'set'} and $AP{'automanage'} ) {
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "Access Point parm change" );
			    $AP{'update_db'}=1;
		    	    $Query = "INSERT INTO bundle_jobs SET port_id=".$AP{'id'};
			    $job_parms  = 'login:'.$fparm->{'login'}.';hw_mac:'.$fparm->{'mac_src'}.';';
			    $job_parms .= 'inet_rate:'.$fparm->{'inet_rate'}.';'   if defined($fparm->{'inet_rate'});
			    $job_parms .= 'ds_speed:'.$fparm->{'port_rate_ds'}.';' if defined($fparm->{'port_rate_ds'});
			    $job_parms .= 'us_speed:'.$fparm->{'port_rate_us'}.';' if defined($fparm->{'port_rate_us'});

			    ########  VPN  VLAN  ########
			    if ( $fparm->{'link_type'} == $link_type{'l2link'} ) {
				#$Query .= ", ltype_id=".$fparm->{'link_type'};
				if ( "x".$fparm->{'vlan_id'} eq "x" ) {
				    # PORT_ID LINK_TYPE ZONE
				    ( $fparm->{'vlan_id'}, $AP{'head_id'} ) = VLAN_get ( PORT_ID => $AP{'id'}, 
				    LINK_TYPE => $fparm->{'link_type'}, ZONE => $AP{'vlan_zone'} );
				    if ( $fparm->{'vlan_id'} > 1 ) {
					$Fvalue .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
					$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
				    }
				} else {
				    $job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
				}
			    }
			    ######## Transport Net ############
			    if ( defined($fparm->{'ip_addr'}) and $fparm->{'link_type'} == $link_type{'l3net4'} ) {
				if ( "x".$fparm->{'vlan_id'} eq "x" ) {
				    $job_parms .= 'ip_subnet:'.(GET_IP3($fparm->{'ip_addr'}.'/30')).'/30;' ;
				    # PORT_ID LINK_TYPE ZONE
				    ( $fparm->{'vlan_id'}, $AP{'head_id'} ) = VLAN_get ( PORT_ID => $AP{'id'}, 
				    LINK_TYPE => $link_type{'l3net4'}, ZONE => $AP{'vlan_zone'} );
				    if ( $fparm->{'vlan_id'} > 1 ) {
					$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
				    }
				}
			    }

			    # Проверка изменений link_type
			    ## Если порт был свободен и задействуется под PPPoE
			    if ( $AP{'link_type'} == $link_type{'free'} and $fparm->{'link_type'} == $start_conf->{'CLI_VLAN_LINKTYPE'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
				$job_parms .= 'vlan_id:'.$AP{'vlan_id'}.';';
			    ## Иначе если порт был свободен и задействуется под другие типы подключений  
			    } elsif ( $AP{'link_type'} == $link_type{'free'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
				$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';' if ( $fparm->{'vlan_id'} > 1 );
			    ## Иначе если порт занят под такой же тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $fparm->{'link_type'}+0 == $AP{'link_type'}+0 ) {
				$Query .= ", ltype_id=".$link_type{'setparms'};
				$job_parms .= 'vlan_id:'.$AP{'vlan_id'}.';';
			    ## Иначе если порт ЗАНЯТ! и задействуется под другой тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $fparm->{'link_type'}+0 != $AP{'link_type'}+0  ) {
				$PreQuery .= "INSERT INTO bundle_jobs SET port_id=".$AP{'id'}.", ltype_id=".$link_type{'free'}.' ON DUPLICATE KEY UPDATE date_insert=NULL';

				$Query .= ", ltype_id=".$fparm->{'link_type'};
				$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';' if ( defined($fparm->{'vlan_id'}) and $fparm->{'vlan_id'} > 1 );
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
			    
			    $Fvalue = 'ap_id:'.$AP{'id'}.';ap_name:'.$AP{'name_ms'}.';bw_ctl:'.$AP{'bw_ctl'}.';ap_swid:'.$AP{'swid'}.';ap_communal:'.$AP{'communal'}.';';
			}

		} elsif ( $AP{'vlan_id'} ) {
		    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "AP ID '".$fparm->{'login'}."' in VLAN ".$AP{'vlan_id'}." not fixed!!!" );
		    $Fres = 2;
		    $Fvalue = 'error:MAC found in VLAN '.$AP{'vlan_id'}.'. Access point not fixed... :-(;';
		}
	}
	my $Fvalue_ms = $Fvalue;
	Encode::from_to($Fvalue_ms, "cp1251", "koi8r");

        dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => 
	"QUERY: Login  = '".$fparm->{'login'}."', MAC = '".$fparm->{'mac'}."', NAS_IP = ".$fparm->{'nas_ip'}."\n".
	"AP_CHECK: ".$RES[$Fres].'('.$Fres.')'.", Login = '".$fparm->{'login'}."', AP_ID = '".$AP{'id'}."', '".$AP{'name'}.", ZONE = ".$AP{'vlan_zone'}.", VLAN = ".$AP{'vlan_id'}."'\n".
	"REPLY: ".$Fres.", '".$Fvalue_ms."'" );

	return ($Fres+0, $Fvalue);
}



sub SW_AP_free {

    DB_mysql_connect(\$dbm);
    my $Q_free; my $Fres = 0; my $Fvalue = '';

    my $fparm = shift;
    #	$fparm->{ap_id} = 1234
    if  ( not ( defined($fparm->{'ap_id'}) && $fparm->{'ap_id'} =~ /^\d+$/ ) ) {
        return ( $Fres, "error:not defined parameter 'ap_id';" );
    }
    ############################ Освобождeние AP

    $Q_free = "INSERT INTO bundle_jobs SET port_id=".$fparm->{'ap_id'}.", ltype_id=".$link_type{'free'}.' ON DUPLICATE KEY UPDATE date_insert=NULL';

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

    DB_mysql_connect(\$dbm);
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
    $Q_parm."' ON DUPLICATE KEY UPDATE date_insert=NULL, parm=CONCAT(parm,'".$Q_parm."')";

    if ( $debug > 1 ) {
        dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "DEBUG mode, Query '".$Q_tune."'" );
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

    DB_mysql_connect(\$dbm);
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

sub SW_send_pod {

    my $param = shift;
    my $sender = shift;
    # nas_ip nas_port nas_secret login

    my ( $res, $a, $err, $strerr );
    my $res_attr = "attr:";

    my $r = new Authen::Radius(Host => $param->{'nas_ip'}.":".$param->{'nas_port'}, Secret => $param->{'nas_secret'}, Debug => 0);
    $r->add_attributes (
      { Name => 'User-Name', Value => $param->{'login'} }
    );

    $r->send_packet(DISCONNECT_REQUEST);
    $res = $r->recv_packet();

    $err = $r->get_error;
    $strerr = $r->strerror;

    for $a ($r->get_attributes()) {
        $res_attr .= ",".$a->{'Name'}."='".$a->{'Value'}."'";
        if($a->{'Name'} eq 'Error-Cause' &&  $a->{'Value'} eq 'Session-Context-Not-Found') {
            $res = 41;
        }
    }
    return ( $res+0, "strerr:".$strerr.";".$res_attr );

}


1;
