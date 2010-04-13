#!/usr/bin/perl

package DESCtl;

use strict;
no strict qw(refs);

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.17;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw(	DES_pass_change DES_conf_first	DES_conf_save	DES_fix_macport
		DES_port_up	DES_port_down	DES_port_defect	DES_port_free	DES_port_setparms
		DES_port_portchannel    DES_port_trunk	DES_port_system
		DES_vlan_trunk_add	DES_vlan_trunk_remove	DES_vlan_remove
	    );

my $debug=1;
my $timeout=15;
my $timeout_login=5;

my $LIB='DES';
my $command	= $LIB."_cmd";
my $login	= $LIB."_login";
my $speed_char	= $LIB."_speed_char";
my $bw_char	= $LIB."_bw_char";
my $hw_char	= $LIB."_hw_char";
my $vlan_char	= $LIB."_vlan_char";

my $port_remove_vlans	= $LIB."_port_remove_vlans";
my $port_set_vlan	= $LIB."_port_set_vlan";
my $set_segmentation	= $LIB."_set_segmentation";
#my $block_vlan		= 4094;

my $prompt='/.*#.*/';

# percent supression multicast and broadcast
#my $trunk_ctl_mcast     = 1;    my $trunk_ctl_bcast     = 10;
my $port_ctl_mcast      = 1;    my $port_ctl_bcast      = 2;

############ SUBS ##############

sub DES_conf_save {

#   IP LOGIN PASS 
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    #print STDERR "SAVE $LIB config in switch ".$arg->{'IP'}." ...\n";
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "SAVE config on $LIB switch ".$arg->{'IP'}." ..." );
    return -1  if (&$command(\$sw, $prompt, "save" ) < 1 );
    $sw->close();
    return 1;
}

sub DES_cmd {
    my ($swl, $cmd_prompt, $cmd ) = @_;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => ${$swl}->last_prompt(), MESS => $cmd );
    my @lines = ${$swl}->cmd(   String  => $cmd,
                                Prompt  => $cmd_prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => ${$swl}->last_prompt(), NORMA => 1,  MESS => \@lines );
    return 1;
}



sub DES_set_segmentation {

    my ($swl, $port, $fwd_ports ) = @_;
    my $sw = ${$swl};
    my $ranges_vlan = ''; my @range = '';
    ## VLAN CONFIGURE
    my @ln = $sw->cmd("show vlan\na");
    $sw->cmd("");  ## ������� ��������� ������ �� �������� 'a' ���� VLAN ������ ��������

    foreach (@ln) {
        # VID             : 14         VLAN Name       : Office-14
        if ( /Member\s+ports\s+:\s+(\S+)/ ) {
            $ranges_vlan = $1;
            $ranges_vlan =~ s/\n//;
            @range = split /\,/,$ranges_vlan;
            foreach my $c ( @range ) {
                if ("x".$port eq "x".$c ) {
		    $fwd_ports .= ",".$ranges_vlan;
                } else {
                    my @d = split /-/,$c;
                    for my $e ($d[0]..$d[1]) {
                        if ($port == $e) {
			    $fwd_ports .= ",".$ranges_vlan;
                        }
                    }
                }
            }
        }
    }
    if ( $fwd_ports ne '' ) {
	SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Normalize traffic_segmentation in ".$port." to ".$fwd_ports );
	#return -1  if (&$command(\$sw, $prompt, "config traffic_segmentation ".$port." forward_list ".$fwd_ports ) < 1 );
    }
    return 1;
}

