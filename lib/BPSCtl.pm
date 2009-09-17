#!/usr/bin/perl

package BPSCtl;

#use strict;
#use Net::SNMP;
#use locale;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.11;
@ISA = qw(Exporter);

@EXPORT_OK = qw();
@EXPORT_TAGS = ();

@EXPORT = qw(	BPS_pass_change BPS_conf_first	BPS_conf_save	BPS_fix_macport
		BPS_port_up	BPS_port_down	BPS_port_defect	BPS_port_free	BPS_port_setparms
		BPS_port_trunk	BPS_port_system
		BPS_vlan_trunk_add	BPS_vlan_trunk_remove	BPS_vlan_remove
	    );

my $debug=1;
my $timeout=10;

my $LIB='BPS';
my $command     = $LIB."_cmd";
my $login       = $LIB."_login";
my $login_nopriv= $LIB."_login_nopriv";
my $speed_char  = $LIB."_speed_char";

my $block_vlan=4094;
my $prompt='/.*[\>#].*/';
my $prompt_conf ='/.*\(config\)#.*/';
my $prompt_conf_if ='/.*\(config\-if\)#.*/';
my $prompt_conf_vlan ='/.*\(config\-vlan\)#.*/';

# percent supression multicast and broadcast
my $trunk_ctl_mcast	= 1;	my $trunk_ctl_bcast	= 10;
my $port_ctl_mcast	= 1;	my $port_ctl_bcast	= 2;

############ SUBS ##############

sub BPS_conf_first {
    print STDERR "Switch '$arg{'IP'}' first configured MANUALLY!!!\n";
    return -1;
}

sub BPS_pass_change {
    print STDERR "Switch '$arg{'IP'}' changed password MANUALLY!!!\n" if $debug;
    return -1;
}

sub BPS_login {
    my ($swl, $ip, $pass ) = @_;
    #print STDERR " IP = ".$ip.", PASS = ".$pass."\n" if $debug > 1;
    ${$swl}=new Net::Telnet (	prompt => $prompt,
                            	Timeout => $timeout,
                        	Errmode => 'return',
			    );
    ${$swl}->open($ip);
    #print STDERR "Wait line Ctrl-Y\n" if $debug > 1;
    ${$swl}->waitfor("/.*Enter Ctrl.*/");
    #print STDERR "line Ctrl-Y found\n" if $debug > 1;
    ${$swl}->print("\cy");
    #print STDERR "line Ctrl-Y input\n" if $debug > 1;
    ${$swl}->waitfor("/.*Enter Password.*/");
    #print STDERR "Password input\n" if $debug > 1;
    ${$swl}->print($pass);
    ${$swl}->waitfor("/.*Use arrow keys to.*/");
    ${$swl}->print("c");
    ${$swl}->waitfor($prompt) || return -1;
    #print STDERR "USE BPS command line interface - Ok\n" if $debug > 1;
    return 1;
}

