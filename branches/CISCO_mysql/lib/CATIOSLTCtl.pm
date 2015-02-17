#!/usr/bin/perl

package CATIOSLTCtl;

use strict;
no strict qw(refs);

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.2;
@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw(	CATIOSLT_pass_change CATIOSLT_conf_first	CATIOSLT_conf_save	CATIOSLT_fix_macport	CATIOSLT_fix_vlan
		CATIOSLT_port_up	CATIOSLT_port_down	CATIOSLT_port_defect	CATIOSLT_port_free	CATIOSLT_port_setparms
		CATIOSLT_port_trunk	CATIOSLT_port_system CATIOSLT_port_add_policy_map
		CATIOSLT_vlan_trunk_add	CATIOSLT_vlan_trunk_remove	CATIOSLT_vlan_remove CATIOSLT_port_disable_shape
	    );

my $debug=1;

my $LIB='CATIOSLT';
my $command	= $LIB."_cmd";
my $login	= $LIB."_login";
my $speed_char	= $LIB."_speed_char";

my $timeout=15;
my $timeout_login=5;
my $prompt='/.*#.*/';
my $prompt_nopriv='/.*[\>#].*/';
my $prompt_conf ='/.*\(config\)#.*/';
my $prompt_conf_if ='/.*\(config\-if\)#.*/';
my $prompt_conf_if_range ='/.*\(config\-if-range\)#.*/';
my $prompt_conf_vlan ='/.*\(config\-vlan\)#.*/';
my $prompt_conf_ext_acl ='/.*\(config-ext-nacl\)#.*/';
my $prompt_conf_cmap ='/.*\(config-cmap\)#.*/';
my $prompt_conf_pmap ='/.*\(config-pmap\)#.*/';
my $prompt_conf_pmapc ='/.*\(config-pmap-c\)#.*/';
my $prompt_conf_line ='/.*\(config-line\)#.*/';

# percent supression multicast and broadcast
my $trunk_ctl_mcast	= 1;	my $trunk_ctl_bcast	= 10;
my $port_ctl_mcast	= 1;	my $port_ctl_bcast	= 2;

############ SUBS ##############

