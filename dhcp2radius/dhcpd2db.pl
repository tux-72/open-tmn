#!/usr/bin/perl -w

use strict;

# use ...
# This is very important ! Without this script will not get the filled hashesh from main.
use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);
#use Data::Dumper;

use FindBin '$Bin';
use lib $Bin.'/../lib';
use SWConf;
use SWFunc;

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


# Function to handle post_auth
my $debug=1;
my $res = 0; 
my $dbm;

sub post_auth {
	# For debugging purposes only
	#&log_request_attributes;
	my $res = RLM_MODULE_NOTFOUND; my $rows_up = -1; my $cli_addr = ''; my $ap_id = '';

	DB_mysql_connect(\$dbm);
	#&radiusd::radlog(1, "Mysql connect ID = ".$dbm->{'mysql_thread_id'}."\n") if $debug;

	#DHCP-Relay-Agent-Information = 0x0106000405dc0303020b010931302e33322e302e31
	my $vlan=oct('0x'.substr($RAD_REQUEST{'DHCP-Relay-Agent-Information'},10,4)) if defined($RAD_REQUEST{'DHCP-Relay-Agent-Information'});
	&radiusd::radlog(1, "New ".$RAD_REQUEST{'DHCP-Message-Type'}." VLAN = $vlan, MAC = ".$RAD_REQUEST{'DHCP-Client-Hardware-Address'} );

	my %AP = (
		'VLAN'		=> $vlan,
		'MAC'		=> $RAD_REQUEST{'DHCP-Client-Hardware-Address'},
		'id'		=> 0,
		'new_lease'	=> 0,
	);

	if ( $RAD_REQUEST{'DHCP-Message-Type'} eq 'DHCP-Release' ) {
	    $dbm->do("UPDATE dhcp_addr SET end_lease=now(), session=NULL WHERE ip='".$RAD_REQUEST{'DHCP-Client-IP-Address'}.
	    "' and hw_mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."' and agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}."'".
	    " and a.session='".$RAD_REQUEST{'DHCP-Transaction-Id'}."'" );
	    $res = RLM_MODULE_OK;

	} elsif ( $RAD_REQUEST{'DHCP-Message-Type'} eq 'DHCP-Discover' ) {
	    ## Выясняем предварительное разрешение использования IP-Unnumbered подключения по данным DHCP-Relay-Agent-Information
	    my $Q_check_macport = "SELECT l.port_id, l.inet_shape, l.head_id, l.static_ip, l.status, l.login, h.term_ip ".
	    " FROM head_link l, heads h WHERE l.head_id=h.head_id and l.pppoe_up=0 and l.inet_priority=1 and h.dhcp_relay_ip='".
	    $RAD_REQUEST{'DHCP-Gateway-IP-Address'}."' and l.status=1 and l.hw_mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."' and l.vlan_id=".$vlan;
	    my $stm_port = $dbm->prepare($Q_check_macport);
	    $stm_port->execute();
	    if  ( $stm_port->rows == 1 ) {
		while (my $ref_port = $stm_port->fetchrow_hashref()) {
		  ######  Выясняем точку доступа ######
		  SW_AP_fix( AP_INFO => \%AP, NAS_IP => $ref_port->{'term_ip'}, LOGIN => $ref_port->{'login'}, VLAN => $AP{'VLAN'}, HW_MAC => $AP{'MAC'} );
		  if ( $AP{'id'} == $ref_port->{'port_id'} ) {
		    &radiusd::radlog(1, "Verify trusted AP_id ".$AP{'id'}." PASS!\n") if $debug;
		    # Выделить IP
		    my $Q_Discover_start  = "SELECT a.login, a.ip, a.start_lease, a.end_lease, p.mask, p.gw, p.static_ip, p.dhcp_lease FROM dhcp_addr a, dhcp_pools p ".
		    " WHERE p.head_id=".$ref_port->{'head_id'}." and p.pool_id=a.pool_id";

		    my $Q_Discover_reuse = ""; my $Q_Discover_new ='' ; my $Q_Discover_grey ='' ;
		    ### Поиск назначенного статического белого IP
		    if ( $ref_port->{'static_ip'} == 1 and $ref_port->{'status'} == 1 ) {
			$Q_Discover_reuse = " and p.real_ip>0 and p.static_ip>0 and a.login='".$ref_port->{'login'}."'";
			$Q_Discover_new   = " and p.real_ip<1 and p.static_ip<1 and a.end_lease<now() and a.inet_shape=".$ref_port->{'inet_shape'}.
			" order by a.end_lease limit 1";
		    ### Поиск ранее выдаваемого динамического белого IP
		    } elsif ( $ref_port->{'static_ip'} < 1 and $ref_port->{'status'} == 1 ) {
			$Q_Discover_reuse = " and p.real_ip>0 and p.static_ip<1 and a.login='".$ref_port->{'login'}."'".
			" and a.inet_shape=".$ref_port->{'inet_shape'};
			$Q_Discover_new   = " and p.real_ip>0 and p.static_ip<1 and a.end_lease<now() and a.inet_shape=".$ref_port->{'inet_shape'};
			$Q_Discover_grey  = " and p.real_ip<1 and p.static_ip>1 and ( a.login='".$ref_port->{'login'}."' or ( a.end_lease<now()".
			" and a.inet_shape=".$ref_port->{'inet_shape'}." ))";
		    ### Поиск ранее выдаваемого серого IP ( линк заблокирован в билинге )
		    } elsif ( $ref_port->{'status'} == 2 ) {
			$Q_Discover_reuse = " and p.real_ip<1 and p.static_ip<1 and a.login='".$ref_port->{'login'}."'";
			$Q_Discover_new   = " and p.real_ip<1 and p.static_ip<1 and a.end_lease<now()";
		    } else {
			$RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-NAK';
			return RLM_MODULE_NOTFOUND;
		    }
		    $Q_Discover_reuse	.= " order by a.end_lease desc limit 1";
		    $Q_Discover_new	.= " order by a.end_lease limit 1";
		    $Q_Discover_grey	.= " order by a.end_lease limit 1";
		    #&radiusd::radlog(1, "Discover_start = ".$Q_Discover_start.$Q_Discover_reuse."\n") if $debug;

		    my $stm_disc = $dbm->prepare($Q_Discover_start.$Q_Discover_reuse);
		    $stm_disc->execute();
		    if  ( not $stm_disc->rows ) {
			$AP{'new_lease'}=1;
			#&radiusd::radlog(1, "Discover_new   = ".$Q_Discover_start.$Q_Discover_new."\n") if $debug;
			$stm_disc->finish;
			$stm_disc = $dbm->prepare($Q_Discover_start.$Q_Discover_new);
			$stm_disc->execute();
			if  ( not $stm_disc->rows and $ref_port->{'static_ip'} < 1 and $ref_port->{'status'} == 1 ) {
			    $stm_disc->finish;
			    $stm_disc = $dbm->prepare($Q_Discover_start.$Q_Discover_grey);
			    $stm_disc->execute();
			}
			if  (not $stm_disc->rows ) {
			    &radiusd::radlog(1, 'All IP used in available DHCP scopes... :-('); 
			    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-NAK';
			    return RLM_MODULE_NOTFOUND;
			}
		    }

		    while (my $ref_disc = $stm_disc->fetchrow_hashref()) {
			if  ( $AP{'new_lease'} and $ref_port->{'status'} == 1 and $ref_disc->{'login'} ) {
			    $Q_Discover_new = "INSERT INTO dhcp_addr_arch ( ip, login, hw_mac, start_lease, end_lease, inet_shape, port_id, agent_info )".
			    " SELECT ip, login, hw_mac, start_lease, end_lease, inet_shape, port_id, agent_info FROM dhcp_addr WHERE ip='".$ref_disc->{'ip'}."'";
			    &radiusd::radlog(1, " Archive prev login = ".$Q_Discover_new) if $debug;
			    $dbm->do($Q_Discover_new);
			    #$dbm->do( "INSERT into dhcp_addr_arch set ip=".$stm_disc->{'ip'}.", login=".$stm_disc->{'login'}.
			    #", start_lease=".$stm_disc->{'start_lease'}.", end_lease=".$stm_disc->{'end_lease'} );
			}
			$RAD_REPLY{'DHCP-IP-Address-Lease-Time'} = $ref_disc->{'dhcp_lease'};
			$RAD_REPLY{'DHCP-Your-IP-Address'}	 = $ref_disc->{'ip'};
			$RAD_REPLY{'DHCP-Subnet-Mask'}		 = $ref_disc->{'mask'};
			$RAD_REPLY{'DHCP-Router-Address'}	 = $ref_disc->{'gw'};
			my $Q_Disc_up = "UPDATE dhcp_addr SET agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}."', login='".$ref_port->{'login'}."'".
			", port_id=".$ref_port->{'port_id'}.", vlan_id=".$vlan.", hw_mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."'".
			", session='".$RAD_REQUEST{'DHCP-Transaction-Id'}."'".( $AP{'new_lease'} ? ", start_lease=NULL" : "" ).", end_lease=ADDDATE(now(), INTERVAL ".$ref_disc->{'dhcp_lease'}." SECOND)".
			" WHERE ip='".$ref_disc->{'ip'}."'";
			$rows_up = $dbm->do($Q_Disc_up);
			$res = RLM_MODULE_OK if $rows_up == 1;
		    }
		    if  (not $stm_disc->rows ) { &radiusd::radlog(1, 'All IP used in available DHCP scopes... :-('); }
		    $stm_disc->finish;
		  } else {
		    &radiusd::radlog(1, "AP for MAC = ".$AP{'MAC'}." and VLAN = ".$AP{'VLAN'}." not fixed :-( ...\n") if $debug;
		    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-NAK';
		    $res = RLM_MODULE_NOTFOUND;
		  }
		}
	    } else {
		    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-NAK';
		    $res = RLM_MODULE_NOTFOUND;
	    }
	    $stm_port->finish;
	} elsif ( $RAD_REQUEST{'DHCP-Message-Type'} eq 'DHCP-Request' ) {
		$cli_addr = ( $RAD_REQUEST{'DHCP-Client-IP-Address'} eq '0.0.0.0' ? $RAD_REQUEST{'DHCP-Requested-IP-Address'} : $RAD_REQUEST{'DHCP-Client-IP-Address'} );
		&radiusd::radlog(1, "CLI_IP = '".$cli_addr."'") if $debug;
		&radiusd::radlog(1, "ID_session ='".$RAD_REQUEST{'DHCP-Transaction-Id'}."'") if $debug;

		my $Q_Request = "SELECT a.session, a.ip, a.port_id, p.mask, p.gw, p.static_ip, p.dhcp_lease, l.login, h.term_ip ".
		" FROM dhcp_addr a, dhcp_pools p, head_link l, heads h ".
		" WHERE l.head_id=h.head_id and l.login=a.login and l.hw_mac=a.hw_mac and a.port_id=l.port_id and a.pool_id=p.pool_id and a.inet_shape=l.inet_shape ".
		" and l.status=1 and l.pppoe_up=0 and l.inet_priority=1 and h.dhcp_relay_ip='".$RAD_REQUEST{'DHCP-Gateway-IP-Address'}."' ".
		" and a.ip='".$cli_addr."' and a.agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}."' ".
		" and a.hw_mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."'";
		#&radiusd::radlog(1, $Q_Request) if $debug;

		my $stm_req = $dbm->prepare($Q_Request);
		$stm_req->execute();
		#&radiusd::radlog(1, "stm_req exec SET Reply data rows - ".$stm_req->rows);
		if  ( $stm_req->rows == 1 ) {
		    while (my $ref_req = $stm_req->fetchrow_hashref()) {

			if ( $ref_req->{'session'} ne $RAD_REQUEST{'DHCP-Transaction-Id'} ) {
			    SW_AP_fix( AP_INFO => \%AP, NAS_IP => $ref_req->{'term_ip'}, LOGIN => $ref_req->{'login'} , VLAN => $AP{'VLAN'}, HW_MAC => $AP{'MAC'} );
			    if ( $AP{'id'} != $ref_req->{'port_id'} ) {
				$RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-NAK';
				return RLM_MODULE_NOTFOUND;
			    } else {
				&radiusd::radlog(1, "Verify trusted AP_id ".$AP{'id'}." PASS!\n") if $debug;
			    }
			}
			#&radiusd::radlog(1, "SET Reply data");
			$RAD_REPLY{'DHCP-IP-Address-Lease-Time'} = $ref_req->{'dhcp_lease'};
			$RAD_REPLY{'DHCP-Your-IP-Address'}	 = $ref_req->{'ip'};
			$RAD_REPLY{'DHCP-Subnet-Mask'}		 = $ref_req->{'mask'};
			$RAD_REPLY{'DHCP-Router-Address'}	 = $ref_req->{'gw'};

			my $Q_Request_up =  "UPDATE dhcp_addr SET end_lease=ADDDATE(now(), INTERVAL ".$ref_req->{'dhcp_lease'}.
			" SECOND ), session='".$RAD_REQUEST{'DHCP-Transaction-Id'}."' WHERE agent_info='".$RAD_REQUEST{'DHCP-Relay-Agent-Information'}.
			"' and hw_mac='".$RAD_REQUEST{'DHCP-Client-Hardware-Address'}."'".
			" and ip='".$cli_addr."'";

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
			    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-NAK';
			    $res = RLM_MODULE_REJECT;
			}
		    }
		} else {
		    $RAD_REPLY{'DHCP-Message-Type'} = 'DHCP-NAK';
		    $res = RLM_MODULE_NOTFOUND;
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
