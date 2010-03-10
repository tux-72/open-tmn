#!/usr/bin/perl

package GSCtl;

use strict;
no strict qw(refs);

#use Net::SNMP;
#use locale;
use SWALLCtl;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.07;
@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw( GS_fix_vlan GS_fix_macport GS_conf_save GS_vlan_trunk_add GS_vlan_trunk_remove GS_vlan_remove
	    );

my $debug 	= 1;
my $timeout	= 5;


my $LIB	= 'GS';
my $command     = $LIB."_cmd";
my $login       = $LIB."_login";

my $prompt='/.*[\>#]/';
my $prompt_conf ='/.*\(config\)#.*/';
my $prompt_conf_if ='/.*\(config\-interface\)#.*/';
my $prompt_conf_vlan ='/.*\(config\-vlan\)#.*/';

#my $block_vlan=4094;
# percent supression broadcast
#my $trunk_ctl_bcast     = 512;
#my $port_ctl_bcast      = 128;

#my $bw_min	= 0;
#my $bw_max	= 99999;
#my $bw_unlim	= 64;

############ SUBS ##############

sub GS_login {
    my ($swl, $ip, $login, $pass) = @_;
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => " IP = ".$ip.", LOGIN =".$login );
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
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Connect user '".$login."' - Ok" );
    return 1;
}

sub GS_cmd {
    my ($swl, $cmd_prompt, $cmd ) = @_;
    dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => ${$swl}->last_prompt(), MESS => $cmd );
    my @lines = ${$swl}->cmd(   String  => $cmd,
                                Prompt  => $cmd_prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
                            );
    dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => ${$swl}->last_prompt(), NORMA => 1,  MESS => \@lines );
    return 1;
}

sub GS_conf_save {
#   IP LOGIN PASS 
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SAVE config in GS switch '".$arg{'IP'}."'..." );
    my @res = $sw->cmd(	String  =>      "write memory",
			prompt  =>      $prompt,
			Timeout =>      20,
		      );
    dlog ( DBUG => 1, SUB => (caller(0))[3], NORMA => 1,  MESS => \@res );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SAVE config in GS switch '".$arg{'IP'}."' - OK " );
    $sw->close();
    return 1;
}

sub GS_fix_vlan {
    # IP LOGIN PASS MAC
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing VLAN in switch '".$arg{'IP'}."', MAC '".$arg{'MAC'}."' ..." );

    my $vlan = 0;
    my @ln = $sw->cmd("show mac address-table all PORT" );
    foreach (@ln) {
	#Port      VLAN ID        MAC Address         Type
	#26        1              00:03:42:97:66:a1   Dynamic
        if ( /(\d+)\s+(\d+)\s+(\w\w\:\w\w\:\w\w\:\w\w\:\w\w\:\w\w)\s+\S+/ and $3 eq $arg{'MAC'} ) {
            $vlan = $2+0;
        }
    }
    $sw->close();
    return $vlan;
}



sub GS_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "Fixing PORT in switch '".$arg{'IP'}."', VLAN '".$arg{'VLAN'}."', MAC '".$arg{'MAC'}."' ..." );

    my $port = -1; my $pref; my $max=3; my $count=0;
    while ($count < $max) {
	my @ln = $sw->cmd("show mac address-table all VID" );
	foreach (@ln) {
	    #Port      VLAN ID        MAC Address         Type
	    #26        1              00:03:42:97:66:a1   Dynamic
    	    if ( /(\d+)\s+(\d+)\s+(\w\w\:\w\w\:\w\w\:\w\w\:\w\w\:\w\w)\s+\S+/ and $2 eq $arg{'VLAN'} and $3 eq $arg{'MAC'} ) {
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
    print STDERR "MAC Port - $port\n" if $debug > 1;
    return ($pref, $port);
}


sub GS_vlan_trunk_add  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "ADD VLAN in TRUNK PORT '".$arg{'PORT'}."', switch '".$arg{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"fixed ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"no untagged ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}

sub GS_vlan_trunk_remove  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN from TRUNK PORT '".$arg{'PORT'}."', switch '".$arg{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_vlan,	"forbidden ".$arg{'PORT'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );
    $sw->close();
    return 1;
}


sub GS_vlan_remove  {
#    IP LOGIN PASS VLAN
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN from switch '".$arg{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf,	"configure" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"no vlan ".$arg{'VLAN'} ) < 1 );
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1 );

    $sw->close();
    return 1;
}

1;
