#!/usr/bin/perl

package ESCtl;

use strict;
no strict qw(refs);

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.12;
@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw(	ES_pass_change ES_conf_first	ES_conf_save	ES_fix_macport
		ES_port_up	ES_port_down	ES_port_defect	ES_port_free	ES_port_setparms
		ES_port_portchannel    ES_port_trunk	ES_port_system
		ES_vlan_trunk_add	ES_vlan_trunk_remove ES_vlan_remove
	    );


my $debug 	= 1;
my $timeout	= 10;
my $timeout_login=5;

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
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "IP = ".$ip.", LOGIN = '".$login."'" );
    sleep(1);

    ${$swl}=new Net::Telnet (	prompt => $prompt,
                            	Timeout => $timeout_login,
                        	Errmode => 'return',
			    );
    ${$swl}->open($ip);
    ${$swl}->waitfor("/.*ser name.*/");
    ${$swl}->print($login);
    ${$swl}->waitfor("/.*assword.*/");
    ${$swl}->print($pass);
    ${$swl}->waitfor($prompt) || return -1;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Connect user '".$login."' - Ok" );
    return 1;
}

sub ES_start_login {
    my ($swl, $ip) = @_;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "IP = ".$ip.", LOGIN = 'admin'" );
    sleep(1);

    ${$swl}=new Net::Telnet (	prompt => $prompt,
                            	Timeout => $timeout_login,
                        	Errmode => 'return',
			    );
    ${$swl}->open($ip);
    ${$swl}->waitfor("/.*ser name.*/");
    ${$swl}->print("admin");
    ${$swl}->waitfor("/.*assword.*/");
    ${$swl}->print("1234");
    ${$swl}->waitfor($prompt) || return -1;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Connect user 'admin' - Ok" );
    return 1;
}

sub ES_cmd {
    my ($swl, $cmd_prompt, $cmd ) = @_;
    ( my $last_prompt = ${$swl}->last_prompt() ) =~ s/\e7//gs;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => $last_prompt, MESS => $cmd );
    my @lines = map{s/\e7//gs} ${$swl}->cmd(   String  => $cmd,
                                Prompt  => $cmd_prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    ( $last_prompt = ${$swl}->last_prompt() ) =~ s/\e7//gs;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => $last_prompt, NORMA => 1,  MESS => \@lines );
    return 1;
}

sub ES_speed_char {

    sleep(1);
    my $arg = shift;
    my @duplex = ''; $duplex[0] = 'half'; $duplex[1] = 'full';

    my $spd = 'auto';
    if ( $arg->{'SPEED'} =~ /^1(0|00|000)$/ && $arg->{'DUPLEX'} =~ /^(0|1)/ and not $arg->{'AUTONEG'} ) { 
	$spd = $arg->{'SPEED'}."-".$duplex[$arg->{'DUPLEX'}];
    }
    return $spd;
}

sub ES_bw_char {
    my $arg = shift;
    my $dsl = ( $arg->{'DS'} < $bw_min || $arg->{'DS'} > $bw_max ? $bw_unlim : $arg->{'DS'} );
    my $usl = ( $arg->{'US'} < $bw_min || $arg->{'US'} > $bw_max ? $bw_unlim : $arg->{'US'} );
    my $egress =  ( $arg->{'DS'} < $bw_min || $arg->{'DS'} > $bw_max ? 'no' : '' );
    my $ingress = ( $arg->{'US'} < $bw_min || $arg->{'US'} > $bw_max ? 'no' : '' );
    return ( $dsl, $egress, $usl, $ingress );
}

sub ES_hw_char {
    my $arg = shift;
    my $maxhw =     ( $arg->{'MAXHW'} > 0 ? $arg->{'MAXHW'} : 100 );
    my $adm_state = ( $arg->{'MAXHW'} > 0 ? '' 	: 'no ' );
    return ( $maxhw, $adm_state );
}


sub ES_port_set_vlan {

    my ( $swl, $port, $vlan_id, $tag, $trunk ) = @_;
    my $sw = ${$swl};
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "PARMS - ' $port, $vlan_id '" );
    #-----------------------------------------
    my @lnv = $sw->cmd("show vlan \nc");
    $sw->cmd("");
    my %vlan_del = ();
    my  @range = (); my @d = ();
    my $current_vid = 0; my $range_ports = '';
    foreach my $ln (@lnv) {
	#	1     1     Static    330:44:15  Untagged :20-22,24-26
	#	                                 Tagged   :23
	#	2    91     Static    330:44:15  Untagged :
	#	                                 Tagged   :19,21-22,25-26
        if ( $ln =~ /^\s+\d+\s+(\d+)\s+Static\s+\S+\s+Untagged\s+\:(.*)/ and $1 > 1 ) {
	    $current_vid = $1;
	    $range_ports = $2;
	} elsif (  /^\s+Tagged\s+\:(\S+)/ and $current_vid > 1 ) {
	    $range_ports = $1;
	} else {
	    next;
	}
	#5,7-8,23-26
	$range_ports =~ s/\n//;
	@range = split /\,/,$range_ports;
	foreach my $c ( @range ) {
	    if ( $port == $c ) {
		$vlan_del{$current_vid} = 1;
	    } else {
		@d = split /-/,$c;
		for my $e ( $d[0]..$d[1] ) {
		    if ( $port == $e ) {
			$vlan_del{$current_vid} = 1;
		    }
		}
	    }
	}
    }

    return -1  if (&$command(\$sw, $prompt_conf,	"config" ) < 1 );
    if (not $trunk ) {
	foreach my $lnd ( sort keys %vlan_del ) {
	  if ( $lnd != $vlan_id ) {
	    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$lnd ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"forbidden ".$port ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
	  }
	}
    }

    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$vlan_id ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"name Vlan".$vlan_id ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed ".$port ) < 1 );
    if ($tag) {
	return -1 if (&$command(\$sw, $prompt_conf_vlan,"no untagged ".$port ) < 1 );
    } else {
	return -1 if (&$command(\$sw, $prompt_conf_vlan,"untagged ".$port ) < 1 );
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"exit") < 1 );
    #-----------------------------------------
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

}


