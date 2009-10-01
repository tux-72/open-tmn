#!/usr/bin/perl

package CAT3508GCtl;

#use strict;
#use Net::SNMP;
#use locale;
use SWALLCtl;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.2;
@ISA = qw(Exporter);

@EXPORT_OK = qw();
@EXPORT_TAGS = ();

@EXPORT = qw(	CAT3508G_pass_change CAT3508G_conf_first	CAT3508G_conf_save	CAT3508G_fix_macport	CAT3508G_fix_vlan
		CAT3508G_port_up	CAT3508G_port_down	CAT3508G_port_defect	CAT3508G_port_free	CAT3508G_port_setparms
		CAT3508G_port_trunk	CAT3508G_port_system
		CAT3508G_vlan_trunk_add	CAT3508G_vlan_trunk_remove	CAT3508G_vlan_remove
	    );

my $debug=1;
my $timeout=3;

my $LIB='CAT3508G';
my $command     = $LIB."_cmd";
my $login       = $LIB."_login";
my $login_nopriv= $LIB."_login_nopriv";
my $speed_char  = $LIB."_speed_char";

#my $block_vlan=4094;
my $prompt='/.*#.*/';
my $prompt_nopriv='/.*[\>#].*/';
my $prompt_conf ='/.*\(config\)#.*/';
my $prompt_conf_if ='/.*\(config\-if\)#.*/';
my $prompt_conf_vlan ='/.*\(vlan\)#.*/';

############ SUBS ##############

sub CAT3508G_conf_first {
    dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => $LIB." Switch '".$arg{'IP'}."' first configured MANUALLY!!!" );
    return -1;
}

sub CAT3508G_pass_change {
    dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => $LIB." Switch '".$arg{'IP'}."' changed password MANUALLY!!!" );
    return -1;
}

sub CAT3508G_login {
    my ($swl, $ip, $pass, $ena_pass) = @_;
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "IP = ".$ip.", PASS = ".$pass.", ENA_PASS =".$ena_pass );
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
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Connect superuser - Ok" );
    return 1;
}

sub CAT3508G_login_nopriv {
    my ($swl, $ip, $pass) = @_;
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => " IP - ".$ip.", PASS ".$pass );
    ${$swl}=new Net::Telnet (	prompt => $prompt_nopriv,
				Timeout => $timeout,
				Errmode => 'return',
			    );
    ${$swl}->open($ip);
    ${$swl}->waitfor("/.*assword.*/");
    ${$swl}->print($pass);
    ${$swl}->waitfor($prompt_nopriv) || return -1;
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Connect non privilege user - Ok" );
    return 1;
}

sub CAT3508G_cmd {
    my ($swl, $cmd_prompt, $cmd ) = @_;

    dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => ${$swl}->last_prompt(), MESS => $cmd );
    my @lines = ${$swl}->cmd(   String  => $cmd,
                                Prompt  => $cmd_prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => ${$swl}->last_prompt(), MESS => \@lines );
    return 1;
}

sub CAT3508G_mac_fix {
	my $mac = shift;
	$mac =~ /^(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)$/ || return -1 ;
	return "$1$2.$3$4.$5$6";
}


