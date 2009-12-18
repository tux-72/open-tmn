#!/usr/bin/perl -w


use strict;
use DBI;
# use ...
# This is very important ! Without this script will not get the filled hashesh from main.
use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);
#use Data::Dumper;


# This is hash wich hold original request from radius
#my %RAD_REQUEST;
# In this hash you add values that will be returned to NAS.
#my %RAD_REPLY;
#This is for check items
#my %RAD_CHECK;

#
# This the remapping of return values
#
	use constant    RLM_MODULE_REJECT=>    0;#  /* immediately reject the request */
	use constant	RLM_MODULE_FAIL=>      1;#  /* module failed, don't reply */
	use constant	RLM_MODULE_OK=>        2;#  /* the module is OK, continue */
	use constant	RLM_MODULE_HANDLED=>   3;#  /* the module handled the request, so stop. */
	use constant	RLM_MODULE_INVALID=>   4;#  /* the module considers the request invalid. */
	use constant	RLM_MODULE_USERLOCK=>  5;#  /* reject the request (user is locked out) */
	use constant	RLM_MODULE_NOTFOUND=>  6;#  /* user not found */
	use constant	RLM_MODULE_NOOP=>      7;#  /* module succeeded without doing anything */
	use constant	RLM_MODULE_UPDATED=>   8;#  /* OK (pairs modified) */
	use constant	RLM_MODULE_NUMCODES=>  9;#  /* How many return codes there are */


my $res = 0; 
my %conf = (
    'MYSQL_host',	'localhost',
    'MYSQL_base',	'switchnet',
    'MYSQL_user',	'swgen',
    'MYSQL_pass',	'SWgeneRatE',
    'DHCP_lease',	120,
    'DHCP_lease_wait',	300,
    'STARTLINKCONF',    20,

    'DHCP-NTP',		'77.239.208.17',
    'DHCP-DNS1',	'77.239.208.17',
    'DHCP-DNS2',	'77.239.208.10',
);


my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
#dlog ( SUB => $script_name, LOGTYPE => 'LOGRADIUS', DBUG => 2, MESS => "Use BIN directory - $Bin" );

my $dbm; $res = DB_mysql_connect(\$dbm, \%conf);
if ($res < 1) {
    #dlog ( SUB => (caller(0))[3], DBUG => 0, LOGTYPE => 'LOGRADIUS', MESS => "Connect to MYSQL DB FAILED, RESULT = $res" );
    DB_mysql_check_connect(\$dbm, \%conf);
}



# Function to handle post_auth

