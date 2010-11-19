#!/usr/bin/perl

my $debug=1;

package SWFuncMSBILL;

use strict;
#use locale;
use POSIX qw(strftime);
use DBI();
use FindBin '$Bin';
use lib $Bin.'/../lib';
use SWConf;
use SWFunc;
use SWFuncAAA;

use Data::Dumper;
use Encode;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();

$VERSION = 1.0;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw( GET_ppp_parm DB_MSsql_connect ACC_update PPP_post_auth
);

my $start_conf	= \%SWConf::conf;
my $dbi		= \%SWConf::dbconf;
my $nas_conf	= \%SWConf::aaa_conf;

my $Querry_start = '';
my $Querry_end = '';
my $res;
my $dbm;
my $dbms;

DB_mysql_connect(\$dbm);

DB_MSsql_connect(\$dbms);

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

sub DB_MSsql_connect {
	my $mssqlconnect = shift;
	${$mssqlconnect} = DBI->connect_cached("DBI:Sybase:server=".$dbi->{'MSSQL_server'}.
	";language=russian;database=".$dbi->{'MSSQL_base'},$dbi->{'MSSQL_user'},$dbi->{'MSSQL_pass'})
	#${$mssqlconnect} = DBI->connect_cached("DBI:Sybase:server=".$dbi->{'MSSQL_server'}.";database=".$dbi->{'MSSQL_base'},$dbi->{'MSSQL_user'},$dbi->{'MSSQL_pass'})
	or die "Unable to connect MSSQL server ".$dbi->{'MSSQL_server'}."$DBI::errstr";
	#or die dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MSSQL DB host ".$dbi->{'MSSQL_host'}."$DBI::errstr" );
	${$mssqlconnect}->do("set dateformat dmy") or die return -1;
	#dlog ( DBUG => 2, SUB => (caller(0))[3],  MESS => "MSsql connect ID = ".${$mssqlconnect}->{'mssql_thread_id'} );
	return 1;
}


######################################### FREERADIUS SUBS for rlm_perl #######################################

sub ACC_update {

	my $RAD_REQUEST = shift;
	DB_MSsql_connect(\$dbms);
	&radiusd::radlog(1, "---------------- PERL ACCOUNTING ---------------------");
	my $dbug = 1;
	my $ip1; my $ip2; my $ip3; my $ip4;
	my $name = "";
	my $iface = 0;
	my $port = 0;
	my $date = "";
	my $time = 0;
	my $status = 2;

	if ( not $dbug and $RAD_REQUEST->{'NAS-IP-Address'} ne $nas_conf->{'pppoe_server'} ) {
               return -1;
	};

	if ($RAD_REQUEST->{'Framed-IP-Address'} && ($RAD_REQUEST->{'Framed-IP-Address'} =~ /^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/) ) {
		$ip1 = $1;
		$ip2 = $2;
		$ip3 = $3;
		$ip4 = $4;
	} else {
		$ip1 = $ip2 = $ip3 = $ip4 = 0;
	}


	$RAD_REQUEST->{'User-Name'} and $name = $RAD_REQUEST->{'User-Name'};
	$RAD_REQUEST->{'Acct-Session-Id'} and $iface = $RAD_REQUEST->{'Acct-Session-Id'};
	$RAD_REQUEST->{'NAS-Port'} and $port = $RAD_REQUEST->{'NAS-Port'};
	#$hdrs{'Timestamp'} and $date = $hdrs{'Timestamp'};
	$RAD_REQUEST->{'Acct-Session-Time'} and $time = $RAD_REQUEST->{'Acct-Session-Time'};
	$RAD_REQUEST->{'Acct-Delay-Time'} and ($time > $RAD_REQUEST->{'Acct-Delay-Time'}) and do {
	    $time -= $RAD_REQUEST->{'Acct-Delay-Time'};
	};
	$RAD_REQUEST->{'Acct-Status-Type'} and $status = $RAD_REQUEST->{'Acct-Status-Type'};

	$name =~ /^\s*"?(.*?)"?\s*$/ and $name = $1;
	$name =~ /^\s*(\S*?)\s*$/ and $name = $1;

	$iface =~ /^\s*"?(.*?)"?\s*$/ and $iface = $1;
	$iface =~ /^\s*(\S*?)\s*$/ and $iface = $1;
	$iface = hex $iface;

	$status = 2 if $status eq "Start";		# 1
	$status = 2 if $status eq "Interim-Update"; 	# 3
	$status = 3 if $status eq "Stop";		# 2

	my @d = ();
	#$date = strftime "%d.%m.%Y %H:%M:%S", localtime($date);
	$date = strftime "%d.%m.%Y %H:%M:%S", localtime(time);
	&radiusd::radlog(1, "---------- DATE = $date, TIME = $time -----------");

	if ($status != 3) {
		my $sth = $dbms->prepare("select status from preparetime where username='$name' and interfacenumber=$iface");
		$sth->execute;
		@d = $sth->fetchrow_array;
		$sth->finish;
		if (defined($d[0]) && ($d[0] == 4)) {
			#&radiusd::radlog(1, "---------------- send POD ---------------------");
			## reset session
			my %pod_parm = ('nas_ip'	=> $RAD_REQUEST->{'NAS-IP-Address'},
					'nas_port'		=> $nas_conf->{'pod_port'},
					'nas_secret'	=> $nas_conf->{'pod_secret'},
					'login'		=> $RAD_REQUEST->{'User-Name'},
			);
			send_pod (\%pod_parm, 'freeradius' );
		}

	}
	$dbms->do("exec WorkPrepareTime $ip1, $ip2, $ip3, $ip4, '$name', $iface, '$date', $time, $status");
	return 1;
}


