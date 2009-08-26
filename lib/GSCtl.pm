#!/usr/bin/perl

package GSCtl;

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

@EXPORT = qw(	GS_fix_vlan	GS_conf_save	GS_vlan_trunk_add	GS_vlan_trunk_remove	GS_vlan_remove
	    );

my $debug 	= 2;
my $timeout	= 10;


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
    print STDERR " IP = ".$ip.", LOGIN =".$login.", PASS = ".$pass." \n" if $debug > 1;
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

sub GS_cmd {
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


sub GS_conf_save {
#   IP LOGIN PASS 
    my %arg = (
        @_,
    );
    # login
    my $sw;  return -1  if (&$login(\$sw, $arg{'IP'}, $arg{'LOGIN'}, $arg{'PASS'}) < 1 );
    print STDERR "SAVE config in GS switch '".$arg{'IP'}."'...\n"; # if $debug;
    my @res = $sw->cmd(	String  =>      "write memory",
			prompt  =>      $GS_prompt,
			Timeout =>      20,
		      ) if not $debug; print @res;
    print STDERR " - OK!\n";
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

sub GS_vlan_trunk_add  {
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

sub GS_vlan_trunk_remove  {
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


sub GS_vlan_remove  {
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