sub ES_conf_save {
#   IP LOGIN PASS 
    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SAVE config on $LIB switch ".$arg->{'IP'}." ..." );
    my @res = $sw->cmd(	String  =>      "write memory",
			prompt  =>      $prompt,
			Timeout =>      20,
		      );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], NORMA => 1,  MESS => \@res );
    $sw->close();
    return 1;
}


sub ES_conf_first {
#    IP LOGIN PASS UPLINKPORT UPLINKPORTPREF LASTPORT VLAN VLANNAME BWFREE MONLOGIN MONPASS COM_RO COM_RW 
    my $arg = shift;
    # login
    my $sw;
    if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 ) {
	$sw->close();
	return -1  if (&$start_login(\$sw, $arg->{'IP'}) < 1 );
    }
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "REPLACE CONFIG in ES switch '".$arg->{'IP'}."'"  );

    ######## ALL SWITCH conf
    $sw->print("erase running-config interface port-channel 1-".$arg->{'LASTPORT'});
    $sw->waitfor("/.* erase configuration.*/");
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Erasing interfaces config ... "  );
    my @res = $sw->cmd  (	String	=>	"y",
				prompt	=>	$prompt,
				Timeout	=>	20,
			    );
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], NORMA => 1,  MESS => \@res  );
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Erasing VLAN config ... "  );
    my @lnv = $sw->cmd("show vlan \nc");
    $sw->cmd("");
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

    return -1  if (&$command(\$sw, $prompt_conf,	"port-security 1-".$arg->{'LASTPORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"port-security 1-".$arg->{'LASTPORT'}." address-limit 5" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"no logins username ".$arg->{'MONLOGIN'} ) < 1 );

    if ($arg->{'UPLINKPORT'} < 25) {
	return -1  if (&$command(\$sw, $prompt_conf,	"port-security ".$arg->{'UPLINKPORT'}." address-limit 0" ) < 1 );
	return -1  if (&$command(\$sw, $prompt_conf,	"no port-security ".$arg->{'UPLINKPORT'} ) < 1 );
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"no service-control http" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no service-control https" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no service-control ssh" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no service-control ftp" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"snmp-server version v2c" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"snmp-server get-community ".$arg->{'COM_RO'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"snmp-server set-community ".$arg->{'COM_RW'} ) < 1 );
    if ($arg->{'IP'} =~ /^192\.168\.128\./) {
        return -1  if (&$command(\$sw, $prompt_conf, 	"timesync server 192.168.128.254") < 1 );
    } elsif ($arg->{'IP'} =~ /^172\.20\./) {
        return -1  if (&$command(\$sw, $prompt_conf, 	"timesync server 172.20.20.254") < 1 );
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"timesync ntp" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"time timezone 600" ) < 1 );

    # Control vlan
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan 1" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"name Control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"forbidden 1-".$arg->{'LASTPORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    # Switch vlan
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"name ".$arg->{'VLANNAME'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed 1-".$arg->{'LASTPORT'}.",".$arg->{'UPLINKPORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"untagged 1-".$arg->{'LASTPORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	 ) < 1 );

    my $i=0;
    if ( $debug < 2) {
	while ( $i < $arg->{'LASTPORT'} ) {
	    $i += 1;
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$i ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"pvid ".$arg->{'VLAN'} ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit ingress" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit ingress ".$arg->{'BWFREE'} ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit  egress" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit  egress ".$arg->{'BWFREE'} ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit ".$port_ctl_bcast ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"loopguard" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"flow-control" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf_if,	"vlan1q port-isolation" ) < 1 );
	    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
	}
	SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Change admin pass ..." );
	return -1  if (&$command(\$sw, $prompt_conf,	"multi-login" ) < 1 );
	return -1  if (&$command(\$sw, $prompt_conf,	"admin-password ".$arg->{'PASS'}." ".$arg->{'PASS'} ) < 1 );
	SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Change admin pass - Ok" );
    }

######## ADD Logins
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Create ".$arg->{'MONLOGIN'}." login" );
    return -1  if (&$command(\$sw, $prompt_conf,	"multi-login" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"logins username ".$arg->{'MONLOGIN'}." password ".$arg->{'MONPASS'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"logins username ".$arg->{'MONLOGIN'}." privilege 3" ) < 1 );
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Create ".$arg->{'MONLOGIN'}." login - OK" );
    return -1  if (&$command(\$sw, $prompt,	"exit" ) < 1 );

    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Save config ..." );
    @res = $sw->cmd (	String	=>	"write memory",
			prompt	=>	$prompt,
			Timeout	=>	20,
		    );	
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], NORMA => 1,  MESS => \@res );
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Save config - OK" );
    $sw->close();

    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Switch '".$arg->{'IP'}."' is configured successfull!" );
    return 1;
}

sub ES_pass_change {
    my $arg = shift;
#    IP LOGIN PASS ADMINLOGIN ADMINPASS MONLOGIN MONPASS
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "CHANGE PASSWORD's in ES switch '".$arg->{'IP'}."'" );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"multi-login" ) < 1 );

    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Change ADMIN password ..." );
    return -1  if (&$command(\$sw, $prompt_conf,	"admin-password ".$arg->{'PASS'}." ".$arg->{'PASS'} ) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Change ADMIN password - OK" );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Create ".$arg->{'MONLOGIN'}." login ..." );
    return -1  if (&$command(\$sw, $prompt_conf,	"logins username ".$arg->{'MONLOGIN'}." password ".$arg->{'MONPASS'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"logins username ".$arg->{'MONLOGIN'}." privilege 3" ) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Create ".$arg->{'MONLOGIN'}." login - OK" );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );
    
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Save config ..." );
    my @res = $sw->cmd ( String	=>	"write memory",
			prompt	=>	$prompt,
			Timeout	=>	20,
		    ) if not $debug;	
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], NORMA => 1,  MESS => \@res )  if not $debug;
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Save config - OK" );
    $sw->close();
    return 1;
}