sub GET_ppp_parm {

	#######  UserAuth ########### 
	my $RAD_REQUEST = shift;
	my $RAD_REPLY = shift;
	my $Q_upd_db = shift;

	DB_MSsql_connect(\$dbms);
	DB_mysql_connect(\$dbm);

	my %AP = (
		'callsub'	=> 'PPPoE2RADIUS',
		'login_service'	=> 0,
		'vlan_id'	=> 0,
		'trust'		=> 0,
		'id'		=> 0,
		'new_lease'	=> 0,
		'set'		=> 0,
		'vlan_zone'	=> 1,
		'update_db'	=> 0,
		'DB_portinfo'	=> 0,
		'vlan_id'	=> 0,
		'name'		=> '',
		'swid'		=> 0,
		'bw_ctl'	=> 0,
		'nas_ip'	=> $RAD_REQUEST->{'NAS-IP-Address'},
		'login'		=> $RAD_REQUEST->{'User-Name'},
	);
	$Q_upd_db->{'User-Name'} = $RAD_REQUEST->{'User-Name'};


	if ( not exists($RAD_REQUEST->{'Framed-Protocol'}) and defined($RAD_REQUEST->{'NAS-Identifier'}) 
	and $RAD_REQUEST->{'NAS-Identifier'} eq $nas_conf->{'mail_server'} ) {
	    print Dumper $RAD_REQUEST;
	    $AP{'login_service'} = 1;
	    $AP{'trust'} = 1;
	} else {
	    $AP{'cisco_num'} = 1;
	}

	if ( $AP{'login_service'} == 0 ) {
	    if ( defined($RAD_REQUEST->{'Cisco-AVPair'}) and $RAD_REQUEST->{'Cisco-AVPair'} =~ /client\-mac\-address\=(\w\w)(\w\w)\.(\w\w)(\w\w)\.(\w\w)(\w\w)/ ) {
		$AP{'hw_mac'}  = lc("$1:$2:$3:$4:$5:$6");
		$AP{'mac_src'} = lc("$1$2$3$4$5$6");
		&radiusd::radlog(1,  "HW_MAC = ". $AP{'hw_mac'} );
		if (($AP{'hw_mac'} eq "0") || ($AP{'hw_mac'} eq "00:00:00:00:00:00")) {
		    &radiusd::radlog(1, "User '".$RAD_REQUEST->{'User-Name'}."' MAC '".$AP{'hw_mac'}."' is Wrong!!!\n\n");
		}
	    } else {
		&radiusd::radlog(1,  "HW_MAC not Fix in RADIUS Pair" );
		return -1;
	    }
	    ####### Fixing VLAN ID ###########
	    SW_VLAN_fix( \%AP );
	    &radiusd::radlog(1, "User VLAN = ".$AP{'vlan_id'} );

	    #print Dumper %AP;
	    ####### Fixing AP ID ###########
	    SW_AP_fix( \%AP );
	    &radiusd::radlog(1, "User AP_id = ".$AP{'id'} );

	    ###### Get parms from Billing

	    ####### UserCheckMAC ########### 
	    my $Q_Check_MAC = "exec UserCheckMAC '".$RAD_REQUEST->{'User-Name'}."', '".$AP{'hw_mac'}."', ".$AP{'id'}.", '".
	    from_to($AP{'name'}, "koi8r", "cp1251")."', ".(! $AP{'communal'}).", ".$AP{'cisco_num'}.", ".$AP{'swid'};

	    my $sth = $dbms->prepare($Q_Check_MAC);
	    $sth->execute;
	    my $ref_ms = $sth->fetchrow_hashref();
	    $sth->finish;
	    $AP{'trust'} = $ref_ms->{'FlagAccess'};
	    if ( $AP{'trust'} < 0 ) {
		$RAD_REPLY->{'Reply-Message'} = $ref_ms->{'TextError'} if defined($ref_ms->{'TextError'});
		return $AP{'trust'};
	    }
	#    foreach my $key ( sort keys %{$ref_ms} ) {
	#	print STDERR $key." = ".$ref_ms->{$key}."\n";
	#    }
	#     FlagAccess = 1 | TextError = | DSSpeed = -1 | USSpeed = -1
	}

	####### UserAuth ########### 
	if ( $AP{'login_service'} > 0 or $AP{'trust'} ) {
	    my $Q_UserAuth = "exec UserAuth '".$RAD_REQUEST->{'User-Name'}."', ".$AP{'login_service'};

	    my $sth1 = $dbms->prepare($Q_UserAuth);
	    $sth1->execute;
	    my $ref_ms1 = $sth1->fetchrow_hashref();
	    $sth1->finish;
	#    foreach my $key ( sort keys %{$ref_ms1} ) {
	#	print STDERR $key." = ".$ref_ms1->{$key}."\n";
	#    }
	    # CardNumber = 1 | DSSpeed = -1 | IP1 = 10 | IP2 = 13 | IP3 = 100 | IP4 = 1 | IdTariff = 6 | InetSpeed = 10000 
	    #  NumberPassword = 1 | Quote = 86400 | Status = 1 | TextError = | USSpeed = -1 | TypeConnect | Category

	    if ( $AP{'login_service'} > 0 ) {
		$RAD_REQUEST->{'User-Name'} = $ref_ms1->{'CardNumber'}.".".$ref_ms1->{'NumberPassword'};
		$AP{'trust'} = 1;
	    } elsif ( $AP{'login_service'} == 0 ) {
		$ref_ms1->{'TypeConnect'} = 21 if not defined($ref_ms1->{'TypeConnect'});
		$ref_ms1->{'Category'} = 2 if not defined($ref_ms1->{'Category'});
		$RAD_REPLY->{'Service-Type'} = "Framed-User";
		$RAD_REPLY->{'Framed-Protocol'} = "PPP";

	      if ( not defined($ref_ms1->{'Quote'}) ) {
		    $RAD_REPLY->{'Reply-Message'} = $ref_ms1->{'TextError'} if defined($ref_ms1->{'TextError'});
		    return -1;
	      } elsif ( $ref_ms1->{'Quote'} < 0 ) {
		$RAD_REPLY->{'Session-Timeout'} = $nas_conf->{'FAKE_QUOTE'};
		$RAD_REPLY->{'Cisco-AVPair'} = "ip:dns-servers=".$nas_conf->{'FAKE_DNS'}." ".$nas_conf->{'FAKE_DNS'};
	      } else {
		$RAD_REQUEST->{'User-Name'} = $ref_ms1->{'CardNumber'}.".".$ref_ms1->{'NumberPassword'};
		$RAD_REPLY->{'Framed-IP-Address'} = $ref_ms1->{'IP1'}.".".$ref_ms1->{'IP2'}.".".$ref_ms1->{'IP3'}.".".$ref_ms1->{'IP4'};
		$RAD_REPLY->{'Session-Timeout'} = $ref_ms1->{'Quote'};

		if ( $RAD_REPLY->{'Framed-IP-Address'} =~ /^10\.13\.2[45]\d\.\d+/ ) {
		    $RAD_REPLY->{'Cisco-AVPair'} = "ip:dns-servers=".$nas_conf->{'FAKE_DNS'}." ".$nas_conf->{'FAKE_DNS'};
		} else {
		    $RAD_REPLY->{'Cisco-AVPair'} = "ip:dns-servers=".$nas_conf->{'DNS_IP1'}." ".$nas_conf->{'DNS_IP2'};
		}
		####################### GET ACCESS POINT ####################
		my $Query = ''; my $Q_upd = ''; my $PreQuery = '';
		my $date = strftime "%Y%m%d%H%M%S", localtime(time);
		my $job_parms = ''; $AP{'set'} = 0;

		################### Если выяснили AP_ID ######################
		if ( $AP{'trust'} > 0 and ( not $RAD_REPLY->{'Framed-IP-Address'} =~ /^10\.13\.2[45]\d\.\d{1,3}$/ ) and ( not $ref_ms1->{'Quote'} < 0 )) {
		# CardNumber = 1 | DSSpeed = -1 | IP1 = 10 | IP2 = 13 | IP3 = 100 | IP4 = 1 | IdTariff = 6 | InetSpeed = 10000 
		#  NumberPassword = 1 | Quote = 86400 | Status = 1 | TextError = | USSpeed = -1 | TypeConnect | Category
			#print Dumper %AP if $debug;
			if ( ( $AP{'link_type'} != $ref_ms1->{'TypeConnect'}
			|| ( 'x'.$ref_ms1->{'USSpeed'} ne 'x' and $AP{'us'} != $ref_ms1->{'USSpeed'} )
			|| ( 'x'.$ref_ms1->{'DSSpeed'} ne 'x' and $AP{'ds'} != $ref_ms1->{'DSSpeed'} )
			) and ! $AP{'communal'} ) {
			    $AP{'set'} = 1;
			}
			dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS =>
			"AP_set = '".$AP{'set'}."', AP_DS = '".$ref_ms1->{'DSSpeed'}."', AP_US = '".$ref_ms1->{'USSpeed'}."'" );

			$Query = "INSERT INTO ap_login_info SET login='".$AP{'login'}."', start_date='".$date."', hw_mac='".$AP{'hw_mac'}."',  port_id='".$AP{'id'}."'";
			$Q_upd = " ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."', last_date='".$date."', vlan_id='".$AP{'vlan_id'}."'".
			", ip_addr='".$RAD_REPLY->{'Framed-IP-Address'}."'";

			$dbm->do( $Query.",".$Q_upd.", trust=0  ON DUPLICATE KEY UPDATE ".$Q_upd );
			$Q_upd_db->{'Q_ap_login_info'} = $Query.",".$Q_upd.", trust=1 ON DUPLICATE KEY UPDATE ".$Q_upd.", trust=1" ;

			## HEAD_LINK inserting data
			if ( $AP{'trust'} and $ref_ms1->{'TypeConnect'} == $link_type{'pppoe'} ) {
			    if ( $RAD_REPLY->{'Framed-IP-Address'} =~ /^10\./ ) { 
				$AP{'pri'} = $ref_ms1->{'Category'}||3;
			    } else {
				$AP{'pri'} = 3;
			    }
			    $Query = "INSERT INTO head_link SET port_id=".$AP{'id'}.", status=1, white_static_ip=0, dhcp_use=".$nas_conf->{'DHCP_USE'}.", ";
			    $Q_upd = " vlan_id=".$AP{'vlan_id'}.", login='".$AP{'login'}."', hw_mac='".$AP{'hw_mac'}."', communal=".$AP{'communal'}.
			    ", inet_shape=".$ref_ms1->{'InetSpeed'}.", inet_priority=".$AP{'pri'}.", stamp=NULL, ip_subnet='".$RAD_REPLY->{'Framed-IP-Address'}."'".
			    ", head_id=".$headinfo{'LHEAD_'.$AP{'nas_ip'}}.", pppoe_up=1";
			    $Query .= $Q_upd." ON DUPLICATE KEY UPDATE ".$Q_upd;
			    $Q_upd_db->{'Q_head_link'} = $Query ;
			}
			######################## SET JOB PARAMETERS #######################
			if ( $AP{'set'} and $AP{'automanage'} ) {
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "Access Point parm change" );
			    $AP{'update_db'}=1;
			    $Query = "INSERT INTO bundle_jobs SET port_id=".$AP{'id'};
			    $job_parms  = 'login:'.$AP{'login'}.';hw_mac:'.$AP{'mac_src'}.';';
			    $job_parms .= 'inet_rate:'.$ref_ms1->{'InetSpeed'}.';'   if defined($ref_ms1->{'InetSpeed'});
			    $job_parms .= 'ds_speed:'.$ref_ms1->{'DSSpeed'}.';'      if defined($ref_ms1->{'DSSpeed'});
			    $job_parms .= 'us_speed:'.$ref_ms1->{'USSpeed'}.';'      if defined($ref_ms1->{'USSpeed'});

			    ########  VPN  VLAN  ########
			    if ( $ref_ms1->{'TypeConnect'} == $link_type{'l2link'} ) {
				#$Query .= ", ltype_id=".$ref_ms1->{'TypeConnect'};
				if ( "x".$ref_ms1->{'vlan_id'} eq "x" ) {
				    # PORT_ID LINK_TYPE ZONE
				    ( $ref_ms1->{'vlan_id'}, $AP{'head_id'} ) = VLAN_get ( PORT_ID => $AP{'id'}, 
				    LINK_TYPE => $ref_ms1->{'TypeConnect'}, ZONE => $AP{'vlan_zone'} );
				    if ( $ref_ms1->{'vlan_id'} > 1 ) {
					$job_parms .= 'vlan_id:'.$ref_ms1->{'vlan_id'}.';';
				    }
				} else {
				    $job_parms .= 'vlan_id:'.$ref_ms1->{'vlan_id'}.';';
				}
			    }
			    ######## Transport Net ############
			    if ( defined($RAD_REPLY->{'Framed-IP-Address'}) and $ref_ms1->{'TypeConnect'} == $link_type{'l3net4'} ) {
				if ( "x".$ref_ms1->{'vlan_id'} eq "x" ) {
				    $job_parms .= 'ip_subnet:'.(GET_IP3($RAD_REPLY->{'Framed-IP-Address'}.'/30')).'/30;' ;
				    # PORT_ID LINK_TYPE ZONE
				    ( $ref_ms1->{'vlan_id'}, $AP{'head_id'} ) = VLAN_get ( PORT_ID => $AP{'id'}, 
				    LINK_TYPE => $link_type{'l3net4'}, ZONE => $AP{'vlan_zone'} );
				    if ( $ref_ms1->{'vlan_id'} > 1 ) {
					$job_parms .= 'vlan_id:'.$ref_ms1->{'vlan_id'}.';';
				    }
				}
			    }

			    # Проверка изменений link_type
			    ## Если порт был свободен и задействуется под PPPoE
			    if ( $AP{'link_type'} == $link_type{'free'} and $ref_ms1->{'TypeConnect'} == $start_conf->{'CLI_VLAN_LINKTYPE'} ) {
				$Query .= ", ltype_id=".$ref_ms1->{'TypeConnect'};
				$job_parms .= 'vlan_id:'.$AP{'vlan_id'}.';';
			    ## Иначе если порт был свободен и задействуется под другие типы подключений  
			    } elsif ( $AP{'link_type'} == $link_type{'free'} ) {
				$Query .= ", ltype_id=".$ref_ms1->{'TypeConnect'};
				$job_parms .= 'vlan_id:'.$ref_ms1->{'vlan_id'}.';' if ( $ref_ms1->{'vlan_id'} > 1 );
			    ## Иначе если порт занят под такой же тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $ref_ms1->{'TypeConnect'}+0 == $AP{'link_type'}+0 ) {
				$Query .= ", ltype_id=".$link_type{'setparms'};
				$job_parms .= 'vlan_id:'.$AP{'vlan_id'}.';';
			    ## Иначе если порт ЗАНЯТ! и задействуется под другой тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $ref_ms1->{'TypeConnect'}+0 != $AP{'link_type'}+0  ) {
				$PreQuery .= "INSERT INTO bundle_jobs SET port_id=".$AP{'id'}.", ltype_id=".$link_type{'free'}.' ON DUPLICATE KEY UPDATE date_insert=NULL';

				$Query .= ", ltype_id=".$ref_ms1->{'TypeConnect'};
				$job_parms .= 'vlan_id:'.$ref_ms1->{'vlan_id'}.';' if ( defined($ref_ms1->{'vlan_id'}) and $ref_ms1->{'vlan_id'} > 1 );
			    } else {
				$AP{'update_db'}=0;
			    }

			    if ( $AP{'update_db'} ) {
				if ("x".$PreQuery ne "x" ) {
				    $Q_upd_db->{'Q_pre_bundle_jobs'} = $PreQuery;
				}
				$Query .= ", parm='".$job_parms."', archiv=0 ON DUPLICATE KEY UPDATE date_insert=NULL, parm='".$job_parms."'";
				dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "Update port DB parameters info" );
				$Q_upd_db->{'Q_bundle_jobs'} = $Query;
			    } else {
				dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', 
				MESS => "Error: Different link_types, possible PORT type is FREE?" );
			    }
			}

			if ( not $AP{'trust'} ) {
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "'".$AP{'login'}."' access point not agree !!!" );
			}
			dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS =>
			"QUERY: Login  = '".$AP{'login'}."', MAC = '".$AP{'hw_mac'}."', NAS_IP = ".$AP{'nas_ip'}."\n".
			" Login = '".$AP{'login'}."', AP_ID = '".$AP{'id'}."', '".$AP{'name'}.", ZONE = ".$AP{'vlan_zone'}.", VLAN = ".$AP{'vlan_id'}."'\n");
		}
	      }
	    }
	}
	return $AP{'trust'};

}