sub DES_port_set_vlan {
    my ($swl, $port, $vlan_id, $tag, $trunk ) = @_;
    my $sw = ${$swl};
    my $tagging='untagged ';
    $tagging = 'tagged ' if $tag > 0;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "PARMS - ' $port, $vlan_id '" );
    my $vln = ''; my $vln_num = 0; my $vlanname = ''; 
    my $ranges_vlan = ''; my @range = '';

    my @ln = $sw->cmd( String  => "show vlan\na",
                                #Prompt  => $prompt,
                                Timeout => 30,
                                #Errmode => 'return',
                                #Cmd_remove_mode => 1,
                            );
    $sw->cmd("");  ## ������� ��������� ������ �� �������� 'a' ���� VLAN ������ ��������

    foreach (@ln) {
	# VID             : 998        VLAN Name       : ES-TEST
        if ( /VID\s+\:\s+(\d+)\s+VLAN\s+Name\s+\:\s+(\S+)/ ) {
	    $vln = $2;
	    $vln_num = $1;
	    $vlanname = $2 if $1 == $vlan_id;
	#	 Member ports    : 5,7-8,23-26
        } elsif ( ! $trunk and /Member\s+ports\s+:\s+(\S+)/ and "x".$vln_num ne "x".$vlan_id ) {
	    $ranges_vlan = $1;
	    $ranges_vlan =~ s/\n//;
	    @range = split /\,/,$ranges_vlan;
	    foreach my $c ( @range ) {
		if ("x".$port eq "x".$c) {
		    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Remove port ".$c." from vlan ".$vln_num );
		    return -1  if (&$command(\$sw, $prompt, "config vlan ".$vln." delete ".$port ) < 1 );
		} else {
		    my @d = split /-/,$c;
		    if (defined($d[1])) {
			for my $e ($d[0]..$d[1]) {
			    if ($port == $e) {
				SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Remove port ".$e." in portrange - ".$c." from vlan ".$vln_num );
				return -1  if (&$command(\$sw, $prompt, "config vlan ".$vln." delete ".$port ) < 1 );
			    }
			}
		    }
		}
	    } 
	} 
    }
    if ("x".$vlanname eq "x" ) {
	$vlanname = "Vlan".$vlan_id;
	SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Create VLAN ".$vlanname );
	return -1  if (&$command(\$sw, $prompt, "create vlan ".$vlanname." tag ".$vlan_id ) < 1 );
    }
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Use vlan name '".$vlanname."'" );
    return -1  if (&$command(\$sw, $prompt, "config vlan ".$vlanname." add ".$tagging." ".$port ) < 1 );

    return 1;
}

sub DES_vlan_char {
    my ($swl, $vlan_id1) = @_;
    my $v_name = '';

    ## VLAN CONFIGURE
    my @ln = ${$swl}->cmd("show vlan\na");
     ${$swl}->cmd("");  ## ������� ��������� ������ �� �������� 'a' ���� VLAN ������ ��������
    foreach (@ln) {
        # VID             : 14         VLAN Name       : Office-14
        if ( /VID\s+\:\s+(\d+)\s+VLAN\s+Name\s+\:\s+(\S+)/ ) {
    	    $v_name = $2 if ("x".$1 eq "x".$vlan_id1);
	}
    }
    undef @ln;
    return $v_name;
}

sub DES_speed_char {
    my $arg = shift;
    my @duplex = ''; $duplex[0] = 'half'; $duplex[1] = 'full';
    my $spd = 'auto';
    if ( defined($arg->{'SPEED'}) and  $arg->{'SPEED'} =~ /^1(0|00|000)$/ and $arg->{'DUPLEX'} =~ /(0|1)/ and not $arg->{'AUTONEG'} ) { 
	$spd = $arg->{'SPEED'}."_".$duplex[$arg->{'DUPLEX'}];
    }
    return $spd;
}

sub DES_bw_char {
    my $arg = shift;
    my $dsl = ( $arg->{'DS'} < 0 || $arg->{'DS'} > 99999 ? "no_limit" : "$arg->{'DS'}" );
    my $usl = ( $arg->{'US'} < 0 || $arg->{'US'} > 99999 ? "no_limit" : "$arg->{'US'}" );
    return ( $dsl, $usl );
}

sub DES_hw_char {
    my $arg = shift;
    my $maxhw =     ( ( defined($arg->{'MAXHW'}) and $arg->{'MAXHW'} > 0 and $arg->{'MAXHW'} < 10 ) ? $arg->{'MAXHW'} : 10 );
    my $adm_state = ( ( defined($arg->{'MAXHW'}) and $arg->{'MAXHW'} > 0 and $arg->{'MAXHW'} < 10 ) ? "enable" : "disable" );
    return ( $maxhw, $adm_state );
}

sub DES_login {
    my ($swl, $ip, $login, $pass) = @_;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "IP = ".$ip.", PASS = ".$pass );
    ${$swl}=new Net::Telnet (   prompt => $prompt,
                                Timeout => $timeout_login,
                                Errmode => 'return',
                            );
    ${$swl}->open($ip);
    ${$swl}->login($login,$pass) || return -1;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Connect to switch - Ok" );
    return 1;
}

