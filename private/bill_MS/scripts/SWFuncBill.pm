#!/usr/bin/perl

my $debug=1;

package SWFuncBill;

use strict;

#use locale;
use POSIX qw(strftime);
use cyrillic qw(cset_factory);
use DBI();
use Authen::Radius;
Authen::Radius->load_dictionary();

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();

$VERSION = 0.5;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw( GET_ppp_parm DB_MSsql_connect ACC_update PPP_post_auth
);

my $start_conf	= \%SWConf::conf;
my $dbi		= \%SWConf::dbconf;
my $nas_conf	= \%SWConf::aaa_conf;

use Data::Dumper;

my $w2k = cset_factory 1251, 20866;
my $k2w = cset_factory 20866, 1251;

my $res;
my $dbm;
my $dbms;

DB_mysql_connect ( \$dbm );
DB_MSsql_connect ( \$dbms );

############ SUBS ##############

sub DB_mysql_connect {
        my $sqlconnect = shift;
        ${$sqlconnect} = DBI->connect_cached("DBI:mysql:database=".$dbi->{'MYSQL_base'}.";host=".$dbi->{'MYSQL_host'},$dbi->{'MYSQL_user'},$dbi->{'MYSQL_pass'})
        or die "Unable to connect MYSQL DB host ".$dbi->{'MYSQL_host'}."$DBI::errstr";
        #or die dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MYSQL DB host ".$dbi->{'MYSQL_host'}."$DBI::errstr" );
        ${$sqlconnect}->do("SET NAMES 'koi8r'") or die return -1;
        #dlog ( DBUG => 2, SUB => (caller(0))[3],  MESS => "Mysql connect ID = ".${$sqlconnect}->{'mysql_thread_id'} );
        return 1;
}

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

sub send_pod  {

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

    #if ( $sender eq 'freeradius' ) { &radiusd::radlog(1, "POD error = $err $strerr" );}

    for $a ($r->get_attributes()) {
	$res_attr .= ",".$a->{'Name'}."='".$a->{'Value'}."'";
	if($a->{'Name'} eq 'Error-Cause' &&  $a->{'Value'} eq 'Session-Context-Not-Found') {
	    $res = 41;
	}
    }
    #if ( $sender eq 'freeradius' ) { &radiusd::radlog(1, "strerr:".$strerr.";".$res_attr ); }
    return ( $res+0, "strerr:".$strerr.";".$res_attr );

}


