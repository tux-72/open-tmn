#!/usr/bin/perl

package C73Ctl;

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
		#----------------------------------- LINK TYPES	----------------------------------
		#	21		22		23		25		26
@EXPORT = qw(	C73_term_l3net4_add C73_term_l3net4_remove C73_term_l3net4_up C73_term_l3net4_down 
		C73_conf_save
	    );

my $debug=1;

my $LIB='C73';
my $command     = $LIB."_cmd";
my $login       = $LIB."_login";
#my $speed_char	= $LIB."_speed_char";

my $timeout=3;
my $prompt='/.*[\>#].*/';
my $prompt_conf ='/.*\(config\)#.*/';
my $prompt_conf_if ='/.*\(config\-if\)#.*/';
my $prompt_conf_subif ='/.*\(config\-subif\)#.*/';

# percent supression multicast and broadcast
#my $trunk_ctl_mcast     = 1;    my $trunk_ctl_bcast     = 10;
#my $port_ctl_mcast      = 1;    my $port_ctl_bcast      = 2;

############ SUBS ##############



sub C73_login {
    my ($swl, $ip, $login, $pass, $ena_pass) = @_;
    print STDERR " IP = ".$ip.", LOGIN = ".$login.", PASS = ".$pass.", ENA_PASS =".$ena_pass." \n" if $debug > 1 ;
    ${$swl}=new Net::Telnet (   prompt => $prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    ${$swl}->open($ip);
    ${$swl}->login($login,$pass) || return -1;
    ${$swl}->print("ena");
    ${$swl}->waitfor("/.*assword.*/");
    ${$swl}->print($ena_pass);
    ${$swl}->waitfor($prompt) || return -1;
    print STDERR "Connect user - Ok\n" if $debug > 1;
    return 1;
}


sub C73_cmd {
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

sub C73_conf_save {
#   IP LOGIN PASS ENA_PASS
    my %arg = (
        @_,
    );
    print STDERR "SAVING $LIB config in router ".$arg{'IP'}." ...\n" if $debug > 1;
    # login
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    if ($debug < 2) {
        $sw->print("copy runn startup");
        $sw->waitfor("/\[startup-config\]/");
        return -1  if ( &$command(\$sw, $prompt, "\n" ) < 1 );
    } else {
        print STDERR $LIB."_conf_save function not running in DEBUG mode\n";
    }
    $sw->close();
    return 1;
}


sub C73_term_l3net4_add {
    my %arg = (
        @_,
    );
    # IP LOGIN PASS ENA_PASS IFACE VLAN VLANNAME IPGW NETMASK UP_ACLIN UP_ACLOUT
    print STDERR "ADD Transport Net Iface in router ".$arg{'IP'}." ...\n" if $debug;
    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "interface ".$arg{'IFACE'}.'.'.$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "description ".$arg{'VLANNAME'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "encapsulation dot1Q ".$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip address ".$arg{'IPGW'}." ".$arg{'NETMASK'} ) < 1);
     if ( defined($arg{'UP_ACLIN'})  ) { return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip access-group ".$arg{'UP_ACLIN'}. " in"  ) < 1); }
     if ( defined($arg{'UP_ACLOUT'}) ) { return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip access-group ".$arg{'UP_ACLOUT'}." out" ) < 1); }
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip redirects" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip unreachables" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip proxy-arp" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip route-cache" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}

sub C73_term_l3net4_remove {

    my %arg = (
        @_,
    );
    # IP LOGIN PASS ENA_PASS IFACE VLAN 
    print STDERR "REMOVE Transport Net Iface in router ".$arg{'IP'}." ...\n" if $debug;

    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "interface ".$arg{'IFACE'}.'.'.$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip redirects" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip unreachables" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip proxy-arp" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip route-cache" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip access-group in"  ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip access-group out" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip address") < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no encapsulation dot1Q" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no description ") < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "no interface ".$arg{'IFACE'}.'.'.$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}


sub C73_term_l3net4_down {
    my %arg = (
        @_,
    );
    # IP LOGIN PASS ENA_PASS IFACE VLAN DOWN_ACLIN DOWN_ACLOUT
    print STDERR "BLOCK Transport Net Iface in router ".$arg{'IP'}." ...\n" if $debug;

    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "interface ".$arg{'IFACE'}.'.'.$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip access-group in"  ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip access-group out" ) < 1);
     if ( defined($arg{'DOWN_ACLIN'})  ) { return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip access-group ".$arg{'DOWN_ACLIN'}. " in"  ) < 1); }
     if ( defined($arg{'DOWN_ACLOUT'}) ) { return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip access-group ".$arg{'DOWN_ACLOUT'}." out" ) < 1); }
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no shutdown"  ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}

sub C73_term_l3net4_up {

    my %arg = (
        @_,
    );
    # IP LOGIN PASS ENA_PASS IFACE VLAN UP_ACLIN UP_ACLOUT
    print STDERR "UNBLOCK Transport Net Iface in router ".$arg{'IP'}." ...\n" if $debug;

    my $sw; return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}, $arg{'ENA_PASS'}) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,      "conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "interface ".$arg{'IFACE'}.'.'.$arg{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip access-group in"  ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no ip access-group out" ) < 1);
     if ( defined($arg{'UP_ACLIN'})  ) { return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip access-group ".$arg{'UP_ACLIN'}. " in"  ) < 1); }
     if ( defined($arg{'UP_ACLOUT'}) ) { return -1  if (&$command(\$sw, $prompt_conf_subif,   "ip access-group ".$arg{'UP_ACLOUT'}." out" ) < 1); }
    return -1  if (&$command(\$sw, $prompt_conf_subif,   "no shutdown"  ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,      "exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,           "exit" ) < 1);
    $sw->close();
    return 1;
}

1;