sub PPP_post_auth {
	my $UPD = shift;
	my $RAD_REQUEST = shift;

	DB_mysql_connect(\$dbm);
	if ( defined($UPD->{'Q_ap_login_info'}) )    { $dbm->do($UPD->{'Q_ap_login_info'})
	or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => $UPD->{'Q_ap_login_info'}." \n$DBI::errstr" ); }
	if ( defined($UPD->{'Q_head_link'}) )        { $dbm->do($UPD->{'Q_head_link'})
	or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => $UPD->{'Q_head_link'}." \n$DBI::errstr" ); }
	if ( defined($UPD->{'Q_pre_bundle_jobs'}) )  { $dbm->do($UPD->{'Q_pre_bundle_jobs'})
	or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => $UPD->{'Q_pre_bundle_jobs'}." \n$DBI::errstr" ); }
	if ( defined($UPD->{'Q_bundle_jobs'}) )      { $dbm->do($UPD->{'Q_bundle_jobs'})
	or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => $UPD->{'Q_bundle_jobs'}." \n$DBI::errstr" ); }

	#print Dumper $RAD_REQUEST;
	if ( defined($RAD_REQUEST->{'NAS-Identifier'}) and $RAD_REQUEST->{'NAS-Identifier'} eq $nas_conf->{'mail_server'} and
	defined($RAD_REQUEST->{'Cleartext-Password'}) and defined ($RAD_REQUEST->{'User-Password'}) and not defined($RAD_REQUEST->{'Framed-Protocol'}) ) {
	    if ( $RAD_REQUEST->{'Cleartext-Password'} ne $RAD_REQUEST->{'User-Password'} ) {
		return -1;
	    }
	} elsif ( defined($RAD_REQUEST->{'Cleartext-Password'}) and defined ($RAD_REQUEST->{'User-Password'}) and defined($RAD_REQUEST->{'Framed-Protocol'}) ) {
		return -1;
	}
	return 1;
}


1;
