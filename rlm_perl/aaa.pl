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

use Data::Dumper;

my $debug=1;

my $nas_conf  = \%SWConf::aaa_conf;

#my $dbm;
#my $dbms;

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


sub post_auth {

}

sub log_request_attributes {
	# This shouldn't be done in production environments!
	# This is only meant for debugging!
	&radiusd::radlog(1, "--");
	for (keys %RAD_REQUEST) {
		&radiusd::radlog(1, "RAD_REQUEST: $_ = $RAD_REQUEST{$_}");
	}
}


######################## PPPoE AUTH #############################

# Function to handle authorize
sub authorize {
       # For debugging purposes only
#       &log_request_attributes;
	

	my %AP = (
		'callsub'	=> 'PPPoE2RADIUS',
		'login_service'	=> 0,
		'vlan_id'	=> 0,
#		'hw_mac'	=> '00:17:31:56:7f:d9',
		'trusted'	=> 0,
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
		'nas_ip'	=> $RAD_REQUEST{'NAS-IP-Address'},
		'nas_ip'	=> '192.168.100.12',
		'login'		=> $RAD_REQUEST{'User-Name'},
	);

	# Cisco-AVPair = "client-mac-address=0017.3156.7fd9"
	#    &radiusd::radlog(1,  "CISCO AVPair  = ".  $RAD_REQUEST{'Cisco-AVPair'} );
	if ( defined($RAD_REQUEST{'Cisco-AVPair'}) and $RAD_REQUEST{'Cisco-AVPair'} =~ /client\-mac\-address\=(\w\w)(\w\w)\.(\w\w)(\w\w)\.(\w\w)(\w\w)/ ) {
	    $AP{'hw_mac'} = lc("$1:$2:$3:$4:$5:$6");
	    &radiusd::radlog(1,  "HW_MAC = ". $AP{'hw_mac'} );
	    if (($AP{'hw_mac'} eq "0") || ($AP{'hw_mac'} eq "00:00:00:00:00:00")) {
		&radiusd::radlog(1, "User '".$AP{'login'}."' MAC '".$AP{'hw_mac'}."' is Wrong!!!\n\n") if $debug;
	    }
	} else {
	    &radiusd::radlog(1,  "HW_MAC not Fix in RADIUS Pair" );
	}
	#########
	####################### FOR DEBUGGING ############################
	if ( $RAD_REQUEST{'User-Name'} eq 'comtest1' and $debug ) {
	    $AP{'nas_ip'}	= '192.168.100.12' ;
	    $RAD_REPLY{'Framed-IP-Address'} = "10.13.100.1";
	    $RAD_REQUEST{'User-Name'} = '1.1';
	}
	####################### FOR DEBUGGING ############################
	########

	if ( $RAD_REQUEST{'NAS-IP-Address'} eq $nas_conf->{'mail_server'} ) {
	    $AP{'login_service'} = 1;
	} else {
	    $AP{'cisco_num'} = 1;
	    #$RAD_REPLY{'Framed-IP-Address'} = '10.13.100.1';
	}

	####### Fixing VLAN ID ###########
	SW_VLAN_fix( \%AP );
	&radiusd::radlog(1, "User VLAN = ".$AP{'vlan_id'} );

	#print Dumper %AP;
	####### Fixing AP ID ###########
	SW_AP_fix( \%AP );
	&radiusd::radlog(1, "User AP_id = ".$AP{'id'} );

	###### Get parms from Billing
	#$AP{'login'} = 'comtest111';
	GET_ppp_parm( \%AP, \%RAD_REPLY );

	print Dumper %RAD_REPLY;

	if ( $AP{'trusted'} < 0 ) {
	    return RLM_MODULE_REJECT;
	} else {
	    $RAD_REQUEST{'User-Name'} = $AP{'login_id'};
	    return RLM_MODULE_OK;
	}
}

# Function to handle authenticate
sub authenticate {
       # For debugging purposes only
#       &log_request_attributes;
        #$RAD_REQUEST{'Chap-Password'} = "JocNacoigHar";
        #$RAD_REPLY{'Cleartext-Password'} = "JocNacoigHar";

       if ($RAD_REQUEST{'User-Name'} =~ /^comtest1/i) {
               # Reject user and tell him why
               $RAD_REPLY{'Reply-Message'} = "Denied access by rlm_perl function";
               return RLM_MODULE_REJECT;
       } else {
               # Accept user and set some attribute
               $RAD_REPLY{'h323-credit-amount'} = "100";
               return RLM_MODULE_OK;
       }
}

# Function to handle preacct
sub preacct {
       # For debugging purposes only
#       &log_request_attributes;

       return RLM_MODULE_OK;
}

# Function to handle accounting
sub accounting {
       # For debugging purposes only
#       &log_request_attributes;

       # You can call another subroutine from here
       &test_call;

       return RLM_MODULE_OK;
}

# Function to handle checksimul
sub checksimul {
       # For debugging purposes only
#       &log_request_attributes;

       return RLM_MODULE_OK;
}

# Function to handle pre_proxy
sub pre_proxy {
       # For debugging purposes only
#       &log_request_attributes;

       return RLM_MODULE_OK;
}

# Function to handle post_proxy
sub post_proxy {
       # For debugging purposes only
#       &log_request_attributes;

       return RLM_MODULE_OK;
}


# Function to handle detach
sub detach {
       # For debugging purposes only
#       &log_request_attributes;

       # Do some logging.
       &radiusd::radlog(0,"rlm_perl::Detaching. Reloading. Done.");
} 

#
# Some functions that can be called from other functions
#

sub test_call {
       # Some code goes here
}

