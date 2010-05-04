#!/usr/bin/perl

package CATIOSCtl;

use strict;
no strict qw(refs);

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.3;
@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw(	CATIOS_pass_change CATIOS_conf_first	CATIOS_conf_save	CATIOS_fix_macport	CATIOS_fix_vlan
		CATIOS_port_up	CATIOS_port_down	CATIOS_port_defect	CATIOS_port_free	CATIOS_port_setparms
		CATIOS_port_trunk	CATIOS_port_system
		CATIOS_vlan_trunk_add	CATIOS_vlan_trunk_remove	CATIOS_vlan_remove
		CATIOS_term_l3subnet_add CATIOS_term_l3subnet_remove CATIOS_term_l3subnet_down CATIOS_term_l3subnet_up
		CATIOS_term_l3realnet_add CATIOS_term_l3realnet_remove CATIOS_term_l3realnet_down CATIOS_term_l3realnet_up
	    );

my $debug=1;
my $timeout=3;

my $LIB='CATIOS';
my $command     = $LIB."_cmd";
my $login       = $LIB."_login";
my $speed_char  = $LIB."_speed_char";

#my $block_vlan=4094;

my $prompt='/.*[\>#].*/';
my $prompt_conf ='/.*\(config\)#.*/';
my $prompt_conf_if ='/.*\(config\-if\)#.*/';
my $prompt_conf_vlan ='/.*\(config\-vlan\)#.*/';

# percent supression multicast and broadcast
my $trunk_ctl_mcast     = 1;    my $trunk_ctl_bcast     = 10;
my $port_ctl_mcast      = 1;    my $port_ctl_bcast      = 2;

############ SUBS ##############

sub CATIOS_conf_first {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "$LIB Switch '$arg->{'IP'}' first configured MANUALLY!!!" ) ;
    return -1;
}


sub CATIOS_pass_change {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "$LIB Switch '$arg->{'IP'}' changed password MANUALLY!!!" );
    return -1;
}

sub CATIOS_login {
    my ($swl, $ip, $login, $pass) = @_;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => " IP = ".$ip.", LOGIN = ".$login.", PASS = ".$pass );
    ${$swl}=new Net::Telnet (   prompt => $prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    ${$swl}->open($ip);
    ${$swl}->print("");
    ${$swl}->login($login,$pass) || return -1;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Login - Ok");
    return 1;
}

sub CATIOS_cmd {
    my ($swl, $cmd_prompt, $cmd ) = @_;

    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => ${$swl}->last_prompt(), MESS => $cmd );
    my @lines = ${$swl}->cmd(   String  => $cmd,
                                Prompt  => $cmd_prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => ${$swl}->last_prompt(), MESS => \@lines );
    return 1;
}


sub CATIOS_mac_fix {
        my $mac = shift;
        $mac =~ /^(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)$/ || return -1 ;
        return "$1$2\.$3$4\.$5$6";
}


sub CATIOS_fix_vlan {

    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # IP LOGIN PASS MAC RSH
    $arg->{'RSH'} = 0;
     SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing VLAN in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}."' ..." );
    my $vlan = 0; my @ln = ''; 	my $sw; 

    if ( $arg->{'RSH'} ) {
        @ln = IOS_rsh( PID => $$, HOST => $arg->{'IP'}, REMOTE_USER => $arg->{'LOGIN'}, CMD => "show mac-address-table dynamic address ".$arg->{'MAC'} );
    } else {
	# login
	return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
	@ln= $sw->cmd("show mac-address-table dynamic address ".$arg->{'MAC'}) if ( not $arg->{'RSH'} );
	$sw->close();
    }
    foreach (@ln) {
	#vlan   mac address     type        protocols               port
	#-------+---------------+--------+---------------------+--------------------
	#464    001f.c66e.2bf4   dynamic ip                    FastEthernet6/30
        if ( /(\d+)\s+\w\w\w\w\.\w\w\w\w\.\w\w\w\w\s+dynamic\s+\S+\s+\S+/ and $1 > 99 ) {
            $vlan = $1;
        }
    }
    return $vlan;
}

