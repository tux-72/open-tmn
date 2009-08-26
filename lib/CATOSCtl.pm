#!/usr/bin/perl

package CATOSCtl;

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

@EXPORT = qw(	CATOS_pass_change CATOS_conf_first	CATOS_conf_save	CATOS_fix_vlan	CATOS_fix_macport
		CATOS_port_up	CATOS_port_down	CATOS_port_defect	CATOS_port_free	CATOS_port_setparms
		CATOS_port_portchannel    CATOS_port_trunk	CATOS_port_system
		CATOS_vlan_trunk_add	CATOS_vlan_trunk_remove	CATOS_vlan_remove
	    );

my $debug=1;
my $timeout=3;

my $LIB='CATOS';
my $command     = $LIB."_cmd";
my $login       = $LIB."_login";
my $login_nopriv= $LIB."_login_nopriv";
my $speed_char  = $LIB."_speed_char";

my $block_vlan=4094;
my $prompt='/.*\>.*\(enable\).*/';
my $prompt_nopriv='/.*\>.*/';

# percent supression multicast and broadcast
my $trunk_ctl_mcast     = 1;    my $trunk_ctl_bcast     = 10;
my $port_ctl_mcast      = 1;    my $port_ctl_bcast      = 2;

############ SUBS ##############

sub CATOS_conf_first {
    print STDERR "Switch '$arg{'IP'}' first configured MANUALLY!!!\n";
    return -1;
}

sub CATOS_pass_change {
    print STDERR "Switch '$arg{'IP'}' changed password MANUALLY!!!\n" if $debug;
    return -1;
}

sub CATOS_conf_save {
    print STDERR "CATOS autosave config ;-) !!!\n" if $debug;
    return 1;
}

sub CATOS_speed_char {

    my %arg = (
        @_,         # список пар аргументов
    );
    my @dpl = ''; $dpl[0] = 'half'; $dpl[1] = 'full';

    my $spd = 'auto';
    if ( $arg{'SPEED'} =~ /^1(0|00|000)/ && $arg{'DUPLEX'} =~ /(0|1)/ and not $arg{'AUTONEG'} ) { 
	$spd = $arg{'SPEED'};
    }
    return ($spd, $dpl[$arg{'DUPLEX'}]);
}