sub ES_fix_vlan {
    # IP LOGIN PASS MAC
    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing VLAN in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}."' ..." );

    my $vlan = 0;
    my @ln = $sw->cmd("show mac address-table all PORT" . "\n" x 100 );
    foreach (@ln) {
	#Port      VLAN ID        MAC Address         Type
	#26        1              00:03:42:97:66:a1   Dynamic
        if ( /(\d+)\s+(\d+)\s+(\w\w\:\w\w\:\w\w\:\w\w\:\w\w\:\w\w)\s+Dynamic/ and $3 eq $arg->{'MAC'} ) {
            $vlan = $2+0;
        }
    }
    $sw->close();
    return $vlan;
}


sub ES_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing PORT in switch '".$arg->{'IP'}."', VLAN '".$arg->{'VLAN'}."', MAC '".$arg->{'MAC'}."' ..." );

    my $port = -1; my $pref; my $max=3; my $count=0;
    while ($count < $max) {
	my @ln = $sw->cmd("show mac address-table vlan ".$arg->{'VLAN'});
        foreach (@ln) {
	    #Port      VLAN ID        MAC Address         Type
	    #26        1              00:03:42:97:66:a1   Dynamic
	    #5         366            00:14:38:19:66:7a   Dynamic
            if ( /(\d+)\s+(\d+)\s+(\w\w\:\w\w\:\w\w\:\w\w\:\w\w\:\w\w)\s+Dynamic/ and $3 eq $arg->{'MAC'} ) {
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
    return ($pref, $port);
}

sub ES_port_up {
#    IP LOGIN PASS PORT 
    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set port state UP in switch '".$arg->{'IP'}."', PORT '".$arg->{'PORT'}."' ..." );

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg->{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}


sub ES_port_down {
#    IP LOGIN PASS PORT 
    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set port state DOWN in switch '".$arg->{'IP'}."', PORT '".$arg->{'PORT'}."' ..." );

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg->{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}

sub ES_port_defect {
#    IP LOGIN PASS PORT PORTPREF VLAN
    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure DEFECT PORT '".$arg->{'PORT'}."' in switch '".$arg->{'IP'}."' ..." );

    ES_port_set_vlan( \$sw, $arg->{'PORT'}, $arg->{'BLOCK_VLAN'}, 0, 0 )  if ($arg->{'BLOCK_VLAN'});

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"port-security ".$arg->{'PORT'}." address-limit 5" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no port-security ".$arg->{'PORT'} ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg->{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"pvid ".$arg->{'BLOCK_VLAN'}) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}


sub ES_port_free {

#    IP LOGIN PASS PORT PORTPREF DS US VLAN
    my $arg = shift;
    return -1 if (not $arg->{'VLAN'});
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure FREE PORT '".$arg->{'PORT'}."' in switch '".$arg->{'IP'}."' ..." );

    my ( $ds, $egress, $us, $ingress )  = &$bw_char( $arg );

    ES_port_set_vlan( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, 0, 0 ) if ($arg->{'VLAN'});

    return -1  if (&$command(\$sw, $prompt_conf,	"config" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,        "port-security ".$arg->{'PORT'}." address-limit 5" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,        "port-security ".$arg->{'PORT'} ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg->{'PORT'}) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"pvid ".$arg->{'VLAN'}) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit ".$port_ctl_bcast) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,     $ingress." bandwidth-limit ingress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit  ingress ".$us ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     $egress. " bandwidth-limit egress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit   egress ".$ds ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"flow-control") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed-duplex auto") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive") < 1 );
    #return -1  if (&$command(\$sw, $prompt_conf_if,	"loopguard") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"vlan1q port-isolation" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf,	"exit") < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit") < 1 );
    $sw->close();
    return 1;
}

sub ES_port_trunk {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my $arg = shift;
    return -1 if (not $arg->{'VLAN'});
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure TRUNK PORT '".$arg->{'PORT'}."' in switch '".$arg->{'IP'}."' ..." );

    my $speed = ES_speed_char( $arg );

    ES_port_set_vlan( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, $arg->{'TAG'}, 1 )  if ($arg->{'VLAN'});

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"port-security ".$arg->{'PORT'}." address-limit 0" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no port-security ".$arg->{'PORT'} ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg->{'PORT'} ) < 1 );

    if ($arg->{'TAG'}) {
        #return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$arg->{'BLOCK_VLAN'}) < 1 );
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid 1") < 1 );
    } else {
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$arg->{'VLAN'}) < 1 );
    }
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit 64" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no bmstorm-limit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit    ingress 64" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bandwidth-limit     egress 64" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no bandwidth-limit ingress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no bandwidth-limit  egress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no flow-control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed-duplex ".$speed ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no loopguard") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );
    $sw->close();
    return 1;
}

sub ES_port_system {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure SYSTEM PORT '".$arg->{'PORT'}."' in switch '".$arg->{'IP'}."' ..." );

    my $speed = ES_speed_char( $arg );
    my ( $maxhw, $adm_state ) = &$hw_char( $arg );
    my ( $ds, $egress, $us, $ingress )  = &$bw_char( $arg );

    ES_port_set_vlan( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, $arg->{'TAG'}, 1 )  if ($arg->{'VLAN'});

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );

    if ($arg->{'VLAN'} and $arg->{'TAG'}) {
	return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg->{'BLOCK_VLAN'} ) < 1 );
	return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed ".$arg->{'PORT'} ) < 1 );
	return -1  if (&$command(\$sw, $prompt_conf_vlan,	"untagged ".$arg->{'PORT'} ) < 1 );
	return -1  if (&$command(\$sw, $prompt_conf,		"exit" ) < 1 );
    }

    return -1  if (&$command(\$sw, $prompt_conf,	"port-security ".$arg->{'PORT'}." address-limit ".$maxhw ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	$adm_state." port-security ".$arg->{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg->{'PORT'} ) < 1 );
    if ($arg->{'VLAN'}) {
     if ($arg->{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$arg->{'BLOCK_VLAN'}) < 1 );
     } else {
        return -1  if (&$command(\$sw, $prompt_conf_if, "vlan1q port-isolation") < 1 );
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$arg->{'VLAN'}) < 1 );
     }
    }