sub CATIOS_fix_macport {
    # IP LOGIN PASS MAC VLAN RSH
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    $arg->{'RSH'} = 0;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing PORT in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}."', VLAN '".$arg->{'VLAN'}."' ..." );

    my $mac=CATIOS_mac_fix($arg->{'MAC'});
    my $port = -1; my $pref; my $max=3; my $count=0; my @ln = ''; my $sw;


    while ($count < $max) {
	if ( $arg->{'RSH'} ) {
	    @ln = IOS_rsh( PID => $$, HOST => $arg->{'IP'}, REMOTE_USER => $arg->{'LOGIN'}, CMD => "show mac-address-table dynamic address ".$mac." vlan ".$arg->{'VLAN'} );
	    #@ln = rsh( $arg->{'IP'}, "show mac-address-table dynamic address ".$mac." vlan ".$arg->{'VLAN'}.' | inc dynamic'  );
	} else {
	    # login
	    return -1 if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
	    @ln = $sw->cmd("show mac-address-table dynamic address ".$mac." vlan ".$arg->{'VLAN'} );
	    $sw->close();
	}
        foreach (@ln) {
		    #vlan   mac address     type        protocols               port
		    #-------+---------------+--------+---------------------+--------------------
		    #464    001f.c66e.2bf4   dynamic ip                    FastEthernet6/30
		    #*    1  001b.1105.3d8e   dynamic  Yes          5   Fa4/46
		    #     1  001e.589f.0c61   dynamic  Yes   Gi3/16
            if      ( /(\d+)\s+(\w\w\w\w\.\w\w\w\w\.\w\w\w\w)\s+dynamic\s+.*\s+(Fa|Gi)(\D+|.*)(\d+\/)(\d+)/ ) {
		$port = $6+0;
		$pref = "$3$5";
		    # *   1  001b.1105.3d8e   dynamic  Yes          5   Po1
		    #     1  0013.4991.f9a5   dynamic  Yes   Po1
            } elsif ( /(\d+)\s+(\w\w\w\w\.\w\w\w\w\.\w\w\w\w)\s+dynamic\s+.*\s+(Po|Lo)(\D+|.*)(\d+)/ ) {
		$port = $5+0;
		$pref = "$3";
	    }
	}
	if ($port>0) {
	    last;
	} else {
	    $count+=1;
	}
    }
    return ($pref, $port);
}

sub CATIOS_fix_vlan_old {

    # IP LOGIN PASS MAC
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing VLAN in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}."' ..." );
    my $vlan = 0;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    my @ln= $sw->cmd("show mac-address-table dynamic address ".$arg->{'MAC'});
        foreach (@ln) {
	    #vlan   mac address     type        protocols               port
	    #-------+---------------+--------+---------------------+--------------------
	    #464    001f.c66e.2bf4   dynamic ip                    FastEthernet6/30
        if ( /(\d+)\s+\w\w\w\w\.\w\w\w\w\.\w\w\w\w\s+dynamic\s+\S+\s+\S+/ and $1 > 1 ) {
            $vlan = $1;
        }
    }
    $sw->close();
    return $vlan;
}

sub CATIOS_fix_macport_old {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # IP LOGIN PASS MAC VLAN
    # login
    my $sw; return -1 if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing PORT in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}."', VLAN '".$arg->{'VLAN'}."' ..." );

    my $mac=CATIOS_mac_fix($arg->{'MAC'});
    my $port = -1; my $pref; my $max=3; my $count=0;

    while ($count < $max) {
    my @ln= $sw->cmd("show mac-address-table dynamic address ".$mac." vlan ".$arg->{'VLAN'});
        foreach (@ln) {
		    #vlan   mac address     type        protocols               port
		    #-------+---------------+--------+---------------------+--------------------
		    #464    001f.c66e.2bf4   dynamic ip                    FastEthernet6/30
		    #*    1  001b.1105.3d8e   dynamic  Yes          5   Fa4/46
		    #     1  001e.589f.0c61   dynamic  Yes   Gi3/16
            if      ( /(\d+)\s+(\w\w\w\w\.\w\w\w\w\.\w\w\w\w)\s+dynamic\s+.*\s+(Fa|Gi)(\D+|.*)(\d+\/)(\d+)/ ) {
		$port = $6+0;
		$pref = "$3$5";
		    # *   1  001b.1105.3d8e   dynamic  Yes          5   Po1
		    #     1  0013.4991.f9a5   dynamic  Yes   Po1
            } elsif ( /(\d+)\s+(\w\w\w\w\.\w\w\w\w\.\w\w\w\w)\s+dynamic\s+.*\s+(Po|Lo)(\D+|.*)(\d+)/ ) {
		$port = $5+0;
		$pref = "$3";
	    }
	}
	if ($port>0) {
	    last;
	} else {
	    $count+=1;
	}
    }
    $sw->close();
    return ($pref, $port);
}


