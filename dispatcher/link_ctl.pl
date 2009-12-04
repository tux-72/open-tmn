#!/usr/bin/perl

#use strict;
use Authen::Radius;
use FindBin '$Bin';
require $Bin . '/../conf/libap.pl';
Authen::Radius->load_dictionary();

$VERSION = 0.8;

my $debug = 1;

my $LOGDIR = '/var/log/dispatcher';
my $logfile = $LOGDIR.'/dispatcher_subs.log';


my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
print STDERR  "Use BIN directory - $Bin\n" if $debug > 1;

sub startup {
    &dispatcher::log(1, "startup\n");
}

sub ap_check {
    #&dispatcher::log(1, "-- SUB ap_check --\n");

    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param, 'ap_check'); 
 
    ## GET AP_ID from SWCTL
    my ($ap_res, $ap_val) = SW_AP_get (\%param);
    return ($ap_res+0, $ap_val);
}


sub ap_tune {

    #&dispatcher::log(1, "-- SUB ap_tune --\n");
    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param, 'ap_tune'); 

    ## SEND FREE AP_ID to SWCTL
    my ($ap_res, $ap_val) = SW_AP_tune (\%param);
    return ($ap_res+0, $ap_val);
}

sub ap_link_state {

    #&dispatcher::log(1, "-- SUB ap_set_state --\n");
    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param, 'ap_link_state'); 

    ## SEND FREE AP_ID to SWCTL
    my ($ap_res, $ap_val) = SW_AP_linkstate (\%param);
    return ($ap_res+0, $ap_val);
}

sub ap_free {

    #&dispatcher::log(1, "-- SUB ap_free --\n");
    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param, 'ap_free'); 

    ## SEND FREE AP_ID to SWCTL
    my ($ap_res, $ap_val) = SW_AP_free (\%param);
    return ($ap_res+0, $ap_val);

}

sub send_pod  {

    #&dispatcher::log(1, "-- SUB send_pod --\n");
    dlog ( SUB => 'send_pod', DBUG => 1, MESS => "-- SUB send_pod --" );
    my %param;
    %param=split(/[:;]/,shift);
    parm_log(\%param, 'send_pod'); 
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

    #&dispather::log(1, "send...\n");
    dlog ( SUB => 'send_pod', DBUG => 2, MESS => "send..." );
    #$r->send_packet(DISCONNECT_REQUEST) and $type = $r->recv_packet();

    $r->send_packet(DISCONNECT_REQUEST);
    #&dispather::log(1, "wait res...\n");
    dlog ( SUB => 'send_pod', DBUG => 2, MESS => "wait res..." );
    $res = $r->recv_packet();
    #&dispather::log(1, "response = $res\n");
    dlog ( SUB => 'send_pod', DBUG => 2, MESS => "response = $res..." );

    $err = $r->get_error;
    $strerr = $r->strerror;

    #&dispather::log(1, "error = $err $strerr\n");
    dlog ( SUB => 'send_pod', DBUG => 2, MESS => "error = $err $strerr" );

    for $a ($r->get_attributes()) {
	#&dispather::log(1, "attr: ".$a->{'Name'}." = ".$a->{'Value'}."\n");
	dlog ( SUB => 'send_pod', DBUG => 2, MESS => "attr: ".$a->{'Name'}." = ".$a->{'Value'} );
	$res_attr .= ",".$a->{'Name'}."='".$a->{'Value'}."'";
	if($a->{'Name'} eq 'Error-Cause' &&  $a->{'Value'} eq 'Session-Context-Not-Found') {
	    #&dispather::log(1, "set res to 41 since Error-Cause = Session-Context-Not-Found\n");
	    dlog ( SUB => 'send_pod', DBUG => 2, MESS => "set res to 41 since Error-Cause = Session-Context-Not-Found" );
	    $res = 41;
	}
    }
    $res_attr .= ";";

    #&dispather::log(1, "res = $res\n");
    dlog ( SUB => 'send_pod', DBUG => 2, MESS => "res = $res" );
    return ( $res+0, "strerr:".$strerr.";".$res_attr ) ;
}



sub dlog {
        my %arg = (
            @_,
        );
        if ( not $arg{'DBUG'} > $debug ) {
            open(LOG,">>$logfile");
            my $subchar = 22; my @lines = ();
            my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];
            my $timelog = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $month + 1, $day, $hour, $min, $sec);
            if ( ref($arg{'MESS'}) ne 'ARRAY' ) {
                @lines = split /\n/,$arg{'MESS'};
            } else {
                @lines = @{$arg{'MESS'}};
            }
            foreach my $mess ( @lines ) {
                next if (not $mess =~ /\S+/);
                print LOG $timelog." ".rspaced("'".$arg{'SUB'}."'",$subchar).": ".$mess."\n";
            }
            close LOG;
        }
}

sub rspaced {
    $str = shift;
    $len = shift;
    return sprintf("%-${len}s",$str);
}

sub parm_log {
    my $parm = shift;
    my $subs = shift;
    my $str_log = 'receive parms: ';
    while(my ($k,$v)=each(%$parm)) {
	$str_log .= " $k='$v',";
    }
    dlog ( SUB => $subs, DBUG => 1, MESS => $str_log );
    #$str_log .= "\n";
    #&dispatcher::log(1, $str_log );
}
