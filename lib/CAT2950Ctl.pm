#!/usr/bin/perl

package CAT2950Ctl;

#use strict;
#use Net::SNMP;
#use locale;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.2;
@ISA = qw(Exporter);

@EXPORT_OK = qw();
@EXPORT_TAGS = ();

@EXPORT = qw(	CAT2950_pass_change CAT2950_conf_first	CAT2950_conf_save	CAT2950_fix_macport	CAT2950_fix_vlan
		CAT2950_port_up	CAT2950_port_down	CAT2950_port_defect	CAT2950_port_free	CAT2950_port_setparms
		CAT2950_port_trunk	CAT2950_port_system
		CAT2950_vlan_trunk_add	CAT2950_vlan_trunk_remove	CAT2950_vlan_remove
	    );

my $debug=1;

my $LIB='CAT2950';
my $command	= $LIB."_cmd";
my $login	= $LIB."_login";
my $login_nopriv= $LIB."_login_nopriv";
my $speed_char	= $LIB."_speed_char";
#my $block_vlan=4094;

my $timeout=15;
#my $prompt='/\r{1,}CAT2950\-.*#$/i';
my $prompt='/.*#.*/';
my $prompt_nopriv='/.*[\>#].*/';
my $prompt_conf ='/.*\(config\)#.*/';
my $prompt_conf_if ='/.*\(config\-if\)#.*/';
my $prompt_conf_vlan ='/.*\(config\-vlan\)#.*/';

# percent supression multicast and broadcast
my $trunk_ctl_mcast	= 1;	my $trunk_ctl_bcast	= 10;
my $port_ctl_mcast	= 1;	my $port_ctl_bcast	= 2;

############ SUBS ##############

sub CAT2950_conf_first {
    print STDERR "Switch '$arg{'IP'}' first configured MANUALLY!!!\n";
    return -1;
}

sub CAT2950_pass_change {
    print STDERR "Switch '$arg{'IP'}' changed password MANUALLY!!!\n" if $debug;
    return -1;
}

sub CAT2950_login {
    my ($swl, $ip, $pass, $ena_pass) = @_;
    print STDERR " IP = ".$ip.", PASS = ".$pass.", ENA_PASS =".$ena_pass." \n" if $debug > 1;
    ${$swl}=new Net::Telnet (	prompt => $prompt,
                            	Timeout => $timeout,
                        	Errmode => 'return',
			    );
    ${$swl}->open($ip);
    ${$swl}->waitfor("/.*assword.*/");
    ${$swl}->print($pass);
    ${$swl}->waitfor($prompt_nopriv);
    ${$swl}->print("ena");
    ${$swl}->waitfor("/.*assword.*/");
    ${$swl}->print($ena_pass);
    ${$swl}->waitfor($prompt) || return -1;
    print STDERR "Connect superuser - Ok\n" if $debug > 1;
    return 1;
}

sub CAT2950_login_nopriv {
    my ($swl, $ip, $pass) = @_;
    print STDERR " IP - ".$ip.", PASS ".$pass." \n\n" if $debug > 1;
    ${$swl}=new Net::Telnet (	prompt => $prompt_nopriv,
				Timeout => $timeout,
				Errmode => 'return',
			    );
    ${$swl}->open($ip);
    ${$swl}->waitfor("/.*assword.*/");
    ${$swl}->print($pass);
    ${$swl}->waitfor($prompt_nopriv) || return -1;
    print STDERR "Connected non privilege user - Ok\n" if $debug > 1;
    return 1;
}