#    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit" ) < 1 );
#    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit ".$trunk_ctl_bcast ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,     $ingress." bandwidth-limit ingress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit  ingress ".$us ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     $egress. " bandwidth-limit egress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit   egress ".$ds ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"flow-control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed-duplex ".$speed ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no loopguard") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}


sub ES_port_setparms {
#    IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX UPLINKPORT

    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SET PARAMETERS port '".$arg->{'PORT'}."' in switch '".$arg->{'IP'}."' ..." );

    my $speed = ES_speed_char( $arg );
    my ( $maxhw, $adm_state ) = &$hw_char( $arg );
    my ( $ds, $egress, $us, $ingress )  = &$bw_char( $arg );

    ES_port_set_vlan( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, $arg->{'TAG'}, 0 )  if ($arg->{'VLAN'});

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    if ($arg->{'VLAN'} and $arg->{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_vlan,       "vlan ".$arg->{'BLOCK_VLAN'} ) < 1 );
        return -1  if (&$command(\$sw, $prompt_conf_vlan,       "fixed ".$arg->{'PORT'} ) < 1 );
        return -1  if (&$command(\$sw, $prompt_conf_vlan,       "untagged ".$arg->{'PORT'} ) < 1 );
        return -1  if (&$command(\$sw, $prompt_conf,            "exit" ) < 1 );
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"port-security ".$arg->{'PORT'}." address-limit ".$maxhw ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	$adm_state." port-security ".$arg->{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface port-channel ".$arg->{'PORT'} ) < 1 );
    if ($arg->{'VLAN'}) {
     if ($arg->{'TAG'}) {
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$arg->{'BLOCK_VLAN'}) < 1 );
     } else {
        return -1  if (&$command(\$sw, $prompt_conf_if, "vlan1q port-isolation") < 1 );
        return -1  if (&$command(\$sw, $prompt_conf_if, "pvid ".$arg->{'VLAN'}) < 1 );
     }
    }

    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"bmstorm-limit ".$port_ctl_bcast ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,     $ingress." bandwidth-limit ingress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     $egress. " bandwidth-limit egress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit  ingress ".$us ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     "bandwidth-limit   egress ".$ds ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     $ingress." bandwidth-limit ingress" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,     $egress. " bandwidth-limit egress" ) < 1 );

    return -1  if (&$command(\$sw, $prompt_conf_if,	"flow-control" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed-duplex ".$speed ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no inactive") < 1 );
#    return -1  if (&$command(\$sw, $prompt_conf_if,	"loopguard") < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}


sub ES_vlan_trunk_add  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "ADD VLAN in TRUNK PORT '".$arg->{'PORT'}."', switch '".$arg->{'IP'}."' ..." );

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no untagged ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}

sub ES_vlan_trunk_remove  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN from TRUNK PORT '".$arg->{'PORT'}."', switch '".$arg->{'IP'}."' ..." );

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"forbidden ".$arg->{'PORTPREF'}.$arg->{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );
    $sw->close();
    return 1;
}


sub ES_vlan_remove  {
#    IP LOGIN PASS VLAN
    my $arg = shift;
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'LOGIN'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN from switch '".$arg->{'IP'}."' ..." );

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no vlan ".$arg->{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}

1;
