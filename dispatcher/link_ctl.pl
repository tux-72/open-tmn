#!/usr/bin/perl


my $debug=0;

$VERSION = 0.7;

#use strict;

use Authen::Radius;
use FindBin '$Bin';
require $Bin . '/../conf/libap.pl';
Authen::Radius->load_dictionary();


my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
print STDERR  "Use BIN directory - $Bin\n" if $debug;

sub startup {
    &dispatcher::log(1, "startup\n");
}

sub ap_check {
    &dispatcher::log(1, "-- SUB ap_check --\n");

    my %param;
    %param=split(/[:;]/,shift);

    parm_log(\%param); 
    #print params to log
    #while(my ($k,$v)=each(%param)) {
    #	&dispatcher::log(1, "$k = $v\n");
    #}

    ## GET AP_ID from SWCTL
    my ($ap_res, $ap_val) = SW_AP_get (\%param);
    return ($ap_res+0, $ap_val);
}


sub ap_tune {

    &dispatcher::log(1, "-- SUB ap_tune --\n");
    my %param;
    %param=split(/[:;]/,shift);
    # ap_id
    parm_log(\%param); 

    ## SEND FREE AP_ID to SWCTL
    my ($ap_res, $ap_val) = SW_AP_tune (\%param);
    return ($ap_res+0, $ap_val);
}

sub ap_link_state {

    &dispatcher::log(1, "-- SUB ap_set_state --\n");
    my %param;
    %param=split(/[:;]/,shift);
    # ap_id
    parm_log(\%param); 

    ## SEND FREE AP_ID to SWCTL
    my ($ap_res, $ap_val) = SW_AP_linkstate (\%param);
    return ($ap_res+0, $ap_val);
}

sub ap_free {

    &dispatcher::log(1, "-- SUB ap_free --\n");
    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param); 

    ## SEND FREE AP_ID to SWCTL
    my ($ap_res, $ap_val) = SW_AP_free (\%param);
    return ($ap_res+0, $ap_val);

}

sub send_pod  {

    &dispatcher::log(1, "-- SUB send_pod --\n");
    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param); 
    # nas_ip nas_port nas_secret login

    my ( $res, $a, $err, $strerr );
    my 	$res_attr = "attr:";

    $r = new Authen::Radius(Host => $param{'nas_ip'}.":".$param{'nas_port'}, Secret => $param{'nas_secret'}, Debug => 0);
    $r->add_attributes (
      { Name => 'User-Name', Value => $param{'login'} }
      #{ Name => 'Acct-Session-Id', Value => $cmd[4] }
      #{ Name => 'Calling-Station-Id', Value => $cmd[5] }
      #{ Name => 'h323-conf-id', Value =>  $cmd[6]},
      #{ Name => 'Session-Key', Value => $cmd[7] },	
    );

    &dispather::log(1, "send...\n");
    #$r->send_packet(DISCONNECT_REQUEST) and $type = $r->recv_packet();

    $r->send_packet(DISCONNECT_REQUEST);
    &dispather::log(1, "wait res...\n");
    $res = $r->recv_packet();
    &dispather::log(1, "response = $res\n");

    $err = $r->get_error;
    $strerr = $r->strerror;

    &dispather::log(1, "error = $err $strerr\n");

    for $a ($r->get_attributes()) {
	&dispather::log(1, "attr: ".$a->{'Name'}." = ".$a->{'Value'}."\n");
	$res_attr .= ",".$a->{'Name'}."='".$a->{'Value'}."'";
	if($a->{'Name'} eq 'Error-Cause' &&  $a->{'Value'} eq 'Session-Context-Not-Found') {
	    &dispather::log(1, "set res to 41 since Error-Cause = Session-Context-Not-Found\n");
	    $res = 41;
	}
    }
    $res_attr .= ";";

    &dispather::log(1, "res = $res\n");
    return ( $res+0, "strerr:".$strerr.";".$res_attr ) ;
}


sub parm_log {
    my $parm = shift;
    my $str_log = 'receive parms: ';
    while(my ($k,$v)=each(%$parm)) {
	$str_log .= "$k='$v', ";
    }
    $str_log .= "\n";
    &dispatcher::log(1, $str_log );
}