sub DES_conf_first {
#    IP LOGIN PASS UPLINKPORT UPLINKPORTPREF LASTPORT VLAN VLANNAME BWFREE MONLOGIN MONPASS COM_RO COM_RW 
    my $arg = shift;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "First config new switch - '".$arg->{'IP'}."'" );
    my $vlan = 0;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

######## ALL SWITCH conf
    if ($arg->{'LASTPORT'} > 26 ) {
	$sw->print("reset");
	$sw->waitfor("/.*log and user account.*/");
	return -1  if (&$command(\$sw, $prompt,    "y") < 1 );
	sleep(10);
	SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Config resetting successfull!" );

    } else {
	return -1  if (&$command(\$sw, $prompt,    "reset force_agree") < 1 );
    }

    if ($arg->{'IP'} =~ /^192\.168\.128\./) {
	return -1  if (&$command(\$sw, $prompt,	"create iproute default 192.168.128.254") < 1 );
    } elsif ($arg->{'IP'} =~ /^172\.20\./) {
	return -1  if (&$command(\$sw, $prompt,	"create iproute default 172.20.20.254") < 1 );
    }
    return -1  if (&$command(\$sw, $prompt,    "disable web") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "delete snmp community private") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "delete snmp community public") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "create snmp community ".$arg->{'COM_RO'}." view CommunityView read_only") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "create snmp community ".$arg->{'COM_RW'}." view CommunityView read_write") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "create snmp host 172.20.20.10 v2c ".$arg->{'COM_RO'}) < 1 );
    return -1  if (&$command(\$sw, $prompt,    "enable sntp") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config time_zone operator + hour 5 min 0") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config sntp primary 172.20.20.254 secondary 192.168.128.254 poll-interval 720") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config dst repeating s_week last s_day sun s_mth 3 s_time 3:0 e_week last e_day sun e_mth 10 e_time 2:0 offset 60") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "disable mac_notification") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config mac_notification ports 1-".$arg->{'LASTPORT'}." disable") < 1 );

    ######## Custom SWITCH conf
    return -1  if (&$command(\$sw, $prompt,    "config port_security ports ".$arg->{'UPLINKPORT'}." admin_state disable") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config ports ".$arg->{'UPLINKPORT'}." flow_control disable speed auto") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config bandwidth_control ".$arg->{'UPLINKPORT'}." rx_rate no_limit tx_rate no_limit") < 1 );
    if ($arg->{'LASTPORT'} > 26 ) {
	return -1  if (&$command(\$sw, $prompt,    "config traffic control 1-".$arg->{'LASTPORT'}." broadcast enable multicast enable action drop threshold 128 countdown 0 time_interval 5") < 1 );
    } else {
	return -1  if (&$command(\$sw, $prompt,    "config traffic control 1-".$arg->{'LASTPORT'}." broadcast enable multicast enable unicast enable action drop threshold 128 countdown 0 time_interval 5") < 1 );
	return -1  if (&$command(\$sw, $prompt,    "enable loopdetect") < 1 );
	return -1  if (&$command(\$sw, $prompt,    "config loopdetect ports 1-".$arg->{'LASTPORT'}." state enable") < 1 );
    }
    return -1  if (&$command(\$sw, $prompt,    "config port_security ports 1-".$arg->{'LASTPORT'}." admin_state enable max_learning_addr 5 lock_address_mode DeleteOnTimeout") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config ports 1-".$arg->{'LASTPORT'}." flow_control enable") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config ports 1-".$arg->{'LASTPORT'}." state enable") < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config vlan default delete 1-".$arg->{'LASTPORT'}) < 1 );
    return -1  if (&$command(\$sw, $prompt,    "create vlan ".$arg->{'VLANNAME'}." tag ".$arg->{'VLAN'}) < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config vlan ".$arg->{'VLANNAME'}." add tagged ".$arg->{'UPLINKPORT'}) < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config vlan ".$arg->{'VLANNAME'}." add untagged 1-".$arg->{'LASTPORT'}) < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config bandwidth_control 1-".$arg->{'LASTPORT'}." rx_rate ".$arg->{'BWFREE'}." tx_rate ".$arg->{'BWFREE'}) < 1 );
    return -1  if (&$command(\$sw, $prompt,    "config traffic_segmentation 1-".$arg->{'LASTPORT'}." forward_list ".$arg->{'UPLINKPORT'}) < 1 );

    ####### REMOVE OLD Accounts
    if ($arg->{'LASTPORT'} > 26 ) {
	return -1  if (&$command(\$sw, $prompt, "delete account ".$arg->{'MONLOGIN'} ) < 1 );
	$sw->print("delete account ".$arg->{'LOGIN'});
	$sw->waitfor("/.*Are you sure to delete the last administrator account.*/");
	$sw->print("y");
    }

    ####### ADD ADMIN LOGIN
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Create login ".$arg->{'LOGIN'} );
    $sw->print("create account admin $arg->{'LOGIN'}");
    $sw->waitfor("/.* new password.*/");
    $sw->print("$arg->{'PASS'}");
    $sw->waitfor("/.* for confirmation.*/");
    return -1  if (&$command(\$sw, $prompt, $arg->{'PASS'} ) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Login ".$arg->{'LOGIN'}." created successfull!" );

    ####### ADD Monitoring LOGIN
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Create login ".$arg->{'MONLOGIN'} );
    $sw->print("create account admin $arg->{'MONLOGIN'}");
    $sw->waitfor("/.* new password.*/");
    $sw->print("$arg->{'MONPASS'}");
    $sw->waitfor("/.* for confirmation.*/");
    return -1  if (&$command(\$sw, $prompt, $arg->{'MONPASS'} ) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Login ".$arg->{'MONLOGIN'}." created successfull!" );

    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Save config ..." );
    return -1  if (&$command(\$sw, $prompt, "save" ) < 1 );
    $sw->close();
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Switch '".$arg->{'IP'}."' is configured successfull!" );
    return 1;
}


sub DES_pass_change {
#    IP LOGIN PASS ADMINLOGIN ADMINPASS MONLOGIN MONPASS
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Change ACCOUNTS in switch '".$arg->{'IP'}."'" );

    ####### ADD ADMIN LOGIN
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Create login ".$arg->{'ADMINLOGIN'} );
    return -1  if (&$command(\$sw, $prompt, "delete account ".$arg->{'LOGIN'} ) < 1 );
    $sw->print("create account admin ".$arg->{'ADMINLOGIN'});
    $sw->waitfor("/.* new password.*/");
    $sw->print($arg->{'ADMINPASS'});
    $sw->waitfor("/.* for confirmation.*/");
    return -1  if (&$command(\$sw, $prompt, $arg->{'ADMINPASS'} ) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Login ".$arg->{'ADMINLOGIN'}." created successfull!" );

    ####### ADD Monitoring LOGIN
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Create login ".$arg->{'MONLOGIN'} );
    $sw->print("create account admin ".$arg->{'MONLOGIN'});
    $sw->waitfor("/.* new password.*/");
    $sw->print($arg->{'MONPASS'});
    $sw->waitfor("/.* for confirmation.*/");
    return -1  if (&$command(\$sw, $prompt, $arg->{'MONPASS'} ) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Login ".$arg->{'MONLOGIN'}." created successfull!" );

    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Save config ..." );
    return -1  if (&$command(\$sw, $prompt, "save" ) < 1 );
    $sw->close();
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Change password accounts complete!" );
    return 1;
}

sub DES_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my $arg = shift;
    # login
    use Data::Dumper;
    #print Dumper $arg->{'IP'}, $arg->{'MAC'} ;
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "FIX PORT in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}.", VLAN '".$arg->{'VLAN'}."'" );

    my $port = -1; my $pref; my $max=3; my $count=0; 
    while ($count < $max) {
    my @ln= $sw->cmd("show fdb mac_address ".$arg->{'MAC'}."\n");
        foreach (@ln) {
            #541   30LetPobedy_146_1_2  00-19-DB-B3-A6-C3   11    DeleteOnTimeout
            if ( /(\d+)\s+\S+\s+(\w\w\-\w\w\-\w\w\-\w\w\-\w\w\-\w\w)\s+(\d+)\s+\S+/ and $1 == $arg->{'VLAN'} ) {
                $port = $3;
            }
        }
        if ($port>0) {
            last;
        } else {
            $count+=1;
        }
    }
    $sw->close();
    return ($pref,$port);
}


sub DES_port_up {

#    IP LOGIN PASS PORT PORTPREF
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set port UP in ".$arg->{'IP'}.", port ".( defined($arg->{'PORTPREF'}) ? $arg->{'PORTPREF'} : '' ).$arg->{'PORT'}  );
    return -1  if (&$command(\$sw, $prompt, "config ports ".$arg->{'PORT'}." state enable" ) < 1 );
    $sw->close();
    return 1;
}

sub DES_port_down {

#    IP LOGIN PASS PORT PORTPREF
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set port DOWN in ".$arg->{'IP'}.", port ".( defined($arg->{'PORTPREF'}) ? $arg->{'PORTPREF'} : '' ).$arg->{'PORT'}  );
    return -1  if (&$command(\$sw, $prompt, "config ports ".$arg->{'PORT'}." state disable" ) < 1 );
    $sw->close();
    return 1;

}

sub DES_port_defect {
#    IP LOGIN PASS PORT PORTPREF VLAN
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set DEFECT port in ".$arg->{'IP'}.", port ".( defined($arg->{'PORTPREF'}) ? $arg->{'PORTPREF'} : '' ).$arg->{'PORT'}  );

    return -1  if (&$command(\$sw, $prompt, "config ports ".$arg->{'PORT'}." state disable flow_control disable speed auto" ) < 1 );
    return -1  if (&$command(\$sw, $prompt, "config bandwidth_control ".$arg->{'PORT'}." rx_rate no_limit tx_rate no_limit" ) < 1 );
    &$port_set_vlan( \$sw, $arg->{'PORT'}, $arg->{'BLOCK_VLAN'}, 0, 0 ) if ($arg->{'VLAN'} > 0);

    $sw->close();
    return 1;
}

sub DES_port_free {

    # IP LOGIN PASS PORT DS US VLAN
    my $arg = shift;
    return -1 if (not $arg->{'VLAN'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set FREE port in ".$arg->{'IP'}.", port ".( defined($arg->{'PORTPREF'}) ? $arg->{'PORTPREF'} : '' ).$arg->{'PORT'}  );
    my ( $ds, $us ) = &$bw_char( $arg );

    return -1  if (&$command(\$sw, $prompt, "config ports ".$arg->{'PORT'}." state enable flow_control enable speed auto" ) < 1 );
    return -1  if (&$command(\$sw, $prompt, "config bandwidth_control ".$arg->{'PORT'}." rx_rate ".$us." tx_rate ".$ds ) < 1 );
    return -1  if (&$command(\$sw, $prompt, "config port_security ports ".$arg->{'PORT'}.
    " admin_state enable max_learning_addr 5 lock_address_mode DeleteOnTimeout" ) < 1 );
    &$port_set_vlan( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, 0, 0 ) if ($arg->{'VLAN'} > 0);

    #return -1  if (&$command(\$sw, $prompt, "config traffic_segmentation ".$arg->{'PORT'}." forward_list ".$arg->{'UPLINKPORT'} ) < 1 );
    $sw->close();
    return 1;
}


sub DES_port_trunk {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set TRUNK port in ".$arg->{'IP'}.", port ".( defined($arg->{'PORTPREF'}) ? $arg->{'PORTPREF'} : '' ).$arg->{'PORT'}  );

    my $speed = &$speed_char( $arg );

    return -1  if (&$command(\$sw, $prompt, "config port_security ports ".$arg->{'PORT'}." admin_state disable" ) < 1 );
    return -1  if (&$command(\$sw, $prompt, "config ports ".$arg->{'PORT'}." state enable flow_control disable speed ".$speed ) < 1 );
    return -1  if (&$command(\$sw, $prompt, "config bandwidth_control ".$arg->{'PORT'}." rx_rate no_limit tx_rate no_limit" ) < 1 );
    #if $arg->{'VLAN'}
    #my $tagging='untagged ';
    #$tagging = 'tagged ' if $tag > 0;
    #return -1  if (&$command(\$sw, $prompt, "config vlan default add untagged ".$arg->{'PORT'} ) < 1 );
    &$port_set_vlan( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, $arg->{'TAG'}, 1 ) if ($arg->{'VLAN'} > 0);
    $sw->close();
    return 1;
}

sub DES_port_system {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set SYSTEM port in ".$arg->{'IP'}.", port ".( defined($arg->{'PORTPREF'}) ? $arg->{'PORTPREF'} : '' ).$arg->{'PORT'}  );
    my $speed = &$speed_char( $arg );
    my ( $ds, $us ) = &$bw_char( $arg );

    return -1  if (&$command(\$sw, $prompt, "config ports ".$arg->{'PORT'}." state enable flow_control  enable speed ".$speed) < 1 );
    return -1  if (&$command(\$sw, $prompt, "config bandwidth_control ".$arg->{'PORT'}." rx_rate ".$us." tx_rate ".$ds ) < 1 );
    return -1  if (&$command(\$sw, $prompt, "config port_security ports ".$arg->{'PORT'}." admin_state disable" ) < 1 );
    &$port_set_vlan( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, $arg->{'TAG'}, 0 ) if ($arg->{'VLAN'} > 0);

    $sw->close();
    return 1;
}

sub DES_port_setparms {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX UPLINKPORT
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SET PARAMETERS port in ".$arg->{'IP'}.", port ".( defined($arg->{'PORTPREF'}) ? $arg->{'PORTPREF'}: '' ).$arg->{'PORT'}  );

    my $speed = &$speed_char( $arg );
    my ( $ds, $us ) = &$bw_char( $arg );
    my ( $maxhw, $adm_state ) = &$hw_char( $arg);

    return -1  if (&$command(\$sw, $prompt, "config ports ".$arg->{'PORT'}." state enable flow_control  enable speed ".$speed) < 1 );
    return -1  if (&$command(\$sw, $prompt, "config bandwidth_control ".$arg->{'PORT'}." rx_rate ".$us." tx_rate ".$ds ) < 1 );
    return -1  if (&$command(\$sw, $prompt, "config port_security ports ".$arg->{'PORT'}." admin_state ".$adm_state.
    " max_learning_addr ".$maxhw." lock_address_mode DeleteOnTimeout" ) < 1 );

    &$port_set_vlan( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, $arg->{'TAG'}, 0 ) if ($arg->{'VLAN'} > 0);
    #return -1  if (&$command(\$sw, $prompt, "config traffic_segmentation ".$arg->{'PORT'}." forward_list ".$arg->{'UPLINKPORT'} ) < 1 );
    $sw->close();
    return 1;
}

sub DES_vlan_trunk_add  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "ADD VLAN ".$arg->{'VLAN'}." to trunk port ".$arg->{'PORT'} );
    my $vlanname = &$vlan_char( \$sw, $arg->{'VLAN'} );
    if ( $vlanname eq '' ) {
	$vlanname = "Vlan_".$arg->{'VLAN'};
	return -1  if (&$command(\$sw, $prompt, "create vlan ".$vlanname." tag ".$arg->{'VLAN'} ) < 1 );
    }
    return -1  if ( &$command(\$sw, $prompt, "config vlan ".$vlanname." add tag ".$arg->{'PORT'} ) < 1 );
    #return -1  if ( &$set_segmentation (\$sw, $arg->{'PORT'}, $arg->{'UPLINKPORT'} ) < 1 );
    
    $sw->close();
    return 1;
}


sub DES_vlan_trunk_remove  {

#    IP LOGIN PASS VLAN PORT PORTPREF
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN ".$arg->{'VLAN'}." from trunk port ".$arg->{'PORT'} );
    my $vlanname = &$vlan_char( \$sw, $arg->{'VLAN'} );
    if ( $vlanname ne '' ) {
	return -1  if (&$command(\$sw, $prompt, "config vlan ".$vlanname." delete ".$arg->{'PORT'} ) < 1 );
    }
    $sw->close();
    return 1;
}

sub DES_vlan_remove  {
#    IP LOGIN PASS VLAN
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN ".$arg->{'VLAN'}." from switch ".$arg->{'IP'} );
    my $vlanname = &$vlan_char( \$sw, $arg->{'VLAN'} );
    if ( $vlanname ne '' ) {
	return -1  if (&$command(\$sw, $prompt, "delete vlan ".$vlanname ) < 1 );
    }
    $sw->close();
    return 1;
}

1;
