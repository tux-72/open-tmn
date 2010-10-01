#!/usr/bin/perl -w

use strict;

# use ...
# This is very important ! Without this script will not get the filled hashesh from main.
use vars qw(%RAD_REQUEST %RAD_REPLY %RAD_CHECK);

use FindBin '$Bin';
use lib $Bin.'/../lib';
use SWConf;
use SWFunc;

my $debug = 1;

my %AP_dbq = ();

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



sub log_request_attributes {
	# This shouldn't be done in production environments!
	# This is only meant for debugging!
	&radiusd::radlog(1, "--");
	for (keys %RAD_REQUEST) {
		&radiusd::radlog(1, "RAD_REQUEST: $_ = $RAD_REQUEST{$_}");
	}
}


######################## PPPoE AUTH #############################

sub post_auth {
	my $res = -1;
	if ( defined($RAD_REQUEST{'DHCP-Message-Type'}) ) {
	    $res = DHCP_post_auth ( \%RAD_REQUEST, \%RAD_REPLY );
	    return $res;
	} elsif ( defined($RAD_REQUEST{'Framed-Protocol'}) and $RAD_REQUEST{'Framed-Protocol'} eq 'PPP' )  {
	    $RAD_REQUEST{'User-Name'} = $AP_dbq{'User-Name'};
	    $res = PPP_post_auth ( \%AP_dbq, \%RAD_REQUEST );
	    if ( $res < 0 ) {
		return RLM_MODULE_REJECT;
	    }
	}
	return RLM_MODULE_OK;
}

# Function to handle authorize
sub authorize {

    if ( defined($RAD_REQUEST{'DHCP-Message-Type'}) ) {
	return RLM_MODULE_OK; 
    } else {
	### TEST only!!!###################################
	$RAD_REQUEST{'NAS-IP-Address'} = '192.168.100.12' if ( $RAD_REQUEST{'NAS-IP-Address'} eq '192.168.100.30' and $debug );
	###################################################

	my $res = GET_ppp_parm( \%RAD_REQUEST, \%RAD_REPLY, \%AP_dbq );

	if ( $res < 0 ) {
	    return RLM_MODULE_REJECT;
	}
	return RLM_MODULE_OK;
    }
}

# Function to handle authenticate
sub authenticate {
#       &log_request_attributes;
        #$RAD_REQUEST{'Chap-Password'} = "JocNacoigHar";
        #$RAD_REPLY{'Cleartext-Password'} = "JocNacoigHar";

       if ($RAD_REQUEST{'User-Name'} =~ /^baduser123/i) {
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
        my $res = ACC_update ( \%RAD_REQUEST );
	if ( $res < 0 ) {
	    return RLM_MODULE_REJECT;
	}
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