sub CAT2950_cmd {
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

sub CAT2950_fix_vlan {
    # IP LOGIN PASS MAC
    my %arg = (
        @_,
    );
    print STDERR "Fixing VLAN in switch '".$arg{'IP'}."', MAC '".$arg{'MAC'}."' ...\n" if $debug;
    my $vlan = 0;
    # login
    my $sw;  return -1  if (&$login_nopriv(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );
    my @ln = $sw->cmd("show mac-address-table dynamic address ".$arg{'MAC'});
    foreach (@ln) {
	    #Vlan    Mac Address       Type        Ports
	    # 999    0004.38bb.8061    DYNAMIC     Gi0/2
	if ( /(\d+)\s+\w\w\w\w\.\w\w\w\w\.\w\w\w\w\s+\S+\s+\S+/ and $1 > 1) {
            $vlan = $1;
	}
    }
    $sw->close();
    return $vlan;
}

sub CAT2950_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my %arg = (
        @_,
    );
    print STDERR "Fixing PORT in switch '".$arg{'IP'}."', MAC '".$arg{'MAC'}."', VLAN '".$arg{'VLAN'}."' ...\n" if $debug;

    my $port = -1; my $pref; my $max=3; my $count=0;
    # login
    my $sw; return -1  if ( &$login_nopriv(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    while ($count < $max) {
    my @ln = $sw->cmd("show mac-address-table dynamic address ".$arg{'MAC'}." vlan ".$arg{'VLAN'});
        foreach (@ln) {
	    #Vlan    Mac Address       Type        Ports
	    # 999    0004.38bb.8061    DYNAMIC     Gi0/2
            if ( /(\d+)\s+(\w\w\w\w\.\w\w\w\w\.\w\w\w\w)\s+\S+\s+(Fa|Gi)(\d+\/)(\d+)/ ) {
                $port = $5+0;
                $pref = "$3$4";
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


sub CAT2950_conf_save {
#   IP LOGIN PASS ENA_PASS
    my %arg = (
        @_,
    );
    print STDERR "SAVING $LIB config in switch ".$arg{'IP'}." ...\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    
    if ($debug < 2) {
	$sw->print("copy running-config startup-config");
	$sw->waitfor("/\[startup-config\]/");
	return -1  if (&$command(\$sw, $prompt, "" ) < 1 );
    } else {
	print STDERR $LIB."_conf_save function not running in DEBUG mode\n";
    }
    $sw->close();
    return 1;
}



sub CAT2950_port_up {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my %arg = (
        @_,
    );
    print STDERR "Set port UP in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}." !!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub CAT2950_port_down {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my %arg = (
        @_,
    );
    print STDERR "Set port DOWN in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}." !!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}


sub CAT2950_port_defect {
#    IP LOGIN PASS PORT PORTPREF VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    print STDERR "Configure DEFECT port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}." !!!\n\n" if $debug;
    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'BLOCK_VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"description PORT DEFECT!!!" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub CAT2950_port_free {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN
    my %arg = (
        @_,
    );
    return -1 if (not $arg{'VLAN'});
    print STDERR "Configure FREE port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}." !!!\n\n" if $debug;

    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"description FREE PORT!!!" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control multicast level ".$port_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control broadcast level ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub CAT2950_speed_char {

    my %arg = (
        @_,
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

sub CAT2950_port_trunk {
#   IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    print STDERR "configure TRUNK port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;

    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
    if ($arg{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk native vlan ".$arg{'BLOCK_VLAN'} ) < 1);
    } else {
        return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk native vlan ".$arg{'VLAN'} ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control multicast level ".$trunk_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control broadcast level ".$trunk_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}


sub CAT2950_port_system {

#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    print STDERR "configure SYSTEM port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;
    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    if ($arg{'TAG'}) {
	#return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'BLOCK_VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg{'VLAN'} ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk native vlan ".$arg{'BLOCK_VLAN'} ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control multicast level ".$trunk_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control broadcast level ".$trunk_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CAT2950_port_setparms {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    print STDERR "SET PORT parameters in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;
    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    if ($arg{'TAG'}) {
	#return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'BLOCK_VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg{'VLAN'} ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk native vlan ".$arg{'BLOCK_VLAN'} ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control multicast level ".$port_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control broadcast level ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CAT2950_vlan_trunk_add {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    print STDERR "ADD VLAN '".$arg{'VLAN'}."' in ".$arg{'IP'}.", trunk port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
#    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
#    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CAT2950_vlan_trunk_remove  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    print STDERR "REMOVE VLAN '".$arg{'VLAN'}."' in ".$arg{'IP'}.", trunk port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    #return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan remove ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CAT2950_vlan_remove  {
#    IP LOGIN PASS VLAN
    my %arg = (
        @_,
    );
    print STDERR "REMOVE VLAN '".$arg{'VLAN'}."' from switch '".$arg{'IP'}."'!!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no vlan ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}
