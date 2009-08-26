#!/usr/bin/perl

package ESCtl;

#use strict;
#use Net::SNMP;
#use locale;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.07;
@ISA = qw(Exporter);

@EXPORT_OK = qw();
@EXPORT_TAGS = ();

@EXPORT = qw(	ES_pass_change ES_conf_first	ES_conf_save	ES_fix_macport
		ES_port_up	ES_port_down	ES_port_defect	ES_port_free	ES_port_setparms
		ES_port_portchannel    ES_port_trunk	ES_port_system
		ES_vlan_trunk_add	ES_vlan_trunk_remove ES_vlan_remove
	    );


my $debug 	= 1;
my $timeout	= 10;

my $block_vlan=4094;

my $LIB	= 'ES';
my $command     = $LIB."_cmd";
my $login       = $LIB."_login";
my $start_login = $LIB."_start_login";
my $speed_char  = $LIB."_speed_char";
my $bw_char	= $LIB."_bw_char";
my $hw_char	= $LIB."_hw_char";

my $prompt='/.*[\>#]/';
my $prompt_conf ='/.*\(config\)#.*/';
my $prompt_conf_if ='/.*\(config\-interface\)#.*/';
my $prompt_conf_vlan ='/.*\(config\-vlan\)#.*/';

# percent supression broadcast
my $trunk_ctl_bcast     = 512;
my $port_ctl_bcast      = 128;

my $bw_min	= 0;
my $bw_max	= 99999;
my $bw_unlim	= 64;

############ SUBS ##############

sub ES_login {
    my ($swl, $ip, $login, $pass) = @_;
    print STDERR " IP = ".$ip.", LOGIN =".$login." \n" if $debug > 1;
    sleep(1);

    ${$swl}=new Net::Telnet (	prompt => $prompt,
                            	Timeout => $timeout,
                        	Errmode => 'return',
			    );
    ${$swl}->open($ip);
    ${$swl}->waitfor("/.*ser name.*/");
    ${$swl}->print($login);
    ${$swl}->waitfor("/.*assword.*/");
    ${$swl}->print($pass);
    ${$swl}->waitfor($prompt) || return -1;
    print STDERR "Connect user '".$login."' - Ok\n" if $debug > 1;
    return 1;
}

sub ES_start_login {
    my ($swl, $ip) = @_;
    print STDERR " IP = ".$ip.", LOGIN =".$login.", PASS = ".$pass." \n" if $debug > 1;
    sleep(1);

    ${$swl}=new Net::Telnet (	prompt => $prompt,
                            	Timeout => $timeout,
                        	Errmode => 'return',
			    );
    ${$swl}->open($ip);
    ${$swl}->waitfor("/.*ser name.*/");
    ${$swl}->print("admin");
    ${$swl}->waitfor("/.*assword.*/");
    ${$swl}->print("1234");
    ${$swl}->waitfor($prompt) || return -1;
    print STDERR "Connect user admin - Ok\n" if $debug > 1;
    return 1;
}

