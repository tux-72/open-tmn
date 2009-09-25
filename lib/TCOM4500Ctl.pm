#!/usr/bin/perl

package TCOM4500Ctl;

#use strict;
#use Net::SNMP;
#use locale;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.0;
@ISA = qw(Exporter);

@EXPORT_OK = qw();
@EXPORT_TAGS = ();

@EXPORT = qw(	TCOM4500_pass_change TCOM4500_conf_first	TCOM4500_conf_save	TCOM4500_fix_macport	TCOM4500_fix_vlan
		TCOM4500_port_up	TCOM4500_port_down	TCOM4500_port_defect	TCOM4500_port_free	TCOM4500_port_setparms
		TCOM4500_port_trunk	TCOM4500_port_system TCOM4500_port_vlan_link
		TCOM4500_vlan_trunk_add	TCOM4500_vlan_trunk_remove	TCOM4500_vlan_remove
	    );

my $debug=1;
my $timeout=15;

my $LIB='TCOM4500';
my $command     = $LIB."_cmd";
my $login       = $LIB."_login";
my $speed_char  = $LIB."_speed_char";
my $bw_char  	= $LIB."_bw_char";

my $block_vlan=4094;
my $prompt='/.*\<4500\>.*/';
my $prompt_conf ='/.*\[4500\].*/';
my $prompt_conf_if ='/.*\[4500\-.*thernet.*\].*/';
my $prompt_conf_vlan ='/.*\[4500\-vlan.*\].*/';

my $trunk_ctl_mcast     = 2;
my $trunk_ctl_bcast     = 10;
my $port_ctl_mcast      = 1;
my $port_ctl_bcast      = 2;

my $bw_min      = 0;
my $bw_max      = 99968;
my $bw_free     = 64;


############ SUBS ##############

sub TCOM4500_conf_first {
    print STDERR "Switch '$arg{'IP'}' first configured MANUALLY!!!\n";
    return -1;
}

sub TCOM4500_pass_change {
    print STDERR "Switch '$arg{'IP'}' changed password MANUALLY!!!\n" if $debug;
    return -1;
}