sub BPS_cmd {
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

sub BPS_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my %arg = (
        @_,
    );
    print STDERR "Fixing PORT in switch '".$arg{'IP'}."', MAC '".$arg{'MAC'}."', VLAN '".$arg{'VLAN'}."' ...\n" if $debug;
    # login
    my $sw; return -1  if ( &$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    my $port = 0; my $pref; my $max=3; my $count=0;
    while ($count < $max) {
    my @ln = $sw->cmd("show mac-address-table vid ".$arg{'VLAN'}." address ".$arg{'MAC'});
        foreach (@ln) {
	    #   MAC Address      Source          MAC Address      Source
	    #-----------------  --------      -----------------  --------
	    #00-04-DC-C8-14-E1  Port: 24
            if ( /(\w\w\-\w\w\-\w\w\-\w\w\-\w\w\-\w\w)\s+Port\:\s+(\d+)/ ) {
                $port = $2+0;
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


sub BPS_conf_save {
#   IP LOGIN PASS ENA_PASS
    my %arg = (
        @_,
    );
    print STDERR "SAVING $LIB config in switch ".$arg{'IP'}." ...\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    if ($debug < 2) {
	return -1  if (&$command(\$sw, $prompt, "copy config nvram" ) < 1 );
    } else {
	print STDERR $LIB."_conf_save function not running in DEBUG mode\n";
    }
    $sw->close();
    return 1;
}



sub BPS_port_up {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my %arg = (
        @_,
    );
    print STDERR "Set port UP in ".$arg{'IP'}.", port ".$arg{'PORT'}." !!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub BPS_port_down {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my %arg = (
        @_,
    );
    print STDERR "Set port DOWN in ".$arg{'IP'}.", port ".$arg{'PORT'}." !!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}


sub BPS_port_defect {
#    IP LOGIN PASS PORT PORTPREF VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    print STDERR "Configure DEFECT port in ".$arg{'IP'}.", port ".$arg{'PORT'}." !!!\n\n" if $debug;
    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan create ".$block_vlan." name Block".$block_vlan." type port learning ivl" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan members add ".$block_vlan." ".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan ports ".$arg{'PORT'}." tagging disable pvid ".$block_vlan.
    " filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub BPS_port_free {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN
    my %arg = (
        @_,
    );
    return -1 if (not $arg{'VLAN'});
    print STDERR "Configure FREE port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}." !!!\n\n" if $debug;

    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan create ".$arg{'VLAN'}." name PPPoE_vlan".$arg{'VLAN'}." type port learning ivl" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan members add ".$arg{'VLAN'}." ".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan ports ".$arg{'PORT'}." tagging disable pvid ".$arg{'VLAN'}.
    " filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
    #return -1  if (&$command(\$sw, $prompt_conf,	"spanning-tree tagged-bpdu disable" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree port ".$arg{'PORT'}." learning disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"rate-limit port ".$arg{'PORT'}." both ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub BPS_speed_char {

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

sub BPS_port_trunk {
#   IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    print STDERR "configure TRUNK port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;

    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    if ($arg{'VLAN'} != 1 ) {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan create ".$arg{'VLAN'}." name Vlan".$arg{'VLAN'}." type port learning ivl" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan members add ".$arg{'VLAN'}." ".$arg{'PORT'} ) < 1);
    if ($arg{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan ports ".$arg{'PORT'}." tagging tagAll untagPvidOnly pvid ".$arg{'VLAN'}.
	" filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan ports ".$arg{'PORT'}." tagging untagPvidOnly pvid ".$arg{'VLAN'}.
	" filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
    }
    #return -1  if (&$command(\$sw, $prompt_conf,	"spanning-tree tagged-bpdu disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree port ".$arg{'PORT'}." learning disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"rate-limit port ".$arg{'PORT'}." both ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}


sub BPS_port_system {

#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    print STDERR "configure SYSTEM port in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;
    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );


    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    if ($arg{'VLAN'} != 1 ) {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan create ".$arg{'VLAN'}." name Vlan".$arg{'VLAN'}." type port learning ivl" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan members add ".$arg{'VLAN'}." ".$arg{'PORT'} ) < 1);
    if ($arg{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan ports ".$arg{'PORT'}." tagging tagAll untagPvidOnly pvid ".$arg{'VLAN'}.
	" filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan ports ".$arg{'PORT'}." tagging untagPvidOnly pvid ".$arg{'VLAN'}.
	" filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
    }
    #return -1  if (&$command(\$sw, $prompt_conf,	"spanning-tree tagged-bpdu disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree port ".$arg{'PORT'}." learning disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"rate-limit port ".$arg{'PORT'}." both ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub BPS_port_setparms {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    print STDERR "SET PORT parameters in ".$arg{'IP'}.", port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;
    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    if ($arg{'VLAN'} != 1 ) {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan create ".$arg{'VLAN'}." name Vlan".$arg{'VLAN'}." type port learning ivl" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan members add ".$arg{'VLAN'}." ".$arg{'PORT'} ) < 1);
    if ($arg{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan ports ".$arg{'PORT'}." tagging tagAll untagPvidOnly pvid ".$arg{'VLAN'}.
	" filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan ports ".$arg{'PORT'}." tagging untagPvidOnly pvid ".$arg{'VLAN'}.
	" filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
    }
    #return -1  if (&$command(\$sw, $prompt_conf,	"spanning-tree tagged-bpdu disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree port ".$arg{'PORT'}." learning disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"rate-limit port ".$arg{'PORT'}." both ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub BPS_vlan_trunk_add {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    print STDERR "ADD VLAN '".$arg{'VLAN'}."' in ".$arg{'IP'}.", trunk port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );


    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    if ($arg{'VLAN'} != 1 ) {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan create ".$arg{'VLAN'}." name Vlan".$arg{'VLAN'}." type port learning ivl" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan members add ".$arg{'VLAN'}." ".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub BPS_vlan_trunk_remove  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    print STDERR "REMOVE VLAN '".$arg{'VLAN'}."' in ".$arg{'IP'}.", trunk port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );


    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan members remove ".$arg{'VLAN'}." ".$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub BPS_vlan_remove  {
#    IP LOGIN PASS VLAN
    my %arg = (
        @_,
    );
    print STDERR "REMOVE VLAN '".$arg{'VLAN'}."' from switch '".$arg{'IP'}."'!!!\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan delete ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}