sub ES_cmd {
    my ($swl, $cmd_prompt, $cmd ) = @_;
    my @lines = ${$swl}->cmd(   String  => $cmd,
                                Prompt  => $cmd_prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    if ($debug) {
        print STDERR "\n>>> CMD '".$cmd."'\n>>> PRT '".${$swl}->last_prompt()."'\n";
        print STDERR @lines;
	print STDERR "\n";
    }
    return 1;
}

sub ES_speed_char {

    sleep(1);
    my %arg = (
        @_,         # список пар аргументов
    );
    my @duplex = ''; $duplex[0] = 'half'; $duplex[1] = 'full';

    my $spd = 'auto';
    if ( $arg{'SPEED'} =~ /^1(0|00|000)/ && $arg{'DUPLEX'} =~ /^(0|1)/ and not $arg{'AUTONEG'} ) { 
	$spd = $arg{'SPEED'}."-".$duplex[$arg{'DUPLEX'}];
    }
    return $spd;
}

sub ES_bw_char {
    my %arg = (
        @_,
    );
    my $dsl = ( $arg{'DS'} < $bw_min || $arg{'DS'} > $bw_max ? $bw_unlim : $arg{'DS'} );
    my $usl = ( $arg{'US'} < $bw_min || $arg{'US'} > $bw_max ? $bw_unlim : $arg{'US'} );
    my $egress =  ( $arg{'DS'} < $bw_min || $arg{'DS'} > $bw_max ? 'no' : '' );
    my $ingress = ( $arg{'US'} < $bw_min || $arg{'US'} > $bw_max ? 'no' : '' );
    return ( $dsl, $egress, $usl, $ingress );
}

sub ES_hw_char {
    my %arg = (
        @_,
    );
    my $maxhw =     ( $arg{'MAXHW'} > 0 ? $arg{'MAXHW'} : 100 );
    my $adm_state = ( $arg{'MAXHW'} > 0 ? '' 	: 'no ' );
    return ( $maxhw, $adm_state );
}


sub ES_conf_save {
#   IP LOGIN PASS 
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "SAVE config in ES switch '".$arg{'IP'}."'...\n"; # if $debug;
    my @res = $sw->cmd(	String  =>      "write memory",
			prompt  =>      $ES_prompt,
			Timeout =>      20,
		      ) if not $debug; print @res;
    print STDERR " - OK!\n";
    $sw->close();
    return 1;
}


sub ES_conf_first {
#    IP LOGIN PASS UPLINKPORT UPLINKPORTPREF LASTPORT VLAN VLANNAME BWFREE MONLOGIN MONPASS COM_RO COM_RW 
    my %arg = (
        @_,
    );
    # login
    my $sw;
    if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 ) {
	$sw->close();
	return -1  if (&$start_login(\$sw, $arg{'IP'}) < 1 );
    }
    
    print STDERR "REPLACE CONFIG in ES switch '".$arg{'IP'}."'...\n" if $debug;

    ######## ALL SWITCH conf
    if ( $debug < 2) {
	$sw->print("erase running-config interface port-channel 1-".$arg{'LASTPORT'});
	$sw->waitfor("/.* erase configuration.*/");
	print STDERR "Erasing config ... \n";
	my @res = $sw->cmd  (	String	=>	"y",
				prompt	=>	$prompt,
				Timeout	=>	20,
			    ); print @res;
    }
# ---------------------------------------------
    my @lnv = $sw->cmd("show vlan \nc");
    $sw->cmd("");
    #print STDERR @lnv;
    my $count = -1;
    my @lnd = ();
    foreach my $ln (@lnv) {
	#    27  1058     Static     15:36:11  Untagged :
        if ( $ln =~ /^\s+\d+\s+(\d+)\s+Static\s+/ and $1 > 1 ) {
	    $count +=1;
	    $lnd[$count] = $1;
	}
    }

    return -1  if (&$command(\$sw, $prompt_conf,	"config" ) < 1 );
    foreach my $lnd (@lnd) {
	return -1  if (&$command(\$sw, $prompt_conf,	"no vlan ".$lnd ) < 1 );
    }
# ---------------------------------------------
    return -1  if (&$command(\$sw, $prompt_conf,	"storm-control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"bandwidth-control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"loopguard" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"ethernet oam" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan1q port-isolation" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"port-security 1-".$arg{'LASTPORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"port-security 1-".$arg{'LASTPORT'}." address-limit 5" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"no logins username ".$arg{'MONLOGIN'} ) < 1 );

    if ($arg{'UPLINKPORT'} < 25) {
	return -1  if (&$command(\$sw, $prompt_conf,	"port-security ".$arg{'UPLINKPORT'}." address-limit 0" ) < 1 );
	return -1  if (&$command(\$sw, $prompt_conf,	"no port-security ".$arg{'UPLINKPORT'} ) < 1 );
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"no service-control http" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no service-control https" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no service-control ssh" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no service-control ftp" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"snmp-server version v2c" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"snmp-server get-community ".$arg{'COM_RO'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"snmp-server set-community ".$arg{'COM_RW'} ) < 1 );
    if ($arg{'IP'} =~ /^192\.168\.128\./) {
        return -1  if (&$command(\$sw, $prompt_conf, 	"timesync server 192.168.128.254") < 1 );
    } elsif ($arg{'IP'} =~ /^172\.20\./) {
        return -1  if (&$command(\$sw, $prompt_conf, 	"timesync server 172.20.20.254") < 1 );
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"timesync ntp" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"time timezone 600" ) < 1 );

    # Control vlan
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan 1" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"name Control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"forbidden 1-".$arg{'LASTPORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    # Switch vlan
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"name ".$arg{'VLANNAME'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed 1-".$arg{'LASTPORT'}.",".$arg{'UPLINKPORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"untagged 1-".$arg{'LASTPORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	 ) < 1 );

    my $i=0;
    if ( $debug < 2) {
	while ( $i < $arg{'LASTPORT'} ) {
	    $i += 1;
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$i ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"pvid ".$arg{'VLAN'} ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit ingress" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit ingress ".$arg{'BWFREE'} ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit  egress" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit  egress ".$arg{'BWFREE'} ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit ".$port_ctl_bcast ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"loopguard" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"flow-control" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"vlan1q port-isolation" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
	}
	print STDERR "Change admin pass\n";
	return -1  if (&$command(\$sw, $prompt_conf,	"multi-login" ) < 1 );
	return -1  if (&$command(\$sw, $prompt_conf,	"admin-password ".$arg{'PASS'}." ".$arg{'PASS'} ) < 1 );
	print STDERR " - Ok!\n";
    }

######## ADD Logins
    print STDERR "Create ".$arg{'MONLOGIN'}." login\n";
    return -1  if (&$command(\$sw, $prompt_conf,	"multi-login" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"logins username ".$arg{'MONLOGIN'}." password ".$arg{'MONPASS'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"logins username ".$arg{'MONLOGIN'}." privilege 3" ) < 1 );
    print STDERR " - OK!\n";

    return -1  if (&$command(\$sw, $prompt,	"exit" ) < 1 );

    print STDERR "Save config ... \n" ;
    @res = $sw->cmd (	String	=>	"write memory",
			prompt	=>	$prompt,
			Timeout	=>	20,
		    );	print @res;
    print STDERR " - OK!\n";

    $sw->close();
    print STDERR "Switch '".$arg{'IP'}."' is configured successfull!\n";
    return 1;
}

sub ES_pass_change {
#    IP LOGIN PASS ADMINLOGIN ADMINPASS MONLOGIN MONPASS
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "CHANGE PASSWORD's in ES switch '".$arg{'IP'}."'...\n" if $debug;
    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"multi-login" ) < 1 );
    print STDERR "Change admin pass\n";
    return -1  if (&$command(\$sw, $prompt_conf,	"admin-password ".$arg{'PASS'}." ".$arg{'PASS'} ) < 1 );
    print STDERR "Create ".$arg{'MONLOGIN'}." login\n";
    return -1  if (&$command(\$sw, $prompt_conf,	"logins username ".$arg{'MONLOGIN'}." password ".$arg{'MONPASS'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"logins username ".$arg{'MONLOGIN'}." privilege 3" ) < 1 );
    print STDERR " - Ok!\n";
    print STDERR "Create ban login\n";
    return -1  if (&$command(\$sw, $prompt_conf,	"logins username ban password ".$arg{'ADMINPASS'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"logins username ".$arg{'MONLOGIN'}." privilege 14" ) < 1 );
    print STDERR " - Ok!\n";
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );
    
    print STDERR "Save config ...\n" ;
    my @res = $sw->cmd(	String  =>      "write memory",
			prompt  =>      $prompt,
			Timeout =>      20
		      ) if not $debug; print @res;
    print STDERR " - OK!\n";
    $sw->close();
    return 1;
}


sub ES_fix_vlan {
    # IP LOGIN PASS MAC
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );

    print STDERR "Fixing VLAN in switch '".$arg{'IP'}."', MAC '".$arg{'MAC'}."' ...\n" if $debug;
    my $vlan = 0;
    my @ln = $sw->cmd("show mac address-table all PORT" . "\n" x 100 );
    foreach (@ln) {
	#Port      VLAN ID        MAC Address         Type
	#26        1              00:03:42:97:66:a1   Dynamic
        if ( /(\d+)\s+(\d+)\s+(\w\w\:\w\w\:\w\w\:\w\w\:\w\w\:\w\w)\s+Dynamic/ and $3 eq $arg{'MAC'} ) {
            $vlan = $2+0;
        }
    }
    $sw->close();
    return $vlan;
}


sub ES_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "Fixing PORT in switch '".$arg{'IP'}."', VLAN '".$arg{'VLAN'}."', MAC '".$arg{'MAC'}."' ...\n" if $debug;

    my $port = 0; my $pref; my $max=3; my $count=0;
    while ($count < $max) {
	my @ln = $sw->cmd("show mac address-table vlan ".$arg{'VLAN'});
        foreach (@ln) {
	    #Port      VLAN ID        MAC Address         Type
	    #26        1              00:03:42:97:66:a1   Dynamic
	    #5         366            00:14:38:19:66:7a   Dynamic
            if ( /(\d+)\s+(\d+)\s+(\w\w\:\w\w\:\w\w\:\w\w\:\w\w\:\w\w)\s+Dynamic/ and $3 eq $arg{'MAC'} ) {
                $port = $1+0;
            }
        }
        if ($port>0) {
            last;
        } else {
            $count+=1;
        }
    }
    $sw->close();
    print STDERR "MAC Port - $port\n" if $debug;
    return ($pref, $port);
}

sub ES_port_up {
#    IP LOGIN PASS PORT 
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "Set port state UP in switch '".$arg{'IP'}."', PORT '".$arg{'PORT'}."' ...\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}


sub ES_port_down {
#    IP LOGIN PASS PORT 
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "Set port state DOWN in switch '".$arg{'IP'}."', PORT '".$arg{'PORT'}."' ...\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}

sub ES_port_defect {
#    IP LOGIN PASS PORT PORTPREF VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "Configure DEFECT PORT '".$arg{'PORT'}."' in switch '".$arg{'IP'}."' ...\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"port-security ".$arg{'PORT'}." address-limit 5" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no port-security ".$arg{'PORT'} ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"untagged ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"pvid ".$arg{'VLAN'}) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}

sub ES_port_free {

#    IP LOGIN PASS PORT PORTPREF DS US VLAN
    my %arg = (
        @_,
    );
    return -1 if (not $arg{'VLAN'});
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "Configure FREE PORT '".$arg{'PORT'}."' in switch '".$arg{'IP'}."' ...\n" if $debug;

    my ( $ds, $egress, $us, $ingress )  = &$bw_char( DS => $arg{'DS'}, US => $arg{'US'} );

#-----------------------------------------
    my @lnv = $sw->cmd("show vlan \nc");
    $sw->cmd("");
    #print STDERR @lnv;
    my $count = -1;
    my @lnd = ();
    foreach my $ln (@lnv) {
	#    27  1058     Static     15:36:11  Untagged :
        if ( $ln =~ /^\s+\d+\s+(\d+)\s+Static\s+/ and $1 > 1 ) {
	    $count +=1;
	    $lnd[$count] = $1;
	}
    }

    return -1  if (&$command(\$sw, $prompt_conf,	"config" ) < 1 );
    foreach my $lnd (@lnd) {
	return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$lnd ) < 1 );
	return -1  if (&$command(\$sw, $prompt_conf_vlan,	"forbidden ".$arg{'PORT'} ) < 1 );
	return -1  if (&$command(\$sw, $prompt_conf,		"exit" ) < 1 );
    }
#-----------------------------------------


    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"untagged ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,        "port-security ".$arg{'PORT'}." address-limit 5" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,        "port-security ".$arg{'PORT'} ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg{'PORT'}) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"pvid ".$arg{'VLAN'}) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit ".$port_ctl_bcast) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,     $ingress." bandwidth-limit ingress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit  ingress ".$us ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     $egress. " bandwidth-limit egress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit   egress ".$ds ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"flow-control") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed-duplex auto") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"loopguard") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"vlan1q port-isolation" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"exit") < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit") < 1 );
    $sw->close();
    return 1;
}