sub CATOS_login {
    my ($swl, $ip, $pass, $ena_pass) = @_;
    print STDERR " IP = ".$ip.", PASS = ".$pass.", ENA_PASS =".$ena_pass." \n" if $debug > 1;
    ${$swl}=new Net::Telnet (   prompt => $prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    ${$swl}->open($ip);
    ${$swl}->waitfor("/Enter password.*/");
    ${$swl}->print($pass);
    ${$swl}->waitfor($prompt_nopriv);
    ${$swl}->print("ena");
    ${$swl}->waitfor("/Enter password.*/");
    ${$swl}->print($ena_pass);
    ${$swl}->waitfor($prompt) || return -1;
    print STDERR "Connect superuser - Ok\n" if $debug > 1;
    return 1;
}

sub CATOS_login_nopriv {
    my ($swl, $ip, $pass) = @_;
    print STDERR " IP - ".$ip.", PASS ".$pass." \n\n" if $debug > 1;
    ${$swl}=new Net::Telnet (   prompt => $prompt_nopriv,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    ${$swl}->open($ip);
    ${$swl}->waitfor("/Enter password.*/");
    ${$swl}->print($pass);
    ${$swl}->waitfor($prompt_nopriv) || return -1;
    print STDERR "Connected non privilege user - Ok\n" if $debug > 1;
    return 1;
}

sub CATOS_cmd {
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

sub CATOS_fix_vlan {
    # IP LOGIN PASS MAC VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login_nopriv(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );
    print STDERR "Fixing VLAN in switch '".$arg{'IP'}."', MAC '".$arg{'MAC'}."' ...\n" if $debug;

    my $vlan = 0;
    $arg{'MAC'} =~ s/\:/\-/g;
    my @ln = $sw->cmd('show cam dynamic | inc '.$arg{'MAC'});
    foreach (@ln) {
	#	print STDERR "lines - $lnv\n";
	#VLAN  Dest MAC/Route Des    [CoS]  Destination Ports
	#1     00-03-42-97-66-a1             3/1 [ALL]
	if ( /(\d+)\s+(\w\w\-\w\w\-\w\w\-\w\w\-\w\w\-\w\w)\s+(\d+\/\d+)\s+/ and $2 >1 ) {
	    $vlan = "$1";
	}
    }
    $sw->close();
    print STDERR "MAC VLAN - $vlan\n" if $debug;
    return $vlan;
}

sub CATOS_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my %arg = (
        @_,
    );
    my $sw;  return -1  if (&$login_nopriv(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );

    $arg{'MAC'} =~ s/\:/\-/g;
    my $port = 0; my $pref; my $max=3; my $count=0; my @p = '';

    while ($count < $max) {
    my @ln= $sw->cmd('show cam dynamic '.$arg{'VLAN'}.' | inc '.$arg{'MAC'});
        foreach (@ln) {
	    #	print STDERR "lines - $lnv\n";
	    #VLAN  Dest MAC/Route Des    [CoS]  Destination Ports
	    #1     00-03-42-97-66-a1             3/1 [ALL]
            if ( /(\d+)\s+(\w\w\-\w\w\-\w\w\-\w\w\-\w\w\-\w\w)\s+(\d+\/)(\d+)\s+/ and $2 eq $arg{'MAC'} and $1 == $arg{'VLAN'} ) {
                $port = $4;
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
    print STDERR "MAC Port - $pref / $port\n" if $debug > 1;
    return ($pref, $port);
}


sub CATOS_port_up {

#    IP LOGIN PASS PORT PORTPREF
    my %arg = (
        @_,
    );
    print STDERR "Set port ".$arg{'PORTPREF'}.$arg{'PORT'}." state UP in switch ".$arg{'IP'}."...\n\n" if $debug;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    return -1  if (&$command(\$sw, $prompt,	"set port enable ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    $sw->close();
    return 1;
}

sub CATOS_port_down {
#    IP LOGIN PASS PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    print STDERR "Set port ".$arg{'PORTPREF'}.$arg{'PORT'}." state DOWN in switch ".$arg{'IP'}."...\n\n" if $debug;

    $sw->print("set port disable ".$arg{'PORTPREF'}.$arg{'PORT'});
    $sw->waitfor("/Do you want to continue.*/") || return -1;
    return -1  if (&$command(\$sw, $prompt,	"y" ) < 1);
    $sw->close();
    return 1;
}


sub CATOS_port_defect {
#    IP LOGIN PASS PORT PORTPREF VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    print STDERR "Set port ".$arg{'PORTPREF'}.$arg{'PORT'}." status DEFECT in switch ".$arg{'IP'}."...\n\n" if $debug;

    return -1  if (&$command(\$sw, $prompt,	"clear trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." 1-1005,1025-4094" ) < 1);
    return -1  if (&$command(\$sw, $prompt,	"set trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." off dot1q" ) < 1);
    return -1  if (&$command(\$sw, $prompt,	"set vlan ".$block_vlan." ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    $sw->print("set port disable ".$arg{'PORTPREF'}.$arg{'PORT'});
    $sw->waitfor("/Do you want to continue.*/") || return -1;
    return -1  if (&$command(\$sw, $prompt,	"y" ) < 1);
    $sw->close();
    return 1;
}

sub CATOS_port_free {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN
    my %arg = (
        @_,
    );
    return -1 if (not $arg{'VLAN'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    print STDERR "Set port ".$arg{'PORTPREF'}.$arg{'PORT'}." status FREE in switch ".$arg{'IP'}."...\n\n" if $debug;

    return -1  if (&$command(\$sw, $prompt,	"set vlan ".$arg{'VLAN'}) < 1);
    return -1  if (&$command(\$sw, $prompt,	"set port speed ".$arg{'PORTPREF'}.$arg{'PORT'}." auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt,	"set vlan ".$arg{'VLAN'}." ".$arg{'PORTPREF'}.$arg{'PORT'}) < 1);
    return -1  if (&$command(\$sw, $prompt,	"clear trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." 1-1005,1025-4094" ) < 1);
    return -1  if (&$command(\$sw, $prompt,	"set trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." off dot1q" ) < 1);
    return -1  if (&$command(\$sw, $prompt,	"set port enable ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    $sw->close();
    return 1;
}

sub CATOS_port_trunk {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    print STDERR "Set port ".$arg{'PORTPREF'}.$arg{'PORT'}." is TRUNK in switch ".$arg{'IP'}."...\n\n" if $debug;
    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});

    return -1  if (&$command(\$sw, $prompt,	"set port speed ".$arg{'PORTPREF'}.$arg{'PORT'}." ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt,	"set vlan ".$arg{'VLAN'}) < 1);
    if (not $arg{'AUTONEG'}) {
	return -1  if (&$command(\$sw, $prompt,	 "set port duplex ".$arg{'PORTPREF'}.$arg{'PORT'}." ".$duplex) < 1);
    }
    if (not $arg{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt,	 "set vlan ".$arg{'VLAN'}." ".$arg{'PORTPREF'}.$arg{'PORT'}) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt,	 "set vlan ".$block_vlan." ".$arg{'PORTPREF'}.$arg{'PORT'}) < 1);
    }
    return -1  if (&$command(\$sw, $prompt,	 "set trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." nonegotiate dot1q ".$arg{'VLAN'}) < 1);
    return -1  if (&$command(\$sw, $prompt,	 "set port enable ".$arg{'PORTPREF'}.$arg{'PORT'}) < 1);
    $sw->close();
    return 1;
}


sub CATOS_port_system {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    print STDERR "Set port ".$arg{'PORTPREF'}.$arg{'PORT'}." is SYSTEM in switch ".$arg{'IP'}."...\n\n" if $debug;
    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});

    return -1  if (&$command(\$sw, $prompt,	"set port speed ".$arg{'PORTPREF'}.$arg{'PORT'}." ".$speed ) < 1);
    if (not $arg{'AUTONEG'}) {
	return -1  if (&$command(\$sw, $prompt,	 "set port duplex ".$arg{'PORTPREF'}.$arg{'PORT'}." ".$duplex) < 1);
    }
    return -1  if (&$command(\$sw, $prompt,	"set vlan ".$arg{'VLAN'}) < 1);
    if (not $arg{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt,	"set vlan ".$arg{'VLAN'}." ".$arg{'PORTPREF'}.$arg{'PORT'}) < 1);
	return -1  if (&$command(\$sw, $prompt,	"clear trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." 1-1005,1025-4094" ) < 1);
	return -1  if (&$command(\$sw, $prompt,	"set trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." off dot1q") < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt,	"set vlan ".$block_vlan." ".$arg{'PORTPREF'}.$arg{'PORT'}) < 1);
	return -1  if (&$command(\$sw, $prompt,	"set trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." nonegotiate dot1q ".$arg{'VLAN'}) < 1);
    }
    return -1  if (&$command(\$sw, $prompt,	"set port enable ".$arg{'PORTPREF'}.$arg{'PORT'}) < 1);
    $sw->close();
    return 1;
}

sub CATOS_port_setparms {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    print STDERR "Set PARAMETERS port ".$arg{'PORTPREF'}.$arg{'PORT'}." in switch ".$arg{'IP'}."...\n\n" if $debug;
    my ($speed, $duplex ) = &$speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});

    return -1  if (&$command(\$sw, $prompt,	"set port speed ".$arg{'PORTPREF'}.$arg{'PORT'}." ".$speed ) < 1);
    if (not $arg{'AUTONEG'}) {
	return -1  if (&$command(\$sw, $prompt,	 "set port duplex ".$arg{'PORTPREF'}.$arg{'PORT'}." ".$duplex) < 1);
    }
    return -1  if (&$command(\$sw, $prompt,	"set vlan ".$arg{'VLAN'}) < 1);
    if (not $arg{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt,	"set vlan ".$arg{'VLAN'}." ".$arg{'PORTPREF'}.$arg{'PORT'}) < 1);
	return -1  if (&$command(\$sw, $prompt,	"clear trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." 1-1005,1025-4094" ) < 1);
	return -1  if (&$command(\$sw, $prompt,	"set trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." off dot1q") < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt,	"set vlan ".$block_vlan." ".$arg{'PORTPREF'}.$arg{'PORT'}) < 1);
	return -1  if (&$command(\$sw, $prompt,	"set trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." nonegotiate dot1q ".$arg{'VLAN'}) < 1);
    }
    return -1  if (&$command(\$sw, $prompt,	"set port enable ".$arg{'PORTPREF'}.$arg{'PORT'}) < 1);
    $sw->close();
    return 1;
}


sub CATOS_vlan_trunk_add  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    print STDERR "ADD VLAN '".$arg{'VLAN'}."' in ".$arg{'IP'}.", trunk port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;

#    return -1  if (&$command(\$sw, $prompt,	"set vlan ".$arg{'VLAN'}." name ".$arg{'VLANNAME'}) < 1);
    return -1  if (&$command(\$sw, $prompt,	"set vlan ".$arg{'VLAN'}) < 1);
    return -1  if (&$command(\$sw, $prompt,	"set trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." nonegotiate dot1q ".$arg{'VLAN'}) < 1);

    $sw->close();
    return 1;
}


sub CATOS_vlan_trunk_remove  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    print STDERR "REMOVE VLAN '".$arg{'VLAN'}."' in ".$arg{'IP'}.", trunk port ".$arg{'PORTPREF'}.$arg{'PORT'}."!!!\n\n" if $debug;

    return -1  if (&$command(\$sw, $prompt,	"clear trunk ".$arg{'PORTPREF'}.$arg{'PORT'}." ".$arg{'VLAN'}) < 1);
    $sw->close();
    return 1;
}

sub CATOS_vlan_remove  {

#    IP LOGIN PASS VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    print STDERR "REMOVE VLAN '".$arg{'VLAN'}."' from switch ".$arg{'IP'}."!!!\n\n" if $debug;

    $sw->print("clear vlan ".$arg{'VLAN'});
    $sw->waitfor("/Do you want to continue.*/") || return -1;
    return -1  if (&$command(\$sw, $prompt,	"y" ) < 1);
    $sw->close();
    return 1;
}

