#!/usr/bin/perl -w


use strict;
use DBI;
use Net::Telnet();
use IO::Pty ();

# use ...
# This is very important ! Without this script will not get the filled hashesh from main.
use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);
use Data::Dumper;


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
    'MYSQL_host'	=> 'localhost',
    'MYSQL_base'	=> 'switchnet',
    'MYSQL_user'	=> 'swgen',
    'MYSQL_pass'	=> 'SWgeneRatE',
    'STARTLINKCONF'	=> 20,
    'DHCP_lease_max'	=> 7200,
    'DHCP_lease_static'	=> 2678400,
    'ssh_host'		=> '77.239.208.17',
    'ssh_user'		=> 'datasync',
    'ssh_pass'		=> 'JoalvexFon',
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
	#&log_request_attributes;
	DB_mysql_check_connect(\$dbm, \%conf);
	my $res = RLM_MODULE_NOTFOUND; my $rows_up = -1; my $cli_addr = ''; 
	#my $new_req =0;


	#DHCP-Relay-Agent-Information = 0x0106000405dc0303020b010931302e33322e302e31
	my $vlan=oct('0x'.substr($RAD_REQUEST{'DHCP-Relay-Agent-Information'},10,4)) if defined($RAD_REQUEST{'DHCP-Relay-Agent-Information'});
	#&radiusd::radlog(1, "VLAN = $vlan");

	if ( $RAD_REQUEST{'DHCP-Message-Type'} eq 'DHCP-Release' ) {
	    $dbm->do("UPDATE dhcp_addr SET end_lease=0, agent_info=NULL, port_id=NULL, session=NULL, mac=NULL, vlan=NULL WHERE ip='".$RAD_REQUEST{'DHCP-Client-IP-Address'}.
	    "' and mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."' and agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}."' and static_ip<1");
	    $res = RLM_MODULE_OK;
	} elsif ( $RAD_REQUEST{'DHCP-Message-Type'} eq 'DHCP-Discover' ) {
	    my $Q_check_macport = "SELECT l.port_id, l.inet_shape, h.dhcp_lease, l.head_id, l.static_ip FROM head_link l, heads h WHERE ".
	    "l.head_id=h.head_id and h.dhcp_relay_ip='".$RAD_REQUEST{'DHCP-Gateway-IP-Address'}."' and l.mac='".
	    $RAD_REQUEST{'DHCP-Client-Hardware-Address'}."' and l.vlan_id=".$vlan." limit 1";
	    my $stm_port = $dbm->prepare($Q_check_macport);
	    $stm_port->execute();
	    if  ( $stm_port->rows == 1 ) {
		while (my $ref_port = $stm_port->fetchrow_hashref()) {

		    my $Q_Discover_start  = "SELECT ip, mask, gw, end_lease, static_ip FROM dhcp_addr WHERE head_id=".$ref_port->{'head_id'}." and real_ip>0";

		    my $Q_Discover_reuse = " and (( static_ip=1 and port_id=".$ref_port->{'port_id'}." and vlan=".$vlan." )".
		    " or ( ip='".$RAD_REQUEST{'DHCP-Requested-IP-Address'}."' and port_id=".$ref_port->{'port_id'}." and vlan=".$vlan." )".
		    " or ( end_lease<now() and port_id=".$ref_port->{'port_id'}." and vlan=".$vlan." )".
		    ") order by end_lease desc limit 1";

		    my $Q_Discover_new = " and end_lease<now() order by end_lease limit 1";

		    my $stm_disc = $dbm->prepare($Q_Discover_start.$Q_Discover_reuse);
		    $stm_disc->execute();
		    if  (not $stm_disc->rows ) {
			$stm_disc->finish;
			$stm_disc = $dbm->prepare($Q_Discover_start.$Q_Discover_new);
			$stm_disc->execute();
		    }

		    while (my $ref_disc = $stm_disc->fetchrow_hashref()) {
			if ( $ref_disc->{'static_ip'} > 0 ) { $ref_port->{'dhcp_lease'} = $conf{'DHCP_lease_max'}; }
			$RAD_REPLY{'DHCP-IP-Address-Lease-Time'} = $ref_port->{'dhcp_lease'};
			$RAD_REPLY{'DHCP-Your-IP-Address'}	 = $ref_disc->{'ip'};
			$RAD_REPLY{'DHCP-Subnet-Mask'}		 = $ref_disc->{'mask'};
			$RAD_REPLY{'DHCP-Router-Address'}	 = $ref_disc->{'gw'};
			my $Q_Disc_up = "UPDATE dhcp_addr SET agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}."'".
			", port_id=".$ref_port->{'port_id'}.", vlan=".$vlan.", mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."'".
			", session='".$RAD_REQUEST{'DHCP-Transaction-Id'}."', static_ip=".$ref_port->{'static_ip'}.", end_lease=ADDDATE(now(), INTERVAL ".
			$ref_port->{'dhcp_lease'}." SECOND) WHERE ip='".$ref_disc->{'ip'}."'";

			$rows_up = $dbm->do($Q_Disc_up);
			$res = RLM_MODULE_OK if $rows_up == 1;
		    }
		    if  (not $stm_disc->rows ) { &radiusd::radlog(1, 'All IP used in current DHCP scope... :-('); }
		    $stm_disc->finish;
		}
	    } else {
		    #$res = RLM_MODULE_REJECT;
		    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-Nack';
	    }
	    $stm_port->finish;
	} elsif ( $RAD_REQUEST{'DHCP-Message-Type'} eq 'DHCP-Request' ) {
		if ( $RAD_REQUEST{'DHCP-Client-IP-Address'} eq '0.0.0.0' ) {
		    $cli_addr = $RAD_REQUEST{'DHCP-Requested-IP-Address'};
		    #$new_req = 1;
		} else {
		    $cli_addr = $RAD_REQUEST{'DHCP-Client-IP-Address'};
		}
		#&radiusd::radlog(1, "CLI_IP = '".$cli_addr."'");
		#&radiusd::radlog(1, "ID_session ='".$RAD_REQUEST{'DHCP-Transaction-Id'}."'");
		my $Q_Request = "SELECT  d.ip, d.mask, d.gw, d.static_ip, h.dhcp_lease FROM dhcp_addr d, heads h WHERE ".
		" d.head_id=h.head_id and d.agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}.
		"' and d.vlan=".$vlan." and d.mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."' and d.ip='".$cli_addr."'".
		" and d.session='".$RAD_REQUEST{'DHCP-Transaction-Id'}."'";

		my $stm_req = $dbm->prepare($Q_Request);
		$stm_req->execute();
		#&radiusd::radlog(1, "stm_req exec SET Reply data rows - ".$stm_req->rows);
		while (my $ref_req = $stm_req->fetchrow_hashref()) {
			#if ( $ref_req->{'static_ip'} > 0 ) { $ref_req->{'dhcp_lease'} = $conf{'DHCP_lease_max'}; }
			#&radiusd::radlog(1, "SET Reply data");
			#$RAD_REPLY{'DHCP-IP-Address-Lease-Time'} = $ref_req->{'dhcp_lease'};
			$RAD_REPLY{'DHCP-IP-Address-Lease-Time'} = ( $ref_req->{'static_ip'} > 0 ? $conf{'DHCP_lease_max'} : $ref_req->{'dhcp_lease'} );
			$RAD_REPLY{'DHCP-Your-IP-Address'}	 = $ref_req->{'ip'};
			$RAD_REPLY{'DHCP-Subnet-Mask'}		 = $ref_req->{'mask'};
			$RAD_REPLY{'DHCP-Router-Address'}	 = $ref_req->{'gw'};

			my $Q_Request_up =  "UPDATE dhcp_addr SET end_lease=ADDDATE(now(), INTERVAL ".
			( $ref_req->{'static_ip'} > 0 ? $conf{'DHCP_lease_max'} : $ref_req->{'dhcp_lease'} )." SECOND )".
			" WHERE agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}."' and mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."'".
			" and ip='".$cli_addr."' and session='".$RAD_REQUEST{'DHCP-Transaction-Id'}."'";

			if ($ref_req->{'static_ip'} < 1) {
			    $rows_up = $dbm->do($Q_Request_up);
			} else {
			    $rows_up = 2;
			}

			if ($rows_up > 0) {
			    $res = RLM_MODULE_OK;
			    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-Ack';
			    &radiusd::radlog(1, "UPDATE ".$rows_up." rows in Request");
			    #ssh_cmd();
			} else {
			    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-Nack';
			    $res = RLM_MODULE_REJECT;
			}
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