sub ES_port_trunk {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    return -1 if (not $arg{'VLAN'});
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "Configure DEFECT PORT '".$arg{'PORT'}."' in switch '".$arg{'IP'}."' ...\n" if $debug;
    my $speed = ES_speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"port-security ".$arg{'PORT'}." address-limit 0" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no port-security ".$arg{'PORT'} ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"name Control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed ".$arg{'PORT'} ) < 1 );
    if ($arg{'TAG'}) {
	return -1 if (&$command(\$sw, $prompt_conf_vlan,"no untagged ".$arg{'PORT'} ) < 1 );
    } else {
	return -1 if (&$command(\$sw, $prompt_conf_vlan,"untagged ".$arg{'PORT'} ) < 1 );
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg{'PORT'} ) < 1 );

    if (not $arg{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$arg{'VLAN'}) < 1 );
    } else {
        #return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$block_vlan) < 1 );
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid 1") < 1 );
    }

    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit ".$trunk_ctl_bcast ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit    ingress 64" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit     egress 64" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no bandwidth-limit ingress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no bandwidth-limit  egress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no flow-control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed-duplex ".$speed ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"loopguard") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );
    $sw->close();
    return 1;
}

sub ES_port_system {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "Configure SYSEM PORT '".$arg{'PORT'}."' in switch '".$arg{'IP'}."' ...\n" if $debug;

    my $speed = ES_speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});
    my ( $maxhw, $adm_state ) = &$hw_char( MAXHW => $arg{'MAXHW'} );
    my ( $ds, $egress, $us, $ingress )  = &$bw_char( DS => $arg{'DS'}, US => $arg{'US'} );

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"port-security ".$arg{'PORT'}." address-limit ".$maxhw ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	$adm_state." port-security ".$arg{'PORT'} ) < 1 );
    if ($arg{'VLAN'}) {
     return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
     return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed ".$arg{'PORT'} ) < 1 );
     if ($arg{'TAG'}) {
	return -1 if (&$command(\$sw, $prompt_conf_vlan,"no untagged ".$arg{'PORT'} ) < 1 );
     } else {
	return -1 if (&$command(\$sw, $prompt_conf_vlan,"untagged ".$arg{'PORT'} ) < 1 );
     }
     return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    }

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg{'PORT'} ) < 1 );
    if ($arg{'VLAN'}) {
     if (not $arg{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_if, "vlan1q port-isolation") < 1 );
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$arg{'VLAN'}) < 1 );
     } else {
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$block_vlan) < 1 );
     }
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit ".$trunk_ctl_bcast ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,     $ingress." bandwidth-limit ingress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit  ingress ".$us ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     $egress. " bandwidth-limit egress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit   egress ".$ds ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"flow-control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed-duplex ".$speed ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"loopguard") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}