sub CATIOSLT_conf_first {
    # erase startup-config
    # reload
    # conf t
    # int vlan1
    # ip add 192.168.128.235 255.255.255.0
    # no shut
    # exit
    # username admin access-class 1 privilege 15 password 7 072E2359442D1B1C11
    # line vty 0 15
    # login local
    # exit

    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "First config switch '".$arg->{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );

    if ($arg->{'IP'} =~ /^192\.168\.128\./) {
        return -1  if (&$command(\$sw, $prompt_conf, "ip default-gateway 192.168.128.254") < 1 );
    } elsif ($arg->{'IP'} =~ /^172\.20\./) {
        return -1  if (&$command(\$sw, $prompt_conf, "ip default-gateway 172.20.20.254") < 1 );
    }

    return -1  if (&$command(\$sw, $prompt_conf,	"service timestamps debug uptime" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"service timestamps log datetime localtime" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"service password-encryption" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"clock timezone YKT 5" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"clock summer-time YEKSD recurring last Sun Mar 3:00 last Sun Oct 2:00" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"errdisable recovery cause all" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no ip domain-lookup" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"vtp mode transparent" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no spanning-tree optimize bpdu transmission" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no spanning-tree vlan 1" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"ip telnet source-interface Vlan1" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no ip http server" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no ip http secure-server" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"logging 192.168.128.254" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no cdp run" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"ntp logging" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"ntp server 172.20.20.254 prefer" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"ntp server 192.168.128.254" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"access-list 10 permit 192.168.100.15" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"access-list 10 permit 192.168.100.25" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"access-list 10 permit 192.168.128.253" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"access-list 10 permit 192.168.128.254" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"access-list 10 permit 192.168.100.20" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"access-list 10 permit 192.168.29.80" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"access-list 10 permit 192.168.29.88" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_line,	"line con 0" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_line,	"exec-timeout 60 0" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_line,	"password 7 072E2359442D1B1C11" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_line,	"line vty 0 15" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_line,	"access-class 10 in" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_line,	"exec-timeout 600 0" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_line,	"password 7 06270D34466A0B0003" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_line,	"login local" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_line,	"transport input telnet" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"enable password 0 ".$arg->{'ENA_PASS'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"username ".$arg->{'LOGIN'}." access-class 1 privilege 15 password 0 ".$arg->{'PASS'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"username ".$arg->{'MONLOGIN'}." access-class 1 privilege 3 password 0 ".$arg->{'MONPASS'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"snmp-server community ".$arg->{'ROCOM'}." RO 10" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no shut" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if_range,	"int range Fa0/1 - ".$arg->{'LASTPORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if_range,	"switchport mode access" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if_range,	"switchport access vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if_range,	"switchport protected" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if_range,	"spanning-tree bpdufilter enable" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if_range,	"storm-control action shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if_range,	"storm-control broadcast level pps 128 64" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if_range,	"storm-control multicast level pps 128 64" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if_range,	"no shut" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    if( $arg->{'UPLINKPORT'} == 50 ){
        $arg->{'UPLINKPORT'} = 'Gi0/2'
    }elsif( $arg->{'UPLINKPORT'} == 24 ){
        $arg->{'UPLINKPORT'} = 'Fa0/24'
    }elsif( $arg->{'UPLINKPORT'} == 26 ){
        $arg->{'UPLINKPORT'} = 'Gi0/2'
    }else{
        #
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"int ".$arg->{'UPLINKPORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk encapsulation dot1q" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan 1,".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport protected" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shut" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    return -1  if (&$command(\$sw, $prompt,	"exit" ) < 1 );
    #return -1  if (&$command(\$sw, $prompt,	"wr" ) < 1 );

    $sw->close();
    return 1;
}

sub CATIOSLT_pass_change {
    my $arg = shift;
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => $LIB." Switch '".$arg->{'IP'}."' changed password MANUALLY!!!" );
    return -1;
}

sub CATIOSLT_login {
    my ($swl, $ip, $login, $pass) = @_;
    SWFunc::dlog ( DBUG => 3, SUB => (caller(0))[3], MESS => " IP = ".$ip.", LOGIN = ".$login.", PASS = ".$pass );
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


sub CATIOSLT_cmd {
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

sub CATIOSLT_fix_vlan {
    # IP LOGIN PASS MAC
    my $arg = shift;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing VLAN in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}."'" );
    my $vlan = 0;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    my @ln = $sw->cmd("show mac-address-table dynamic address ".$arg->{'MAC'});
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

sub CATIOSLT_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my $arg = shift;
    my $port = -1; my $pref; my $index; my $max=3; my $count=0;
    ################
    if ($arg->{'USE_SNMP'}) {
        SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "SNMP FIX PORT in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}.", VLAN '".$arg->{'VLAN'}."'" );
        ($pref, $port, $index ) = SWFunc::SNMP_fix_macport_name($arg);
    ################
    } else {
      my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
      SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing PORT in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}."', VLAN '".$arg->{'VLAN'}."'" );
      while ($count < $max) {
      my @ln = $sw->cmd("show mac-address-table dynamic address ".$arg->{'MAC'}." vlan ".$arg->{'VLAN'});
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
    }
    return ($pref, $port, $index);
}

sub CATIOSLT_conf_save {
#   IP LOGIN PASS ENA_PASS
    my $arg = shift;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SAVING $LIB config in switch '".$arg->{'IP'}."'" );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    
    $sw->print("copy running-config startup-config");
    $sw->waitfor("/\[startup-config\]/");
    return -1  if (&$command(\$sw, $prompt, "" ) < 1 );
    $sw->close();
    return 1;
}

sub CATIOSLT_port_up {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set port UP in '".$arg->{'IP'}."', port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOSLT_port_down {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set port DOWN in '".$arg->{'IP'}."', port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}


sub CATIOSLT_port_defect {
#    IP LOGIN PASS PORT PORTPREF VLAN
    my $arg = shift;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure DEFECT port in '".$arg->{'IP'}."', port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg->{'BLOCK_VLAN'} ) < 1);
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

sub CATIOSLT_port_free {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN
    my $arg = shift;
    return -1 if (not $arg->{'VLAN'});
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure FREE port in '".$arg->{'IP'}."', port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"description FREE PORT!!!" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control multicast level ".$port_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control broadcast level ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control action shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport protected" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub CATIOSLT_speed_char {

    my $arg = shift;
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

sub CATIOSLT_port_trunk {
#   IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my $arg = shift;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure TRUNK port in '".$arg->{'IP'}."', port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    my ($speed, $duplex ) = &$speed_char( $arg );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
    if ($arg->{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk native vlan ".$arg->{'BLOCK_VLAN'} ) < 1);
    } else {
        return -1  if (&$command(\$sw, $prompt_conf_if,     "switchport trunk native vlan ".$arg->{'VLAN'} ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control multicast level ".$trunk_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control broadcast level ".$trunk_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport protected" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}


sub CATIOSLT_port_system {

#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my $arg = shift;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure SYSTEM port in '".$arg->{'IP'}."', port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );
    my ($speed, $duplex ) = &$speed_char( $arg );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    if ($arg->{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg->{'VLAN'} ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk native vlan ".$arg->{'BLOCK_VLAN'} ) < 1);
    } else {
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg->{'VLAN'} ) < 1);
	return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control multicast level ".$trunk_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control broadcast level ".$trunk_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control action shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport protected" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}


sub CATIOSLT_port_setparms {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my $arg = shift;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SET PORT parameters in '".$arg->{'IP'}."', port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );

    my ($speed, $duplex ) = &$speed_char( $arg );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport" ) < 1);
    if ($arg->{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode trunk" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg->{'VLAN'} ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk native vlan ".$arg->{'BLOCK_VLAN'} ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport protected" ) < 1);
    } else {
        return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport mode access" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport access vlan ".$arg->{'VLAN'} ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if,	"no switchport trunk allowed vlan" ) < 1);
        return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport protected" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree bpdufilter enable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control multicast level ".$port_ctl_mcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control broadcast level ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"storm-control action shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed ".$speed ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex ".$duplex ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CATIOSLT_vlan_trunk_add {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my $arg = shift;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "ADD VLAN '".$arg->{'VLAN'}."' in '".$arg->{'IP'}."', trunk port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no shutdown" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"state active" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan add ".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CATIOSLT_vlan_trunk_remove  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my $arg = shift;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN '".$arg->{'VLAN'}."' from '".$arg->{'IP'}."', trunk port ".$arg->{'PORTPREF'}.$arg->{'PORT'} );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"switchport trunk allowed vlan remove ".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub CATIOSLT_vlan_remove  {
#    IP LOGIN PASS VLAN
    my $arg = shift;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN '".$arg->{'VLAN'}."' from '".$arg->{'IP'}."'" );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no vlan ".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

1;