sub GET_ppp_parm {

	#######  UserAuth ########### 
	my $RAD_REQUEST = shift;
	my $RAD_REPLY = shift;
	my $Q_upd_db = shift;

	DB_MSsql_connect(\$dbms);
	DB_mysql_connect(\$dbms);

	my %AP = (
		'callsub'	=> 'PPPoE2RADIUS',
		'login_service'	=> 0,
		'vlan_id'	=> 0,
		'id'		=> 0,
		'new_lease'	=> 0,
		'set'		=> 0,
		'vlan_zone'	=> 1,
		'update_db'	=> 0,
		'DB_portinfo'	=> 0,
		'name'		=> '',
		'swid'		=> 0,
		'bw_ctl'	=> 0,
		'nas_ip'	=> $RAD_REQUEST->{'NAS-IP-Address'},
		'login'		=> $RAD_REQUEST->{'User-Name'},
	);
	$Q_upd_db->{'User-Name'} = $RAD_REQUEST->{'User-Name'};
	my $ref_ms1;

	$AP{'trust'} = 1;

	if ( not exists($RAD_REQUEST->{'Framed-Protocol'}) and defined($RAD_REQUEST->{'NAS-Identifier'}) 
	and $RAD_REQUEST->{'NAS-Identifier'} eq $nas_conf->{'mail_server'} ) {
	    print Dumper $RAD_REQUEST;
	    $AP{'login_service'} = 1;
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
                    return -1;
                }
            } else {
                &radiusd::radlog(1,  "HW_MAC not Fix in RADIUS Pair" );
                return -1;
            }


	####### UserAuth ########### 
	if ( $AP{'login_service'} > 0 or $AP{'trust'} ) {
	    my $Q_UserAuth = "exec UserAuth '".$RAD_REQUEST->{'User-Name'}."', ".$AP{'login_service'};

	    my $sth1 = $dbms->prepare($Q_UserAuth);
	    $sth1->execute;
	    $ref_ms1 = $sth1->fetchrow_hashref();
	    $sth1->finish;
	    foreach my $key ( sort keys %{$ref_ms1} ) {
		print STDERR $key." = ".$ref_ms1->{$key}."\n";
	    }
	    # CardNumber = 1 | DSSpeed = -1 | IP1 = 10 | IP2 = 13 | IP3 = 100 | IP4 = 1 | IdTariff = 6 | InetSpeed = 10000
	    #  NumberPassword = 1 | Quote = 86400 | Status = 1 | TextError = | USSpeed = -1 | TypeConnect | Category
	    if ( defined($ref_ms1->{'CardNumber'}) and defined($ref_ms1->{'NumberPassword'}) ) {
		$RAD_REQUEST->{'User-Name'} = $ref_ms1->{'CardNumber'}.".".$ref_ms1->{'NumberPassword'}; }
	    } else {
		return -1;
	    }

	    if ( $AP{'login_service'} > 0 ) {
		#$RAD_REQUEST->{'User-Name'} = $ref_ms1->{'CardNumber'}.".".$ref_ms1->{'NumberPassword'};
		$AP{'trust'} = 1;
	    } elsif ( $AP{'login_service'} == 0 ) {
		if ( not defined($ref_ms1->{'TypeConnect'}) ) { $ref_ms1->{'TypeConnect'} = 21;}
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
		#$RAD_REQUEST->{'User-Name'} = $ref_ms1->{'CardNumber'}.".".$ref_ms1->{'NumberPassword'};
		$RAD_REPLY->{'Framed-IP-Address'} = $ref_ms1->{'IP1'}.".".$ref_ms1->{'IP2'}.".".$ref_ms1->{'IP3'}.".".$ref_ms1->{'IP4'};
		$RAD_REPLY->{'Session-Timeout'} = $ref_ms1->{'Quote'};

		if ( $RAD_REPLY->{'Framed-IP-Address'} =~ /^10\.13\.2[45]\d\.\d+/ ) {
		    $RAD_REPLY->{'Cisco-AVPair'} = "ip:dns-servers=".$nas_conf->{'FAKE_DNS'}." ".$nas_conf->{'FAKE_DNS'};
		} else {
		    $RAD_REPLY->{'Cisco-AVPair'} = "ip:dns-servers=".$nas_conf->{'DNS_IP1'}." ".$nas_conf->{'DNS_IP2'};
		}

		my $Query = ''; my $Q_upd = ''; my $PreQuery = '';
		my $date = strftime "%Y%m%d%H%M%S", localtime(time);
		my $job_parms = ''; $AP{'set'} = 0;

		if ( $AP{'trust'} > 0 and ( not $RAD_REPLY->{'Framed-IP-Address'} =~ /^10\.13\.2[45]\d\.\d{1,3}$/ ) and ( not $ref_ms1->{'Quote'} < 0 )) {
		# CardNumber = 1 | DSSpeed = -1 | IP1 = 10 | IP2 = 13 | IP3 = 100 | IP4 = 1 | IdTariff = 6 | InetSpeed = 10000 
		#  NumberPassword = 1 | Quote = 86400 | Status = 1 | TextError = | USSpeed = -1 | TypeConnect | Category
			#print Dumper %AP if $debug;
			dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS =>
			"AP_set = '".$AP{'set'}."', AP_DS = '".$ref_ms1->{'DSSpeed'}."', AP_US = '".$ref_ms1->{'USSpeed'}."'" );

			$Query = "INSERT INTO ap_login_info SET login='".$AP{'login'}."', start_date='".$date."', hw_mac='".$AP{'hw_mac'}."',  port_id='".$AP{'id'}."'";
			$Q_upd = " ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."', last_date='".$date."', vlan_id='-1'".
			", ip_addr='".$RAD_REPLY->{'Framed-IP-Address'}."'";

			$dbm->do( $Query.", ".$Q_upd.", trust=0  ON DUPLICATE KEY UPDATE ".$Q_upd );
			$Q_upd_db->{'Q_ap_login_info'} = $Query.",".$Q_upd.", trust=1 ON DUPLICATE KEY UPDATE ".$Q_upd.", trust=1" ;

			## HEAD_LINK inserting data
			if ( $ref_ms1->{'TypeConnect'} == 21 ) {
			    if ( $RAD_REPLY->{'Framed-IP-Address'} =~ /^10\./ ) { 
				$AP{'pri'} = $ref_ms1->{'Category'}||3;
			    } else {
				$AP{'pri'} = 3;
			    }
			    $Query = "INSERT INTO head_link SET port_id=".$AP{'id'}.", status=1, white_static_ip=0, dhcp_use=".$nas_conf->{'DHCP_USE'}.", ";
			    $Q_upd = " vlan_id=-1, login='".$AP{'login'}."', hw_mac='".$AP{'hw_mac'}."', communal=".$AP{'communal'}.
			    ", inet_shape=".$ref_ms1->{'InetSpeed'}.", inet_priority=".$AP{'pri'}.", stamp=NULL, ip_subnet='".$RAD_REPLY->{'Framed-IP-Address'}."'".
			    ", head_id=".$nas_conf->{'DHCP_HEAD_ID'}.", pppoe_up=1";
			    $Query .= $Q_upd." ON DUPLICATE KEY UPDATE ".$Q_upd;
			    $Q_upd_db->{'Q_head_link'} = $Query;
			}
			######################## SET JOB PARAMETERS #######################

			dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS =>
			"QUERY: Login  = '".$AP{'login'}."', MAC = '".$AP{'hw_mac'}."', NAS_IP = ".$AP{'nas_ip'}."\n".
			" Login = '".$AP{'login'}."', AP_ID = '".$AP{'id'}."', '".$AP{'name'}.", ZONE = ".$AP{'vlan_zone'}.", VLAN = -1 \n");
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