sub ES_port_setparms {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX UPLINKPORT

    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "SET PARAMETERS in PORT '".$arg{'PORT'}."', switch '".$arg{'IP'}."' ...\n" if $debug;

    my $speed = ES_speed_char(SPEED => $arg{'SPEED'}, DUPLEX => $arg{'DUPLEX'}, AUTONEG => $arg{'AUTONEG'});
    my ( $maxhw, $adm_state ) = &$hw_char( MAXHW => $arg{'MAXHW'} );
    my ( $ds, $egress, $us, $ingress )  = &$bw_char( DS => $arg{'DS'}, US => $arg{'US'} );
    print STDERR "BW - DS $egress $ds, US $ingress $us \n" if $debug; 

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"port-security ".$arg{'PORT'}." address-limit ".$maxhw ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	$adm_state." port-security ".$arg{'PORT'} ) < 1 );

    if ($arg{'VLAN'}) {
     return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
     return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed ".$arg{'PORT'} ) < 1 );
     if ($arg{'TAG'}) {
	return -1 if (&$command(\$sw, $prompt_conf_vlan,"no untagged ".$arg{'PORT'} ) < 1 );
     } else {
	return -1 if (&$command(\$sw, $prompt_conf_vlan,"untagged ".$arg{'PORT'} ) < 1 );
     }
     return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    }

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg{'PORT'} ) < 1 );
    if ($arg{'VLAN'}) {
     if (not $arg{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_if, "vlan1q port-isolation") < 1 );
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$arg{'VLAN'}) < 1 );
     } else {
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$block_vlan) < 1 );
     }
    }

    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit ".$port_ctl_bcast ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,     $ingress." bandwidth-limit ingress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit  ingress ".$us ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     $egress. " bandwidth-limit egress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit   egress ".$ds ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"flow-control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed-duplex ".$speed ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"loopguard") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}


sub ES_vlan_trunk_add  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "ADD VLAN in TRUNK PORT '".$arg{'PORT'}."', switch '".$arg{'IP'}."' ...\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no untagged ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}

sub ES_vlan_trunk_remove  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "REMOVE VLAN from TRUNK PORT '".$arg{'PORT'}."', switch '".$arg{'IP'}."' ...\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"forbidden ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );
    $sw->close();
    return 1;
}


sub ES_vlan_remove  {
#    IP LOGIN PASS VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "REMOVE VLAN from switch '".$arg{'IP'}."' ...\n" if $debug;

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}

1;
