#!/usr/bin/perl

package BPSCtl;

use strict;
no strict qw(refs);

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use Net::Telnet();

$VERSION = 1.13;
@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

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

#my $block_vlan=4094;
my $prompt='/.*[\>#].*/';
my $prompt_conf ='/.*\(config\)#.*/';
my $prompt_conf_if ='/.*\(config\-if\)#.*/';
my $prompt_conf_vlan ='/.*\(config\-vlan\)#.*/';

# percent supression multicast and broadcast
my $trunk_ctl_mcast	= 1;	my $trunk_ctl_bcast	= 10;
my $port_ctl_mcast	= 1;	my $port_ctl_bcast	= 2;

############ SUBS ##############

sub BPS_conf_first {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => $LIB." Switch '".$arg->{'IP'}."' first configured MANUALLY!!!" );
    return -1;
}

sub BPS_pass_change {
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => $LIB." Switch '".$arg->{'IP'}."' changed password MANUALLY!!!" );
    return -1;
}

sub BPS_login {
    my ($swl, $ip, $pass ) = @_;
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => " IP = ".$ip.", PASS = ".$pass );
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
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "USE BPS command line interface - Ok" );
    return 1;
}

sub BPS_cmd {
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

sub BPS_port_set_vlan {

    my ( $swl, $port, $vlan_id, $tag, $trunk ) = @_;

    my $sw = ${$swl};
    SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "PARMS - ' $port, $vlan_id '" );
    my %vlan_del = ();

    #BPS2000#show vlan interface vids 24
    #Port VLAN VLAN Name         VLAN VLAN Name         VLAN VLAN Name
    #---- ---- ----------------  ---- ----------------  ---- ----------------
    #24   1    default           14   Office            17   Office_voip
    #     91   RSS_VoIP          111  copirtehnika      130  Quant
    #     131  Server            157  RSS_157           186  Ural_VTB
    #     215  AUTOBOSS          242  Leon              259  RiveraTur
    #     269  VUZ_bank          327  RSS_327           332  RSS_332
    #     355  Elekto_Montaz
    if (not $trunk ) {
	my @ln = $sw->cmd( String  => "sh vlan interface vids ".$port,
                                Prompt  => $prompt,
                                Timeout => $timeout,
                                Errmode => 'return',
	);
	foreach (@ln) {
	    #24   1    default           14   Office            17   Office_voip
	    if 	( /\s+(\d+)\s+\S+\s+(\d+)\s+\S+\s+(\d+)\s+\S+/ ) {
		$vlan_del{$1}=1; $vlan_del{$2}=1; $vlan_del{$3}=1;
	    } elsif ( /\s+(\d+)\s+\S+\s+(\d+)\s+\S+/ ) {
		$vlan_del{$1}=1; $vlan_del{$2}=1;
	    } elsif ( /\s+(\d+)\s+\S+/ ) {
		$vlan_del{$1}=1;
	    }
	}
    }
    return -1  if (&$command(\$sw, $prompt_conf, "conf t" ) < 1 );
    #############
    if (not $trunk ) {
	foreach my $vdel ( sort keys %vlan_del ) {
	    if ( $vdel != $vlan_id ) { return -1 if (&$command(\$sw, $prompt_conf, "vlan members remove ".$vdel." ".$port ) < 1); }
	}
    }
    if ($vlan_id != 1 ) {
	return -1  if (&$command(\$sw, $prompt_conf,    "vlan create ".$vlan_id." name Vlan".$vlan_id." type port learning ivl" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf,        "vlan members add ".$vlan_id." ".$port ) < 1);
    if ($tag) {
	return -1  if (&$command(\$sw, $prompt_conf,    "vlan ports ".$port." tagging tagAll untagPvidOnly pvid ".$vlan_id.
	" filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
    } else {
	if ( $trunk ) {
	    return -1  if (&$command(\$sw, $prompt_conf,    "vlan ports ".$port." tagging untagPvidOnly pvid ".$vlan_id.
	    " filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
	} else {
	    return -1  if (&$command(\$sw, $prompt_conf,    "vlan ports ".$port." tagging disable pvid ".$vlan_id.
	    " filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
	}
    }
    #############
    return -1  if (&$command(\$sw, $prompt,      "exit" ) < 1);

    return 1;
}

sub BPS_fix_macport {
    # IP LOGIN PASS MAC VLAN
    my $arg = shift;
    my $port = -1; my $pref; my $max=3; my $count=0;
################
    if ($arg->{'USE_SNMP'}) {
	SWFunc::dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "SNMP Fix PORT in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}."', VLAN '".$arg->{'VLAN'}."'" );
	($pref, $port ) = SWFunc::SNMP_fix_macport($arg);
    } else {
################
	# login
	my $sw; return -1  if ( &$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );
	while ($count < $max) {
	my @ln = $sw->cmd("show mac-address-table vid ".$arg->{'VLAN'}." address ".$arg->{'MAC'});
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
    }
    return ($pref, $port);
}


sub BPS_conf_save {
#   IP LOGIN PASS ENA_PASS
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SAVING $LIB config in switch '".$arg->{'IP'}."'" );
    return -1  if (&$command(\$sw, $prompt, "copy config nvram" ) < 1 );
    $sw->close();
    return 1;
}



sub BPS_port_up {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set port UP in '".$arg->{'IP'}."', port ".$arg->{'PORT'});

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

sub BPS_port_down {
#    IP LOGIN PASS ENA_PASS PORT PORTPREF
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Set port DOWN in '".$arg->{'IP'}."', port ".$arg->{'PORT'});

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}


sub BPS_port_defect {
#    IP LOGIN PASS PORT PORTPREF BLOCK_VLAN
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure DEFECT port in '".$arg->{'IP'}."', port ".$arg->{'PORT'});

    #BPS_port_set_vlan ( \$sw, $arg->{'PORT'}, $arg->{'BLOCK_VLAN'}, 0, 0 );
    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan create ".$arg->{'BLOCK_VLAN'}." name Block".$arg->{'BLOCK_VLAN'}." type port learning ivl" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan members add ".$arg->{'BLOCK_VLAN'}." ".$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan ports ".$arg->{'PORT'}." tagging disable pvid ".$arg->{'BLOCK_VLAN'}.
    " filter-tagged-frame disable filter-untagged-frame disable priority 0" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg->{'PORT'} ) < 1);
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
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    return -1 if (not $arg->{'VLAN'});
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure FREE port in '".$arg->{'IP'}."', port ".$arg->{'PORT'});

    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );

    BPS_port_set_vlan ( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, 0, 0 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    #return -1  if (&$command(\$sw, $prompt_conf,	"spanning-tree tagged-bpdu disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"speed auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"duplex auto" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"no shutdown" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree port ".$arg->{'PORT'}." learning disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"rate-limit port ".$arg->{'PORT'}." both ".$port_ctl_bcast ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf,	"exit" ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub BPS_speed_char {

    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
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

sub BPS_port_trunk {
#   IP LOGIN PASS PORT PORTPREF DS US VLAN TAG MAXHW AUTONEG SPEED DUPLEX
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure TRUNK port in '".$arg->{'IP'}."', port ".$arg->{'PORT'});

    my ($speed, $duplex ) = &$speed_char( $arg );
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );

    BPS_port_set_vlan ( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, $arg->{'TAG'}, 0 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    #return -1  if (&$command(\$sw, $prompt_conf,	"spanning-tree tagged-bpdu disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree port ".$arg->{'PORT'}." learning disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"rate-limit port ".$arg->{'PORT'}." both ".$port_ctl_bcast ) < 1);
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
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );

    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "Configure SYSTEM port in '".$arg->{'IP'}."', port ".$arg->{'PORT'});

    my ($speed, $duplex ) = &$speed_char( $arg );

    BPS_port_set_vlan ( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, $arg->{'TAG'}, 0 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    #return -1  if (&$command(\$sw, $prompt_conf,	"spanning-tree tagged-bpdu disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree port ".$arg->{'PORT'}." learning disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"rate-limit port ".$arg->{'PORT'}." both ".$port_ctl_bcast ) < 1);
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
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "SET PORT parameters in '".$arg->{'IP'}."', port ".$arg->{'PORT'} );

    my ($speed, $duplex ) = &$speed_char( $arg );

    BPS_port_set_vlan ( \$sw, $arg->{'PORT'}, $arg->{'VLAN'}, $arg->{'TAG'}, 0 );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    #return -1  if (&$command(\$sw, $prompt_conf,	"spanning-tree tagged-bpdu disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"interface Fa".$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"spanning-tree port ".$arg->{'PORT'}." learning disable" ) < 1);
    return -1  if (&$command(\$sw, $prompt_conf_if,	"rate-limit port ".$arg->{'PORT'}." both ".$port_ctl_bcast ) < 1);
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
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "ADD VLAN '".$arg->{'VLAN'}."' in '".$arg->{'IP'}."', trunk port ".$arg->{'PORT'} );


    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    if ($arg->{'VLAN'} != 1 ) {
	return -1  if (&$command(\$sw, $prompt_conf,	"vlan create ".$arg->{'VLAN'}." name Vlan".$arg->{'VLAN'}." type port learning ivl" ) < 1);
    }
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan members add ".$arg->{'VLAN'}." ".$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub BPS_vlan_trunk_remove  {
#    IP LOGIN PASS VLAN PORT PORTPREF
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN '".$arg->{'VLAN'}."' from '".$arg->{'IP'}."', trunk port ".$arg->{'PORT'} );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan members remove ".$arg->{'VLAN'}." ".$arg->{'PORT'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);

    $sw->close();
    return 1;
}

sub BPS_vlan_remove  {
#    IP LOGIN PASS VLAN
    my $arg = shift;
    #my %arg = (
    #    @_,
    #);
    # login
    my $sw; return -1  if (&$login(\$sw, $arg->{'IP'}, $arg->{'PASS'}) < 1 );
    SWFunc::dlog ( DBUG => 1, SUB => (caller(0))[3], MESS => "REMOVE VLAN '".$arg->{'VLAN'}."' from switch '".$arg->{'IP'}."'" );

    return -1  if (&$command(\$sw, $prompt_conf,	"conf t" ) < 1 );
    return -1  if (&$command(\$sw, $prompt_conf,	"vlan delete ".$arg->{'VLAN'} ) < 1);
    return -1  if (&$command(\$sw, $prompt,		"exit" ) < 1);
    $sw->close();
    return 1;
}

1;