sub CATIOS_conf_save {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
#   IP LOGIN PASS
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS =>  "SAVING $LIB config in switch ".$arg->{'IP'}." ..." );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    $sw->print("copy runn startup");
    $sw->waitfor("/\[startup-config\]/");
    return -1  if (&$command(\$sw, $prompt, "" ) < 1 );
    $sw->close();
    return 1;
}

sub CATIOS_port_up {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
#    IP LOGIN PASS PORT PORTPREF
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS =>  "Set port UP in ".$arg->{'IP'}.", port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,        "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,             "exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOS_port_down {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
#    IP LOGIN PASS PORT PORTPREF
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS =>  "Set port DOWN in ".$arg->{'IP'}.", port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,        "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,             "exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOS_port_defect {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
#   IP LOGIN PASS PORT PORTPREF VLAN
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS =>  "Configure DEFECT port in ".$arg->{'IP'}.", port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,        "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "no switchport trunk encapsulation dot1q" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "no switchport trunk allowed vlan" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport mode access" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport access vlan ".$arg->{'BLOCK_VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "description PORT DEFECT!!!" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "speed auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,             "exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOS_port_free {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    #    IP LOGIN PASS PORT PORTPREF DS US VLAN
    return -1 if (not $arg->{'VLAN'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS =>  "Configure FREE port in ".$arg->{'IP'}.", port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,        "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,     "interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "no switchport trunk encapsulation dot1q" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "no switchport trunk allowed vlan" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport mode access" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport access vlan ".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "description FREE PORT!!!" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "storm-control multicast level ".$port_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "storm-control broadcast level ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "speed auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,             "exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOS_speed_char {

    my $arg = shift;
    #my %arg = (
    #    @_,         # список пар аргументов
    #);
    $arg->{'DUPLEX'} += 0;
    my @dpl = ''; $dpl[0] = 'half'; $dpl[1] = 'full';

    my $spd = 'auto';
    if ( $arg->{'SPEED'} && $arg->{'SPEED'} =~ /^1(0|00)$/ && $arg->{'DUPLEX'} && $arg->{'DUPLEX'}=~ /(0|1)/ and not $arg->{'AUTONEG'} ) {
	$spd = $arg->{'SPEED'};
	return ($spd, $dpl[$arg->{'DUPLEX'}]);
    } else {
	return ('auto', 'auto');
    }
}

sub CATIOS_port_trunk {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    #   IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS =>  "Configure TRUNK port in ".$arg->{'IP'}.", port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    my ($speed, $duplex ) = &$speed_char( $arg );

    return -1  if (&$command(\$sw, $prompt_conf,        "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "no switchport access vlan" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk encapsulation dot1q" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport mode trunk" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk allowed vlan add ".$arg->{'VLAN'} ) < 1);
    if ($arg->{'TAG'}) {
#	return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk native vlan ".$arg->{'BLOCK_VLAN'} ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk native vlan ".$arg->{'VLAN'} ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,     "spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "storm-control multicast level ".$trunk_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "storm-control broadcast level ".$trunk_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,             "exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOS_port_system {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS =>  "Configure SYSTEM port in ".$arg->{'IP'}.", port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    my ($speed, $duplex ) = &$speed_char( $arg );
    return -1  if (&$command(\$sw, $prompt_conf,        "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,     "interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    if ($arg->{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_if, "switchport access vlan ".$arg->{'BLOCK_VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if, "switchport trunk encapsulation dot1q" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if, "switchport mode trunk" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if, "switchport trunk allowed vlan add ".$arg->{'VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk native vlan ".$arg->{'BLOCK_VLAN'} ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf_if, "no switchport trunk encapsulation dot1q" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if, "no switchport trunk allowed vlan" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if, "switchport mode access" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if, "switchport access vlan ".$arg->{'VLAN'} ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,     "spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "storm-control multicast level ".$trunk_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "storm-control broadcast level ".$trunk_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,             "exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOS_port_setparms {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS =>  "SET PORT parameters in ".$arg->{'IP'}.", port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    my ($speed, $duplex ) = &$speed_char( $arg );

    return -1  if (&$command(\$sw, $prompt_conf,        "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,     "interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    if ($arg->{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_if, "switchport access vlan ".$arg->{'BLOCK_VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if, "switchport trunk encapsulation dot1q" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if, "switchport mode trunk" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if, "switchport trunk allowed vlan add ".$arg->{'VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk native vlan ".$arg->{'BLOCK_VLAN'} ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf_if, "no switchport trunk encapsulation dot1q" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if, "no switchport trunk allowed vlan" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if, "switchport mode access" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if, "switchport access vlan ".$arg->{'VLAN'} ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,     "spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "storm-control multicast level ".$port_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "storm-control broadcast level ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,             "exit" ) < 1);

    $sw->close();
    return 1;
}


sub CATIOS_vlan_trunk_add  {

    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
#    IP LOGIN PASS VLAN PORT PORTPREF
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "ADD VLAN '".$arg->{'VLAN'}."' in ".$arg->{'IP'}.", trunk port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,        "config term" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,   "state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,     "interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
#    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
#    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk encapsulation dot1q" ) < 1);
#    return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport mode trunk" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk allowed vlan add ".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,             "exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOS_vlan_trunk_remove  {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
#    IP LOGIN PASS VLAN PORT PORTPREF
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN '".$arg->{'VLAN'}."' from ".$arg->{'IP'}.", trunk port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,        "conf t" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,     "interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    #return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk encapsulation dot1q" ) < 1);
    #return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan remove ".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,        "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,             "exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOS_vlan_remove  {

    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
#    IP LOGIN PASS VLAN
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN '".$arg->{'VLAN'}."' from switch ".$arg->{'IP'} );

    return -1  if (&$command(\$sw, $prompt_conf,        "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,        "no vlan ".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,             "exit" ) < 1);
    $sw->close();
    return 1;
}

############################ TERMINATOR FUNCTION
############################ TERMINATE SUBNET IFACES

sub CATIOS_term_l3subnet_add {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # IP LOGIN PASS ENA_PASS VLAN VLANNAME IPGW NETMASK UP_ACLIN UP_ACLOUT
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "ADD VLAN '".$arg->{'VLAN'}."' Subnet Iface to terminator '".$arg->{'IP'} );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,   "interface Vlan".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "description ".$arg->{'VLANNAME'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip address ".$arg->{'IPGW'}." ".$arg->{'NETMASK'} ) < 1);
    if ( defined($arg->{'UP_ACLIN'})  ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'UP_ACLIN'}. " in"  ) < 1); }
    if ( defined($arg->{'UP_ACLOUT'}) ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'UP_ACLOUT'}." out" ) < 1); }
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip redirects" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip unreachables" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip proxy-arp" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip route-cache cef" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}


sub CATIOS_term_l3subnet_remove {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # IP LOGIN PASS ENA_PASS VLAN
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN '".$arg->{'VLAN'}."' Subnet Iface from terminator '".$arg->{'IP'} );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,   "interface Vlan".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip redirects" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip unreachables" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip proxy-arp" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip route-cache" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group in"  ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group out" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip address") < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no encapsulation dot1Q" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no description") < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "no interface Vlan".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOS_term_l3subnet_down {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # IP LOGIN PASS ENA_PASS VLAN DOWN_ACLIN DOWN_ACLOUT
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "BLOCK VLAN '".$arg->{'VLAN'}."' Subnet Iface in terminator '".$arg->{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,   "interface Vlan".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group in"  ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group out" ) < 1);
    if ( defined($arg->{'DOWN_ACLIN'})  ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'DOWN_ACLIN'}. " in"  ) < 1); }
    if ( defined($arg->{'DOWN_ACLOUT'}) ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'DOWN_ACLOUT'}." out" ) < 1); }
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);

    $sw->close();
    return 1;
}


sub CATIOS_term_l3subnet_up {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # IP LOGIN PASS ENA_PASS VLAN UP_ACLIN UP_ACLOUT
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "UNBLOCK VLAN '".$arg->{'VLAN'}."' Subnet Iface in terminator '".$arg->{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,   "interface Vlan".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group in"  ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group out" ) < 1);
    if ( defined($arg->{'UP_ACLIN'})  ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'UP_ACLIN'}. " in"  ) < 1); }
    if ( defined($arg->{'UP_ACLOUT'}) ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'UP_ACLOUT'}." out" ) < 1); }
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}