sub CAT3508G_fix_vlan {
    # IP LOGIN PASS MAC
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login_nopriv(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing VLAN in switch '".$arg{'IP'}."', MAC '".$arg{'MAC'}."'" );

    my $vlan = 0;
    my $mac=CAT3508G_mac_fix($arg{'MAC'});
    my @ln = $sw->cmd("show mac-address-table dynamic address ".$mac);
    foreach (@ln) {
	    #0003.4297.b301       Dynamic          1  GigabitEthernet0/8
	if ( /\w\w\w\w\.\w\w\w\w\.\w\w\w\w\s+\S+\s+(\d+)\s+\S+/ and $1 > 1) {
            $vlan = $1;
	}
    }
    $sw->close();
    return $vlan;
}

sub CAT3508G_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if ( &$login_nopriv(\$sw, $arg{'IP'}, $arg{'PASS'}) < 1 );
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing PORT in switch '".$arg{'IP'}."', MAC '".$arg{'MAC'}."', VLAN '".$arg{'VLAN'}."'");

    my $mac=CAT3508G_mac_fix($arg{'MAC'});
    my $port = -1; my $pref; my $max=3; my $count=0;
    while ($count < $max) {
    my @ln = $sw->cmd("show mac-address-table dynamic address ".$mac." vlan ".$arg{'VLAN'});
        foreach (@ln) {
	    #0003.4297.b301       Dynamic          1  GigabitEthernet0/8
            if ( /(\w\w\w\w\.\w\w\w\w\.\w\w\w\w)\s+\S+\s+(\d+)\s+(Gi)\D+(\d+\/)(\d+)/ ) {
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
    return ($pref, $port);
}


sub CAT3508G_conf_save {
#   IP LOGIN PASS ENA_PASS
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SAVING $LIB config in switch '".$arg{'IP'}."'");
    $sw->print("copy runn startup");
    $sw->waitfor("/\[startup-config\]/");
    return -1  if (&$command(\$sw, $prompt, "\n" ) < 1 );
    $sw->close();
    return 1;
}


sub CAT3508G_port_up {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set port UP in '".$arg{'IP'}."', port ".$arg{'PORTPREF'}.$arg{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub CAT3508G_port_down {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set port DOWN in '".$arg{'IP'}."', port ".$arg{'PORTPREF'}.$arg{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}


sub CAT3508G_port_defect {
#    IP LOGIN PASS PORT PORTPREF VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure DEFECT port in '".$arg{'IP'}."', port ".$arg{'PORTPREF'}.$arg{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'BLOCK_VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"description PORT DEFECT!!!" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub CAT3508G_port_free {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN
    my %arg = (
        @_,
    );
    return -1 if (not $arg{'VLAN'});
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure FREE port in '".$arg{'IP'}."', port ".$arg{'PORTPREF'}.$arg{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan database" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'}." state active"  ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"description FREE PORT!!!" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub CAT3508G_speed_char {

    my %arg = (
        @_,
    );
    $arg{'DUPLEX'} += 0;
    my @dpl = ''; $dpl[0] = 'half'; $dpl[1] = 'full';

    if ( $arg{'DUPLEX'} =~ /(0|1)/ and not $arg{'AUTONEG'} ) {
	return ($dpl[$arg{'DUPLEX'}]);
    } else {
	return ('auto');
    }
}

sub CAT3508G_port_trunk {
#   IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure TRUNK port in '".$arg{'IP'}."', port ".$arg{'PORTPREF'}.$arg{'PORT'} );

    my $duplex = &$speed_char( DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
    if ($arg{'TAG'}) {
#	return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk native vlan ".$arg{'BLOCK_VLAN'} ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk native vlan ".$arg{'VLAN'} ) < 1);
    }

    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}


sub CAT3508G_port_system {

#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure SYSTEM port in '".$arg{'IP'}."', port ".$arg{'PORTPREF'}.$arg{'PORT'} );

    my $duplex = &$speed_char( DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});

    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan database" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'}." state active"  ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    if ($arg{'TAG'}) {
	#return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'BLOCK_VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg{'VLAN'} ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CAT3508G_port_setparms {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SET PARAMETERS in '".$arg{'IP'}."', port ".$arg{'PORTPREF'}.$arg{'PORT'} );

    my $duplex = &$speed_char( DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});

    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan database" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'}." state active"  ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    if ($arg{'TAG'}) {
	#return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'BLOCK_VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg{'VLAN'} ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg{'VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CAT3508G_vlan_trunk_add {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "ADD VLAN '".$arg{'VLAN'}."' in '".$arg{'IP'}."', trunk port ".$arg{'PORTPREF'}.$arg{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan database" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'}." state active"  ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CAT3508G_vlan_trunk_remove  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN '".$arg{'VLAN'}."' from '".$arg{'IP'}."', trunk port ".$arg{'PORTPREF'}.$arg{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg{'PORTPREF'}.$arg{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan remove ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CAT3508G_vlan_remove  {
#    IP LOGIN PASS VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN '".$arg{'VLAN'}."' from switch '".$arg{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan database" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

1;