sub TCOM4500_login {
    my ($swl, $ip, $login, $pass) = @_;
    #print STDERR " IP = ".$ip.", LOGIN = ".$login.", PASS = ".$pass."\n" if $debug > 1;
    ${$swl}=new Net::Telnet (   prompt => $prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    ${$swl}->open($ip);
    ${$swl}->login($login,$pass) || return -1;
    print STDERR "Login - Ok\n"; # if $debug > 1;
    return 1;
}

sub TCOM4500_cmd {
    my ($swl, $cmd_prompt, $cmd ) = @_;
    my @lines = ${$swl}->cmd(   String  => $cmd,
                                Prompt  => $cmd_prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    if ($debug) {
        print STDERR "\n>>> CMD '".$cmd."'\n>>> PRT '".${$swl}->last_prompt()."'\n";
        print STDERR @lines; print STDERR "\n";
    }
    return 1;
}

sub TCOM4500_mac_fix {
	my $mac = shift;
	$mac =~ /^(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)$/ || return -1 ;
	return "$1$2-$3$4-$5$6";
}


sub TCOM4500_speed_char {
    my %arg = (
        @_,         # список пар аргументов
    );
    $arg{'DUPLEX'} += 0;
    my @dpl = ''; $dpl[0] = 'half'; $dpl[1] = 'full';

    my $spd = 'auto';
    if ( $arg{'SPEED'} =~ /^1(0|00|000)/ && $arg{'DUPLEX'} =~ /(0|1)/ and not $arg{'AUTONEG'} ) {
        $spd = $arg{'SPEED'};
        return ($spd, $dpl[$arg{'DUPLEX'}]);
    } else {
        return ('auto', 'auto');
    }
}

sub TCOM4500_bw_char {
    my %arg = (
        @_,
    );
    my $dsl = ( $arg{'DS'} < $bw_min || $arg{'DS'} > $bw_max ? '' : "$arg{'DS'}" );
    my $usl = ( $arg{'US'} < $bw_min || $arg{'US'} > $bw_max ? '' : "$arg{'US'}" );
    my $out = ( $arg{'DS'} < $bw_min || $arg{'DS'} > $bw_max ? 'undo' : '' );
    my $in  = ( $arg{'US'} < $bw_min || $arg{'US'} > $bw_max ? 'undo' : '' );
    return ( $dsl, $out, $usl, $in );

}

sub TCOM4500_fix_vlan {
    # IP LOGIN PASS MAC
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "Fixing VLAN in switch '".$arg{'IP'}."', MAC '".$arg{'MAC'}."' ...\n" if $debug;

    my $vlan = 0;
    my $mac=TCOM4500_mac_fix($arg{'MAC'});
    print STDERR "MAC transfer - $mac " if $debug > 1;
    my $max=3; my $count=0;
    while ($count < $max) {
	my @ln = $sw->cmd("display mac-address ".$mac);
	foreach (@ln) {
	    print STDERR "$_" if $debug > 1;
	    #MAC ADDR        VLAN ID    STATE            PORT INDEX             AGING TIME(s)
	    #0017-315a-9277   344       Learned          GigabitEthernet1/0/49  AGING
	    if ( /\w\w\w\w\-\w\w\w\w\-\w\w\w\w\s+(\d+)\s+\S+\s+\S+/ and $1 > 1) {
        	$vlan = $1;
	    }
	}
        if ($vlan>0) {
            last;
        } else {
            $count+=1;
        }
    }
    $sw->close();
    return $vlan;
}

sub TCOM4500_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if ( &$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "Fixing PORT in switch '".$arg{'IP'}."', MAC '".$arg{'MAC'}."', VLAN '".$arg{'VLAN'}."' ...\n" if $debug > 1;

    my $mac=TCOM4500_mac_fix($arg{'MAC'});
    my $port = 0; my $pref; my $max=3; my $count=0;
    while ($count < $max) {
    my @ln = $sw->cmd("display mac-address ".$mac." vlan ".$arg{'VLAN'});
        foreach (@ln) {
	    print STDERR "$_" if $debug > 1;
	    #MAC ADDR        VLAN ID    STATE            PORT INDEX             AGING TIME(s)
	    #0017-315a-9277   344       Learned          GigabitEthernet1/0/49  AGING
	    if ( /\w\w\w\w\-\w\w\w\w\-\w\w\w\w\s+(\d+)\s+\S+\s+(Gi|Ether)\S+(\d+\/\d+\/)(\d+)\s+\S+/ and $1 == $arg{'VLAN'} ) {
                $port = $4+0;
                $pref = "$2"."$3";
            }
        }
        if ($port>0) {
            last;
        } else {
            $count+=1;
        }
    }
    $sw->close();
    print STDERR "MAC Port - $pref / $port\n" if $debug > 1;
    return ($pref, $port);
}


sub TCOM4500_conf_save {
#   IP LOGIN PASS ENA_PASS
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );
    print STDERR "SAVING $LIB config in switch ".$arg{'IP'}." ...\n" if $debug;

    if ($debug < 2) {
	$sw->print("save safely");
	$sw->waitfor("/.*Are you sure.*/");
	my @ln = $sw->cmd( String  => "y",
                                Prompt  => $prompt,
                                Timeout => 60,
                                Errmode => 'return',
                                #Cmd_remove_mode => 1,
        ); print STDERR @ln if $debug;
    } else {
	print STDERR $LIB."_conf_save function not running in DEBUG mode\n";
    }
    $sw->close();
    return 1;
}


sub TCOM4500_port_up {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );
    print STDERR "Set port UP in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}." !!!\n\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"system-view" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"undo shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"quit" ) < 1);
    $sw->close();
    return 1;
}

sub TCOM4500_port_down {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my %arg = (
        @_,
    );
    print STDERR "Set port DOWN in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}." !!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"system-view" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"quit" ) < 1);
    $sw->close();
    return 1;
}


sub TCOM4500_port_defect {
#    IP LOGIN PASS PORT PORTPREF VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );
    print STDERR "Configure DEFECT port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}." !!!\n\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"system-view" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"port link-type access" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"port access vlan ".$block_vlan ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"description PORT DEFECT!!!" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"line-rate outbound 64" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"priority 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"stp edged-port disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"quit" ) < 1);
    $sw->close();
    return 1;
}

