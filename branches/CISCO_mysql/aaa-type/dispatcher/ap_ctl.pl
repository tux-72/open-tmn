#!/usr/bin/perl

use strict;
no strict qw(refs);

use FindBin '$Bin';
use lib $Bin.'/../../lib';

use SWConf;
use SWFunc;
use SWFuncAAA;
use SWFuncDisp;

my $VER = 0.92;

my $debug = 1;

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );

sub startup {
    &dispatcher::log(1, "startup\n");
}

sub ap_check {

    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param, 'ap_check'); 
 
    ## GET AP_ID from SWCTL
    my ($ap_res, $ap_val) = SW_AP_get (\%param);
    return ($ap_res+0, $ap_val);
}


sub ap_tune {

    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param, 'ap_tune'); 

    ## SEND FREE AP_ID to SWCTL
    my ($ap_res, $ap_val) = SW_AP_tune (\%param);
    return ($ap_res+0, $ap_val);
}

sub ap_link_state {

    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param, 'ap_link_state'); 

    ## SEND FREE AP_ID to SWCTL
    my ($ap_res, $ap_val) = SW_AP_linkstate (\%param);
    return ($ap_res+0, $ap_val);
}

sub ap_free {

    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param, 'ap_free'); 

    ## SEND FREE AP_ID to SWCTL
    my ($ap_res, $ap_val) = SW_AP_free (\%param);
    return ($ap_res+0, $ap_val);

}

sub send_pod  {

    dlog ( SUB => 'send_pod', LOGTYPE => 'LOGDISP', DBUG => 1, MESS => "-- SUB send_pod --" );
    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param, 'send_pod'); 
    # nas_ip nas_port nas_secret login

    return SW_send_pod ( \%param, 'dispatcher' )
}

sub parm_log {
    my $parm = shift;
    my $subs = shift;
    my $str_log = "--\nreceive parms: ";
    while(my ($k,$v)=each(%$parm)) {
	$str_log .= " $k='$v',";
    }
    dlog ( SUB => $subs, LOGTYPE => 'LOGDISP', DBUG => 1, MESS => $str_log );
}

1;