############################ TERMINATE IP UNNUMBERED IFACES ######################################

sub CATIOS_term_l3realnet_add {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # IP LOGIN PASS ENA_PASS VLAN VLANNAME IPCLI UP_ACLIN UP_ACLOUT LOOP_IF DHCP_HELPER
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "ADD Real IP Unnumbered Iface Vlan'".$arg->{'VLAN'}."' to terminator '".$arg->{'IP'}."'" );

    my $loop_if = ''; my $ifn = -1;

    my @lnvl = $sw->cmd('sh runn | inc interface Loopback');
    foreach (@lnvl) {
        if ( /interface\s+Loopback(\d+)/ ) {
	    $ifn = $1;
            my @ln = $sw->cmd("sh runn int Loopback".$ifn);
	    foreach (@ln) {
		# ip address 192.168.40.1 255.255.255.0
		if ( /ip\s+address\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/ and $1 eq $arg->{'IPGW'} and $2 eq $arg->{'NETMASK'} ) {
		    $loop_if = "Loopback".$ifn;
		    last;
		    #print STDERR "Loopback iface N".$ifn."\n";
		}
	    }
	    if ( "x".$loop_if ne 'x' ) { last; }
        }
    }
    if ( "x".$loop_if eq 'x' ) {
        foreach (@lnvl) {
	    if ( /interface\s+(Loopback\d+)/ and $arg->{'LOOP_IF'} eq $1 ) {
		$loop_if = $arg->{'LOOP_IF'};
	    }
	}
    }

    return -1 if ($loop_if eq '');

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,   "interface Vlan".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "description ".$arg->{'VLANNAME'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip unnumbered ".$loop_if ) < 1);
    if ( defined($arg->{'UP_ACLIN'})  ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'UP_ACLIN'}. " in"  ) < 1); }
    if ( defined($arg->{'UP_ACLOUT'}) ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'UP_ACLOUT'}." out" ) < 1); }
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip redirects" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip unreachables" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip proxy-arp" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip route-cache cef" ) < 1);
    if ( defined($arg->{'DHCP_HELPER'}) and not ( defined($arg->{'STATIC'}) and $arg->{'STATIC'} ) ) {
	return -1  if (&$command(\$sw, $prompt_conf,  "ip dhcp relay information trusted"  ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf,  "ip helper-address ".$arg->{'DHCP_HELPER'} ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    if ( defined($arg->{'STATIC'}) and $arg->{'STATIC'} and defined($arg->{'IPCLI'}) ) { 
	return -1  if (&$command(\$sw, $prompt_conf,  "ip route ".$arg->{'IPCLI'}." 255.255.255.255 Vlan".$arg->{'VLAN'} ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}


sub CATIOS_term_l3realnet_remove {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # IP LOGIN PASS ENA_PASS VLAN IPCLI
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE Real IP Unnumbered Iface Vlan'".$arg->{'VLAN'}."' from terminator '".$arg->{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    if ( defined($arg->{'IPCLI'}) and "x".$arg->{'IPCLI'} ne "x" ) { return -1  if (&$command(\$sw, $prompt_conf,      "no ip route ".$arg->{'IPCLI'}." 255.255.255.255 Vlan".$arg->{'VLAN'} ) < 1) };
    return -1  if (&$command(\$sw, $prompt_conf_if,   "interface Vlan".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip helper-address" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip dhcp relay information trusted" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip redirects" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip unreachables" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip proxy-arp" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "ip route-cache" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group in"  ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group out" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip unnumbered") < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,   "no description ") < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "no interface Vlan".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}


sub CATIOS_term_l3realnet_down {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # IP LOGIN PASS ENA_PASS VLAN DOWN_ACLIN DOWN_ACLOUT
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "BLOCK Real IP Unnumbered Iface Vlan'".$arg->{'VLAN'}."' in terminator '".$arg->{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,   "interface Vlan".$arg->{'VLAN'} ) < 1);
#    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group in"  ) < 1);
#    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group out" ) < 1);
    if ( defined($arg->{'DOWN_ACLIN'})  ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'DOWN_ACLIN'}. " in"  ) < 1); }
    if ( defined($arg->{'DOWN_ACLOUT'}) ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'DOWN_ACLOUT'}." out" ) < 1); }
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}


sub CATIOS_term_l3realnet_up {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # IP LOGIN PASS ENA_PASS VLAN UP_ACLIN UP_ACLOUT
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "UNBLOCK Real IP Unnumbered Iface Vlan'".$arg->{'VLAN'}."' in terminator '".$arg->{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,   "interface Vlan".$arg->{'VLAN'} ) < 1);
#    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group in"  ) < 1);
#    return -1  if (&$command(\$sw, $prompt_conf_if,   "no ip access-group out" ) < 1);
    if ( defined($arg->{'UP_ACLIN'})  ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'UP_ACLIN'}. " in"  ) < 1); }
    if ( defined($arg->{'UP_ACLOUT'}) ) { return -1  if (&$command(\$sw, $prompt_conf_if,   "ip access-group ".$arg->{'UP_ACLOUT'}." out" ) < 1); }
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}


1;