sub post_auth {
	# For debugging purposes only
	&log_request_attributes;
	DB_mysql_check_connect(\$dbm, \%conf);
	my $res = RLM_MODULE_NOTFOUND; my $portid=0; my $rows_up = -1; my $cli_addr = ''; my $sess_up = 0;


	#DHCP-Relay-Agent-Information = 0x0106000405dc0303020b010931302e33322e302e31
	my $vlan=oct('0x'.substr($RAD_REQUEST{'DHCP-Relay-Agent-Information'},10,4)) if defined($RAD_REQUEST{'DHCP-Relay-Agent-Information'});
	#&radiusd::radlog(1, "VLAN = $vlan");

	if ( $RAD_REQUEST{'DHCP-Message-Type'} eq 'DHCP-Release' ) {
		$dbm->do("UPDATE dhcp_addr SET end_lease=0, agent_info=NULL, port_id=NULL, session=NULL, mac=NULL, vlan=NULL WHERE ip='".$RAD_REQUEST{'DHCP-Client-IP-Address'}.
		"' and mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."' and agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}."'");
		$res = RLM_MODULE_OK;
	} elsif ( $RAD_REQUEST{'DHCP-Message-Type'} eq 'DHCP-Discover' ) {
	    my $Q_check_macport = "SELECT port_id FROM swports WHERE link_type>".$conf{'STARTLINKCONF'}." and mac_port='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}.
	    "' and portvlan=".$vlan." order by mac_port desc limit 1";
	    my $stm_port = $dbm->prepare($Q_check_macport);
	    $stm_port->execute();
	    if  ( $stm_port->rows ) {
		while (my $ref_port = $stm_port->fetchrow_hashref()) {
		    $portid=$ref_port->{'port_id'};
		}
		my $Q_Discover_start = "SELECT ip, mask, gw, end_lease FROM dhcp_addr WHERE head_id in ( select head_id FROM heads WHERE dhcp_relay_ip='".$RAD_REQUEST{'DHCP-Gateway-IP-Address'}."' )";
		my $Q_Discover_existing_IP = " and ( ( ip='".$RAD_REQUEST{'DHCP-Requested-IP-Address'}."' and mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."' and vlan=".$vlan." ) or ";
		my $Q_Discover_new_IP = " ( end_lease<now()+".$conf{'DHCP_lease_wait'}." and static_ip<1 ) )";
		my $Q_Discover_end = " order by end_lease limit 1";

		my $stm_disc = $dbm->prepare($Q_Discover_start.$Q_Discover_existing_IP.$Q_Discover_new_IP.$Q_Discover_end);
		$stm_disc->execute();
		while (my $ref_disc = $stm_disc->fetchrow_hashref()) {
		    $RAD_REPLY{'DHCP-NTP-Servers'}	 	= $conf{'DHCP-NTP'};
		    $RAD_REPLY{'DHCP-Domain-Name-Server'}	= $conf{'DHCP-DNS1'};
		    $RAD_REPLY{'DHCP-Domain-Name-Server'}	= $conf{'DHCP-DNS2'};
		    $RAD_REPLY{'DHCP-IP-Address-Lease-Time'}	= $conf{'DHCP_lease'};
		    $RAD_REPLY{'DHCP-Your-IP-Address'}		= $ref_disc->{'ip'};
		    $RAD_REPLY{'DHCP-Subnet-Mask'}		= $ref_disc->{'mask'};
		    $RAD_REPLY{'DHCP-Router-Address'}		= $ref_disc->{'gw'};
		    $rows_up = $dbm->do("UPDATE dhcp_addr SET end_lease=now()+60+".$conf{'DHCP_lease'}.", agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}."'".
		    ", port_id=".$portid.", vlan=".$vlan.", mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}.
		    #", session=".$RAD_REQUEST{'DHCP-Transaction-Id'}.
		    "' WHERE ip='".$ref_disc->{'ip'}."'");
		    $res = RLM_MODULE_OK if $rows_up == 1;
		}
	    } else {
		    $res = RLM_MODULE_REJECT;
		    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-Nack';
	    }
	    $stm_port->finish;
	} elsif ( $RAD_REQUEST{'DHCP-Message-Type'} eq 'DHCP-Request' ) {
		if ( $RAD_REQUEST{'DHCP-Client-IP-Address'} eq '0.0.0.0' ) {
		    $cli_addr = $RAD_REQUEST{'DHCP-Requested-IP-Address'};
		} else {
		    $cli_addr = $RAD_REQUEST{'DHCP-Client-IP-Address'};
		    $sess_up = 1;
		}
		#&radiusd::radlog(1, "CLI_IP = '".$cli_addr."'");
		#&radiusd::radlog(1, "ID_session ='".$RAD_REQUEST{'DHCP-Transaction-Id'}."'");
		
		my $Q_Request = "SELECT ip, mask, gw, end_lease FROM dhcp_addr WHERE agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}.
		"' and mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."' and ip='".$cli_addr."'";
		if ($sess_up) { $Q_Request .= " and session=".$RAD_REQUEST{'DHCP-Transaction-Id'}; }

		my $stm_req = $dbm->prepare($Q_Request);
		$stm_req->execute();
		#&radiusd::radlog(1, "stm_req exec SET Reply data rows - ".$stm_req->rows);
		while (my $ref_req = $stm_req->fetchrow_hashref()) {
			#&radiusd::radlog(1, "SET Reply data");
			$RAD_REPLY{'DHCP-NTP-Servers'}	 	 = $conf{'DHCP-NTP'};
			$RAD_REPLY{'DHCP-Domain-Name-Server'}	 = $conf{'DHCP-DNS1'};
			$RAD_REPLY{'DHCP-Domain-Name-Server'}	 = $conf{'DHCP-DNS2'};
			$RAD_REPLY{'DHCP-IP-Address-Lease-Time'} = $conf{'DHCP_lease'};
			$RAD_REPLY{'DHCP-Your-IP-Address'}	 = $ref_req->{'ip'};
			$RAD_REPLY{'DHCP-Subnet-Mask'}		 = $ref_req->{'mask'};
			$RAD_REPLY{'DHCP-Router-Address'}	 = $ref_req->{'gw'};

			my $Q_Request_up =  "UPDATE dhcp_addr SET end_lease=now()+60+".$conf{'DHCP_lease'}." WHERE agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}.
			"' and mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."' and ip='".$cli_addr."'";
			if ($sess_up) { $Q_Request_up .= " and session=".$RAD_REQUEST{'DHCP-Transaction-Id'}; } 
			$rows_up = $dbm->do($Q_Request_up);
			if ($rows_up == 1) {
			    $res = RLM_MODULE_OK;
			    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-Ack';
			} else {
			    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-Nack';
			}

			&radiusd::radlog(1, "UPDATE ".$rows_up." rows in Request");
		}
		$stm_req->finish;
	} else {
	    $res = RLM_MODULE_OK;
	}
	return $res;
#	return RLM_MODULE_OK;
}

sub log_request_attributes {
	# This shouldn't be done in production environments!
	# This is only meant for debugging!
	&radiusd::radlog(1, "--");
	for (keys %RAD_REQUEST) {
		&radiusd::radlog(1, "RAD_REQUEST: $_ = $RAD_REQUEST{$_}");
	}
}

sub DB_mysql_connect {
    $dbm = DBI->connect_cached("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'})
    or die dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MYSQL DB host ".$conf{'MYSQL_host'}."$DBI::errstr" );
    $dbm->do("SET NAMES 'koi8r'") or die return -1;
    return 1;
}


sub DB_mysql_check_connect {
    my $db_ping = $dbm->ping;
    #dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DB PING = $db_ping" );
    if ( $db_ping != 1 ) {
        dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DB PING = $db_ping, MYSQL connect lost! RECONNECT to DB host ".$conf{'MYSQL_host'} );
        $dbm->disconnect;
        $dbm = DBI->connect_cached("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'})
        or dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MYSQL DB host ".$conf{'MYSQL_host'}."$DBI::errstr" );
        $dbm->do("SET NAMES 'koi8r'");
    }
}