sub TCOM4500_port_free {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN
    my %arg = (
        @_,
    );
    return -1 if (not $arg{'VLAN'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );
    print STDERR "Configure FREE port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}." !!!\n\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"system-view" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"port link-type access" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"port access vlan ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"description FREE PORT!!!" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"loopback-detection enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"multicast-suppression ".$port_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"broadcast-suppression ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"line-rate outbound ".$bw_free ) < 1);
    #return -1  if (&$command(\$sw, $prompt_conf_if,	"line-rate inbound  ".$bw_free ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"undo shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"priority 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"stp edged-port disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"undo packet-filter inbound link-group 4999 rule 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"quit" ) < 1);


    $sw->close();
    return 1;
}

sub TCOM4500_port_trunk {
#   IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    return -1 if (not $arg{'VLAN'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );
    print STDERR "configure TRUNK port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;
    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});

    return -1  if (&$command(\$sw, $prompt_conf,	"system-view" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"description TRUNK PORT!!!" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"port link-type trunk" ) < 1);
    if ($arg{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt_conf_if,     "undo port trunk pvid" ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf_if,     "port trunk pvid vlan ".$arg{'VLAN'} ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"port trunk permit vlan ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed  ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "loopback-detection enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"multicast-suppression ".$trunk_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"broadcast-suppression ".$trunk_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "undo line-rate outbound" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "undo shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"priority 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"stp edged-port disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"undo packet-filter inbound link-group 4999 rule 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"quit" ) < 1);

    $sw->close();
    return 1;
}


sub TCOM4500_port_system {

#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    #return -1 if (not $arg{'VLAN'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );
    print STDERR "configure SYSTEM port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;

    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});
    my ( $ds, $out, $us, $in )  = &$bw_char( DS => $arg{'DS'}, US => $arg{'US'} );


    return -1  if (&$command(\$sw, $prompt_conf,	"system-view" ) < 1 );
    return -1  if ( $arg{'VLAN'} and &$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if ( $arg{'VLAN'} and &$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"description SYSTEM PORT!!!" ) < 1);
    if ($arg{'VLAN'}) {
     if ($arg{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt_conf_if,	"port link-type trunk" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"port trunk permit vlan ".$arg{'VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if, "undo port trunk pvid" ) < 1);
     } else {
	return -1  if (&$command(\$sw, $prompt_conf_if,	"port link-type access" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"port access vlan ".$arg{'VLAN'} ) < 1);
     }
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed  ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "loopback-detection enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"multicast-suppression ".$port_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"broadcast-suppression ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	$out." line-rate outbound ".$ds ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "undo shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"priority 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"stp edged-port disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"undo packet-filter inbound link-group 4999 rule 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"quit" ) < 1);

    $sw->close();
    return 1;
}

sub TCOM4500_port_setparms {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );
    print STDERR "SET PORT parameters in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;

    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});
    my ( $ds, $out, $us, $in )  = &$bw_char( DS => $arg{'DS'}, US => $arg{'US'} );

    return -1  if (&$command(\$sw, $prompt_conf,	"system-view" ) < 1 );
    return -1  if ( $arg{'VLAN'} and &$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if ( $arg{'VLAN'} and &$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"description CLIENT PORT" ) < 1);
    if ($arg{'VLAN'}) {
     if ($arg{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt_conf_if,	"port link-type trunk" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"port trunk permit vlan ".$arg{'VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if, "undo port trunk pvid" ) < 1);
     } else {
	return -1  if (&$command(\$sw, $prompt_conf_if,	"port link-type access" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"port access vlan ".$arg{'VLAN'} ) < 1);
     }
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed  ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "loopback-detection enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"multicast-suppression ".$port_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"broadcast-suppression ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	$out." line-rate outbound ".$ds ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,     "undo shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"priority 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"stp edged-port disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"undo packet-filter inbound link-group 4999 rule 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"quit" ) < 1);

    $sw->close();
    return 1;
}

sub TCOM4500_vlan_trunk_add {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );
    print STDERR "ADD VLAN '".$arg{'VLAN'}."' in ".$arg{'IP'}.", trunk port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"system-view" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"port link-type trunk" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"port trunk permit vlan ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"quit" ) < 1);

    $sw->close();
    return 1;
}

sub TCOM4500_vlan_trunk_remove  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );
    print STDERR "REMOVE VLAN '".$arg{'VLAN'}."' in ".$arg{'IP'}.", trunk port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"system-view" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"undo port trunk permit vlan ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"quit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"quit" ) < 1);

    $sw->close();
    return 1;
}

sub TCOM4500_vlan_remove  {
#    IP LOGIN PASS VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'},  $arg{'PASS'}) < 1 );
    print STDERR "REMOVE VLAN '".$arg{'VLAN'}."' from switch '".$arg{'IP'}."'!!!\n\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"system-view" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"undo vlan ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"quit" ) < 1);
    $sw->close();
    return 1;
}
