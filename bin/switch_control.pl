#!/usr/bin/perl -w


my $debug=1;

use Getopt::Long;
use strict;
no strict qw(refs);
use POSIX qw(strftime);
use locale;

use FindBin '$Bin';
use lib $Bin . '/../conf';
use lib $Bin.'/../lib';
use SWConf;
use SWFunc;

my $conf = \%SWConf::conf;

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
dlog ( SUB => $script_name, DBUG => 2, MESS => "Use BIN directory - $Bin" );

my $cycle_name='cycle_check.pl';
if ( $script_name eq $cycle_name and $ARGV[0] ) {

    my $lockfile="/tmp/".$script_name."_".$ARGV[0];
    open(LOCK,">",$lockfile) or die "Can't open file $!";
    flock(LOCK,2|4) or die;
    
}

my $ver='2.00';

my $cycle_run=1;
my $cycle_sleep=20;
my $res=0;
 
my $dbm; $res = DB_mysql_connect(\$dbm);
if ($res < 1) {
    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "Connect to MYSQL DB FAILED, RESULT = $res" );
    DB_mysql_check_connect(\$dbm);
}

my %link_type = ();
my @link_types = '';

my $stm0 = $dbm->prepare("SELECT ltype_id, ltype_name FROM link_types order by ltype_id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $link_type{$ref0->{'ltype_name'}}=$ref0->{'ltype_id'} if defined($ref0->{'ltype_name'});
    $link_types[$ref0->{'ltype_id'}]=$ref0->{'ltype_name'} if defined($ref0->{'ltype_id'});
}
$stm0->finish();

my %libs = ();
my @sw_models = '';
my %sw_descr = ();
$stm0 = $dbm->prepare("SELECT model_id, lib, model_name, sysdescr FROM models order by model_id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $libs{$ref0->{'lib'}}               = $ref0->{'model_id'}   if defined($ref0->{'lib'});
    $sw_models[$ref0->{'model_id'}]     = $ref0->{'model_name'} if defined($ref0->{'model_id'});
    $sw_descr{$ref0->{'sysdescr'}}      = $ref0->{'model_id'}   if defined($ref0->{'sysdescr'});
}
$stm0->finish();


my %SW = (
 'type',	'',
 'sw_id',	0,
 'swip',	'',
 'admin',	'admin',
 'adminpass',	'pass',
 'monlogin',	'swmon',
 'monpass',	'monpass',
 'rocomunity',	'public',
 'rwcomunity',	'private',
 'bwfree',	64,
 'uplink',	1,
 'last_port',	1,
 'cli_vlan_num',0,
 'cli_vlan',	'test',
);

my $head;
my $LIB_action = '';
my $resport=0;
my $point='';
my $Querry_portfix = '';
my $Querry_portfix_where = '';
my $Querry_start = '';
my $Querry_end = '';
my %parm = ();
my %sw_arg = ();
my ($ipcli, $ipgw, $netmask);

if ( not defined($ARGV[0]) ) {
    print STDERR "Usage:  $script_name ( newswitch <hostname old switch> <IP new switch> | [checkterm|checkjobs] )\n"

} elsif ( $ARGV[0] eq "newswitch" ) {
        DB_mysql_check_connect(\$dbm);
	exit if not $ARGV[1] =~ /^\S+$/;
	exit if not $ARGV[2] =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
	my $src_switch= $ARGV[1];
	my $test_swip= $ARGV[2] || $conf->{'def_swip'};
	my $stm1 = $dbm->prepare("SELECT h.sw_id, h.hostname, h.ip, h.clients_vlan, h.uplink_port, h.uplink_portpref, h.model_id, m.lib, m.bw_free, \
	m.lastuserport, m.admin_login, m.admin_pass, m.ena_pass, m.mon_login, m.mon_pass, m.rocom, m.rwcom FROM hosts h, models m WHERE \
	h.model_id=m.model_id and h.uplink_port>0 and h.hostname='".$src_switch."'");
	$stm1->execute();
	while (my $ref1 = $stm1->fetchrow_hashref()) {
		last if ($ref1->{'uplink_port'} < 1 or $ref1->{'clients_vlan'} < 1);

		$SW{'id'}=$ref1->{'id'} if defined($ref1->{'id'});
		$SW{'lib'}=$ref1->{'lib'} if defined($ref1->{'lib'});
		$SW{'admin'}="$ref1->{'admin_login'}" if defined($ref1->{'admin_login'});
		$SW{'adminpass'}="$ref1->{'admin_pass'}"   if defined($ref1->{'admin_pass'});
		$SW{'ena_pass'}="$ref1->{'ena_pass'}"   if defined($ref1->{'ena_pass'});
		$SW{'monlogin'}="$ref1->{'mon_login'}"     if defined($ref1->{'mon_login'});
		$SW{'monpass'}="$ref1->{'mon_pass'}"  if defined($ref1->{'mon_pass'});
		$SW{'bwfree'}="$ref1->{'bw_free'}"   if defined($ref1->{'bw_free'});
		$SW{'rocomunity'}="$ref1->{'rocom'}"  if defined($ref1->{'rocom'});
		$SW{'rwcomunity'}="$ref1->{'rwcom'}"  if defined($ref1->{'rwcom'});

		$SW{'cli_vlan_num'}="$ref1->{'clients_vlan'}";
		$SW{'cli_vlan'}="$ref1->{'hostname'}";
		$SW{'uplink'}="$ref1->{'uplink_port'}";
		if ($SW{'uplink'} > $ref1->{'lastuserport'}) {
		    $SW{'last_port'} = $ref1->{'lastuserport'};
		} else {
		    $SW{'last_port'} = $SW{'uplink'} - 1;
		}
		%sw_arg = (
                    LIB => $ref1->{'lib'}, ACT => 'conf_first',  IP => $test_swip, LOGIN => $SW{'admin'}, PASS => $SW{'adminpass'},  ENA_PASS => $SW{'ena_pass'}, UPLINKPORT => $SW{'uplink'},
		    UPLINKPORTPREF => $SW{'uplink_portpref'}, LASTPORT => $SW{'last_port'}, VLAN => $SW{'cli_vlan_num'}, VLANNAME => $SW{'cli_vlan'}, BLOCK_VLAN => $conf->{'BLOCKPORT_VLAN'},
		    BWFREE => $SW{'bwfree'}, MONLOGIN => $SW{'monlogin'}, MONPASS => $SW{'monpass'}, COM_RO => $SW{'rocomunity'}, COM_RW => $SW{'rwcomunity'},
                );
                $res = SW_ctl ( \%sw_arg ) if $debug < 3;

		############# RECONFIGURE SWITCH (for replace hardware)
		#$dbm-> do("UPDATE swports SET autoconf=".$link_type{'setparms'}." WHERE sw_id=".$SW{'id'}) if ( $ARGV[2] eq "useport" ); 
	}
	$stm1->finish();
} elsif ( $ARGV[0] eq "pass_change" ) {
        DB_mysql_check_connect(\$dbm);
	my $stm = $dbm->prepare("SELECT h.hostname, h.ip, m.lib, m.admin_login, m.admin_pass, m.ena_pass, m.old_admin, m.old_pass, m.mon_login, m.mon_pass FROM hosts h, models m \
	WHERE h.automanage=1 and h.model_id=m.model_id order by h.model_id");
	$stm->execute();
	while (my $ref = $stm->fetchrow_hashref()) {
	    next if not defined($ref->{'lib'});
	    next if not defined($ref->{'admin_login'});
	    next if not defined($ref->{'admin_pass'});

	    dlog ( SUB => 'pass_change', DBUG => 0, MESS => "ADD admin accounts in host '".$ref->{'hostname'}."'..." );
	    %sw_arg = (
        	LIB => $ref->{'lib'}, ACT => 'pass_change', IP => $ref->{'ip'}, LOGIN => $ref->{'old_admin'}, PASS => $ref->{'old_pass'}, ENA_PASS => $ref->{'ena_pass'},
		ADMINLOGIN => $ref->{'admin_login'}, ADMINPASS => $ref->{'admin_pass'}, MONLOGIN => $ref->{'mon_login'}, MONPASS => $ref->{'mon_pass'},
            );
            $res = SW_ctl ( \%sw_arg );
	    dlog ( SUB => 'pass_change', DBUG => 0, MESS => "Change accounts in host '".$ref->{'hostname'}."' failed!" ) if $res < 1;
	}
	$stm->finish();

} elsif ( $ARGV[0] eq "checkterm" ) {
  while ( $cycle_run < 2 or $script_name eq 'cycle_check.pl' ) {
    #dlog ( SUB => 'checkterm', DBUG => 1, MESS => "#" x 30 . " Checking cycle N $cycle_run " . "#" x 30 ) if $debug;
    DB_mysql_check_connect(\$dbm);
    ################################ SYNC LINK STATES
    my $stml = $dbm->prepare("SELECT l.head_id, l.port_id, p.vlan_id, l.status, l.set_status, p.ltype_id, l.ip_subnet, l.login \
    FROM swports p, head_link l WHERE l.set_status>0 and l.port_id=p.port_id ORDER BY l.head_id");
    $stml->execute();
    if ( $stml->rows ) { dlog ( SUB => 'checkterm', DBUG => 1, MESS => "#" x 30 . " Checking cycle N $cycle_run " . "#" x 30 ); }

    while (my $ref = $stml->fetchrow_hashref()) {
    $point = " ip_subnet => ".$ref->{'ip_subnet'};

	if ( $ref->{'set_status'} == $link_type{'up'} || $ref->{'set_status'} == $link_type{'down'} ) {
	    dlog ( SUB => 'checkterm', DBUG => 1, MESS => "##############################\n Control <<".$link_types[$ref->{'set_status'}].">> LINK in Terminator ".$point."\n##############################" );

    	    $head = GET_Terminfo ( TERM_ID => $ref->{'head_id'} );
            %sw_arg = (
                LIB => $head->{'TERM_LIB'}, ACT => 'term_'.$link_types[$ref->{'ltype_id'}].'_'.$link_types[$ref->{'set_status'}],
		IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'}, ENA_LOGIN => $head->{'TERM_LOGIN2'}, 
		ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'}, VLAN => $ref->{'vlan_id'}, 
		LOOP_IF => $head->{'LOOP_IF'}, UP_ACLIN => $head->{'UP_ACLIN'}, UP_ACLOUT => $head->{'UP_ACLOUT'}, 
		DOWN_ACLIN => $head->{'DOWN_ACLIN'}, DOWN_ACLOUT => $head->{'DOWN_ACLOUT'},
            );
            $res = SW_ctl ( \%sw_arg );
    	    next if $res < 1;
	    $res = SAVE_config(LIB => $head->{'TERM_LIB'}, SWID => -1, IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
	    ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}); next if $res < 1;

	    $dbm->do("UPDATE head_link SET status=".$ref->{'set_status'}.", set_status=NULL WHERE port_id=".$ref->{'port_id'}." and vlan_id=".$ref->{'vlan_id'});
	}
    }
    $stml->finish;

    exit if ( $script_name ne 'cycle_check.pl' );
    sleep($conf->{'CYCLE_SLEEP'});
    $cycle_run += 1;
  }


} elsif ( $ARGV[0] eq "checkjobs" ) {

  while ( $cycle_run < 2 or $script_name eq 'cycle_check.pl' ) {
    #dlog ( SUB => 'checkjobs', DBUG => 1, MESS => "#" x 30 . " Checking cycle N $cycle_run " . "#" x 30 ) if $debug;
    DB_mysql_check_connect(\$dbm);

    $SW{'change'} = 0;
    $SW{'sw_id'}=0;
    my $act=''; my $trunking_vlan = 1;
    ############################ CHECK for UPDATES PORTS PARAMETERS CYCLE ########################
    my $Q_jobs = "SELECT h.hostname, h.clients_vlan, h.model_id, h.ip, h.uplink_port, h.uplink_portpref, h.parent, h.parent_port, \
    h.parent_portpref, h.zone_id, h.automanage, j.ltype_id as new_ltype, j.job_id, j.parm, \
    p.sw_id, p.port_id, p.port, p.portpref, p.ds_speed, p.us_speed, p.vlan_id, p.tag, p.ltype_id, \
    m.lib, m.bw_free, m.admin_login, m.admin_pass, m.ena_pass FROM hosts h, swports p, models m, bundle_jobs j \
    WHERE h.model_id=m.model_id and h.sw_id=p.sw_id and j.archiv<2 and p.type>0 and j.port_id=p.port_id \
    and h.automanage=1  and j.ltype_id in \(";
    if ($script_name eq 'cycle_check.pl' ) {
	$Q_jobs .= $link_type{'setparms'}.",".$link_type{'pppoe'};
	#dlog ( SUB => 'checkjobs', DBUG => 1, MESS => "Checking scheduled jobs automatically" );
    } else {
	$Q_jobs .= $link_type{'up'}.",".$link_type{'down'}.",".$link_type{'uplink'}.",".$link_type{'free'}.
	",".$link_type{'l2link'}.",".$link_type{'l3realnet'}.",".$link_type{'l3net4'};
	dlog ( SUB => 'checkjobs', DBUG => 1, MESS => "Checking scheduled jobs manual" ) if $debug;
    }
    $Q_jobs .= "\) order by h.model_id, p.sw_id, p.portpref, p.port, j.job_id ";
    my $stm2 = $dbm->prepare($Q_jobs);
    
    $stm2->execute();
    if ( $stm2->rows ) { dlog ( SUB => 'checklink', DBUG => 1, MESS => "#" x 30 . " Checking cycle N $cycle_run " . "#" x 30  ); }

    while ( my $ref = $stm2->fetchrow_hashref() ) {
	############ SAVE PREVIOUS SWITCH CONFIG
	if ( $SW{'change'} and $SW{'sw_id'} != $ref->{'sw_id'} and defined($libs{$SW{'lib'}}) and 
	( $ref->{'new_ltype'}  == $link_type{'uplink'} || $ref->{'new_ltype'}  >= $conf->{'STARTLINKCONF'} )) {
	    $SW{'change'} = 0;
 	    $res = SAVE_config(LIB => $SW{'lib'}, SWID => $SW{'sw_id'}, IP => $SW{'swip'}, LOGIN => $SW{'admin'}, 
	    PASS => $SW{'adminpass'}, ENA_PASS => $SW{'ena_pass'});
	    #next if $res < 1;
	}

	%parm=split(/[:;]/,$ref->{'parm'});
	if (defined($parm{'hw_mac'}) and $parm{'hw_mac'} =~ /^(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)$/ ) {
            $parm{'hw_mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	}
	my $str_log;
	while(my ($k,$v)=each(%parm)) {
    	    $str_log .= " $k='$v',";
        }
        dlog ( SUB => 'checklink', DBUG => 0, MESS => $str_log );
	
	dlog ( SUB => 'checklink', DBUG => 0, MESS => "Switch LIB '".$ref->{'lib'}."' not exists!!! for switch '".$ref->{'hostname'}."'" ) if not defined($libs{$ref->{'lib'}});
	$res=0;
	$resport=0;
        $point = "\nPOINT: switch => ".$ref->{'hostname'}.", port => ".( defined($ref->{'portpref'}) ? $ref->{'portpref'} : '' ).$ref->{'port'}.", model => ".$sw_models[$ref->{'model_id'}];

        $SW{'sw_id'}=$ref->{'sw_id'};
        $SW{'swip'}=$ref->{'ip'}		if defined($ref->{'ip'});
	$SW{'lib'}=$ref->{'lib'} 		if defined($ref->{'lib'});
	$SW{'admin'}=$ref->{'admin_login'} 	if defined($ref->{'admin_login'});
	$SW{'adminpass'}=$ref->{'admin_pass'}	if defined($ref->{'admin_pass'});
	$SW{'ena_pass'}=$ref->{'ena_pass'}      if defined($ref->{'ena_pass'});

	if ($ref->{'new_ltype'}  < $conf->{'STARTPORTCONF'}) {
	    $Querry_portfix = "UPDATE swports p, bundle_jobs j SET j.archiv=1, date_exec=NOW()";
	} else {
	    $Querry_portfix = "UPDATE swports p, bundle_jobs j SET j.archiv=1, date_exec=NOW(), p.ltype_id=".$ref->{'new_ltype'};
	}
	$Querry_portfix_where = " WHERE j.job_id=".$ref->{'job_id'}." and j.port_id=p.port_id ";
	dlog ( SUB => 'checklink', DBUG => 0, MESS => "##############################\n Configure <<".$link_types[$ref->{'new_ltype'} ].">> LINK ".$point."\n##############################" );

###################### FREE LINK
	if ($ref->{'new_ltype'}  == $link_type{'free'}) {

	    next if $debug>2;
	    next if $ref->{'vlan_id'} == 1;
    	    $head = GET_Terminfo( TYPE => $ref->{'ltype_id'} , ZONE => $ref->{'zone_id'}, TERM_ID => $ref->{'head_id'});

	    $Querry_portfix  .=  ", p.status=".$link_type{'up'}.", p.us_speed=".$ref->{'bw_free'}.", p.ds_speed=".$ref->{'bw_free'}.
	    ", p.tag=0, p.start_date=NULL, p.info=NULL, p.maxhwaddr=-1, p.head_id=NULL, p.autoneg=1, p.speed=NULL, p.duplex=NULL";

	    $trunking_vlan = 1; 
	    # Если тип порта вне диапазоне линкуемых типов
	    if ( not $ref->{'ltype_id'}  > $link_type{'free'} ) {
		$trunking_vlan = 0;
	    # если VLAN на свиче установлен, а на порту не установлен 
	    } elsif ( $ref->{'clients_vlan'} > 1 and ( $ref->{'vlan_id'} == $ref->{'clients_vlan'} || $ref->{'vlan_id'} < 1 )) {
	        $trunking_vlan = 0;
	    } elsif ( not defined($ref->{'clients_vlan'}) and $ref->{'vlan_id'} < 1 ) {
	        $trunking_vlan = 0;
	    } elsif ( $ref->{'vlan_id'} > 1 ) {
		$trunking_vlan = VLAN_remove(PORT_ID => $ref->{'port_id'}, VLAN => $ref->{'vlan_id'}, HEAD => $ref->{'head_id'}) if defined($ref->{'head_id'});
	    } else {
	        $trunking_vlan = 0;
	    }
	    if ($trunking_vlan) {
		## Убираем VLAN c Терминатора, согласно типа подключения.
		if ( $head->{'TERM_USE'} ) {
		  if ( $head->{'TERM_USE'} > 1 ) {
        	    %sw_arg = (
            		LIB => $head->{'TERM_LIB'}, ACT => 'term_'.$link_types[$ref->{'ltype_id'} ].'_remove',
			IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
                	ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'},
                	VLAN => $ref->{'vlan_id'}, LOOP_IF => $head->{'LOOP_IF'},
		    );
        	    $res = SW_ctl ( \%sw_arg );
		    next if $res < 1;
		    $res = SAVE_config(LIB => $head->{'TERM_LIB'}, SWID => -1, IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
		    ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}); next if $res < 1;
		  }
		  $dbm->do("DELETE FROM head_link WHERE port_id=".$ref->{'port_id'});
		} else {
		    dlog ( SUB => 'check_free', DBUG => 1, MESS => "Head link not USE for this link type, AP '".$point."'" );
		}
	        # Убираем VLAN по всей цепочке транковых портов вплоть до коммутатора непосредственно связанного с терминатором.
		$res = VLAN_link(LIB => $ref->{'lib'}, ACT => 'remove', TYPE => $ref->{'ltype_id'} , SWID => $ref->{'sw_id'}, IP => $ref->{'ip'}, 
		LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, VLAN => $ref->{'vlan_id'}, 
		PARENT => $ref->{'parent'}, PARENTPORT => $ref->{'parent_port'}, PARENTPORTPREF => $ref->{'parent_portpref'},
		L2HEAD => $head->{'L2SW_ID'}, L2HEAD_PORT => $head->{'L2SW_PORT'}, L2HEAD_PORTPREF => $head->{'L2SW_PORTPREF'}) 
		if ( defined($ref->{'uplink_port'}) and defined($ref->{'parent'}) and defined($ref->{'parent_port'}));
		#next if $res < 1;
		## Убираем VLAN на UPLINK порту текущего коммутатора
		dlog ( SUB => 'check_free', DBUG => 1, MESS => "REMOVE VLAN in UPLINK port" );
	      if ($ref->{'uplink_port'} > 0 and DB_trunk_vlan(ACT => 'remove', SWID => $ref->{'sw_id'}, VLAN => $ref->{'vlan_id'},
	      PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'}) < 1) {
	        %sw_arg = (
		    LIB => $ref->{'lib'}, ACT => 'vlan_trunk_remove',IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, 
		    ENA_PASS => $ref->{'ena_pass'}, VLAN => $ref->{'vlan_id'}, PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'},
		);
        	$res = SW_ctl ( \%sw_arg );
		next if $res < 1;

		$SW{'change'} += 1;
	        DB_trunk_update(ACT => 'remove', SWID => $ref->{'sw_id'}, PORTPREF => $ref->{'uplink_portpref'}, PORT => $ref->{'uplink_port'}, VLAN => $ref->{'vlan_id'});
	      } elsif ($ref->{'uplink_port'} < 1) {
		dlog ( SUB => 'check_free', DBUG => 0, MESS => "Trunking vlan chains skip uplink in ".$ref->{'hostname'}.", UPLINK_PORT not SET  :-(" );
	      } else {
		dlog ( SUB => 'check_free', DBUG => 0, MESS => "Trunking vlan uplink in ".$ref->{'hostname'}.", already remove in DB ;-)" );
	      }
	      
	      %sw_arg = (
        	LIB => $ref->{'lib'}, ACT => 'vlan_remove', IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, 
		ENA_PASS => $ref->{'ena_pass'}, VLAN => $ref->{'vlan_id'},
    	      );
	      $res = SW_ctl ( \%sw_arg );
	    }
	    ## Освобождаем клиентский порт текущего коммутатора
	    $ref->{'clients_vlan'} = $conf->{'BLOCKPORT_VLAN'} if not defined($ref->{'clients_vlan'});
	    $Querry_portfix  .=  ", p.vlan_id=".$ref->{'clients_vlan'} if ( $ref->{'clients_vlan'} > 1 );

            %sw_arg = (
                LIB => $ref->{'lib'}, ACT => 'port_free', IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'},
		ENA_PASS => $ref->{'ena_pass'}, VLAN => $ref->{'clients_vlan'}, PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}, 
		DS => $ref->{'bw_free'}, US => $ref->{'bw_free'}, UPLINKPORT => $ref->{'uplink_port'}, BLOCK_VLAN => $conf->{'BLOCKPORT_VLAN'}, 
		UPLINKPORTPREF => $ref->{'uplink_portpref'},
            );
            $resport = SW_ctl ( \%sw_arg ) if defined($libs{$ref->{'lib'}});
	    next if $resport < 1;
	    $SW{'change'} += 1;

	} elsif ( $ref->{'new_ltype'}  < $conf->{'STARTLINKCONF'} and $ref->{'new_ltype'}  != $link_type{'uplink'} ) {
	    next if $debug>2;

	    ############# SET PORT PARAMETERS 
	    if ($ref->{'new_ltype'}  == $link_type{'setparms'}) {
		$Querry_portfix  .=  ", p.status=".$link_type{'up'};
		$Querry_portfix  .=  ", p.us_speed=".$parm{'us_speed'} if ( defined($parm{'us_speed'}));
		$Querry_portfix  .=  ", p.ds_speed=".$parm{'ds_speed'} if ( defined($parm{'ds_speed'}));
		$Querry_portfix  .=  ", p.vlan_id=".$parm{'vlan_id'} if ( defined($parm{'vlan_id'}));
	    ############# PORT TYPE TRUNK
	    } elsif ($ref->{'new_ltype'}  == $link_type{'trunk'}) {
		$Querry_portfix .= ", p.status=".$link_type{'up'}.", p.ds_speed=-1, p.us_speed=-1"
	    } elsif ($ref->{'new_ltype'}  == $link_type{'uplink'}) {
		$Querry_portfix .= ", p.status=".$link_type{'up'}.", p.ds_speed=-1, p.us_speed=-1"
	    ############# SET PORT is DEFECT 
	    } elsif ($ref->{'new_ltype'}  == $link_type{'defect'}) {
		$Querry_portfix  .=  ", p.status=".$link_type{'down'}.", p.us_speed=NULL, p.ds_speed=NULL, p.tag=0, \
		p.vlan_id=-1, p.start_date=NULL, p.info=NULL, p.maxhwaddr=-1, p.head_id=NULL, p.autoneg=1, p.speed=NULL, p.duplex=NULL";
	    ############# PORT DISABLE
	    } elsif ($ref->{'new_ltype'} == $link_type{'down'}) {
		$Querry_portfix  .= ", p.status=".$link_type{'down'};
	    } else {
	    	$Querry_portfix .= ", p.status=".$link_type{'up'};
	    }

            %sw_arg = (
                LIB => $ref->{'lib'}, ACT => 'port_'.$link_types[$ref->{'new_ltype'}], IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'},
		PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}, 
		DS => ( $parm{'ds_speed'} ? $parm{'ds_speed'} : $ref->{'ds_speed'} ),
		US => ( $parm{'us_speed'} ? $parm{'us_speed'} : $ref->{'us_speed'} ),
		VLAN => ( $parm{'vlan_id'} ? $parm{'vlan_id'} : $ref->{'vlan_id'} ),
		MAXHW => ( $parm{'maxhwaddr'} ? $parm{'maxhwaddr'} : $ref->{'maxhwaddr'} ),
		AUTONEG => ( $parm{'autoneg'} ? $parm{'autoneg'} : $ref->{'autoneg'} ),
		SPEED => ( $parm{'speed'} ? $parm{'speed'} : $ref->{'speed'} ),
		DUPLEX => ( $parm{'duplex'} ? $parm{'duplex'} : $ref->{'duplex'} ),
		TAG => $ref->{'tag'}, BLOCK_VLAN => $conf->{'BLOCKPORT_VLAN'},
            );
            $resport = SW_ctl ( \%sw_arg );
	    next if $resport < 1;

            $SW{'change'} += 1;

	#### UPLINK PORT - temporary not use
	} elsif ( $ref->{'new_ltype'}  == $link_type{'uplink'} ) {
	    ## Настройка UPLINK порта
            next if $debug>2;
	    next if $ref->{'vlan_id'} < 1;
	    $trunking_vlan = 1;

	    # Настройка непосредственно параметров порта
	    dlog ( SUB => 'check_uplink', DBUG => 0, MESS => "Configure  UPLINK port !!!" );

            %sw_arg = (
                LIB => $ref->{'lib'}, ACT => 'port_trunk', IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, 
		ENA_PASS => $ref->{'ena_pass'}, PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}, DS => -1, US => -1, VLAN => $ref->{'vlan_id'}, MAXHW => -1,
		AUTONEG => $ref->{'autoneg'}, SPEED =>  $ref->{'speed'}, DUPLEX =>  $ref->{'duplex'}, TAG => $ref->{'tag'}, BLOCK_VLAN => $conf->{'BLOCKPORT_VLAN'},
            );
            $res = SW_ctl ( \%sw_arg );

	    next if $res < 1;
 
	    $trunking_vlan=0 if not defined($ref->{'clients_vlan'});
	    $ref->{'vlan_id'} = $ref->{'clients_vlan'};
	    $Querry_portfix  .=  ", p.status=".$link_type{'up'}.", p.us_speed=-1, p.ds_speed=-1, p.maxhwaddr=-1";

	    if ($trunking_vlan) {
	      ## Добавляем VLAN на UPLINK порту текущего коммутатора
	      if ($ref->{'port'} > 0 and DB_trunk_vlan(ACT => 'add', SWID => $ref->{'sw_id'}, VLAN => $ref->{'vlan_id'}, PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}) < 1) {
		dlog ( SUB => 'check_uplink', DBUG => 1, MESS => "ADD VLAN in UPLINK port" );
                %sw_arg = (
                    LIB => $ref->{'lib'}, ACT => 'vlan_trunk_add', IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'},
		    ENA_PASS => $ref->{'ena_pass'},	VLAN => $ref->{'vlan_id'} , PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}, 
		    UPLINKPORTPREF => $ref->{'portpref'}, UPLINKPORT => $ref->{'port'},
                );
                $resport = SW_ctl ( \%sw_arg );
		next if $resport < 1;

		$SW{'change'} += 1;
		DB_trunk_update(ACT => 'add', SWID => $ref->{'sw_id'}, PORTPREF => $ref->{'portpref'}, PORT => $ref->{'port'}, VLAN => $ref->{'vlan_id'});
	      } elsif ($ref->{'port'} < 1) {
		dlog ( SUB => 'check_uplink', DBUG => 0, MESS => "Trunking vlan chains skip uplink in ".$ref->{'hostname'}.", UPLINK_PORT not SET  :-\(" );
	      } else {
		dlog ( SUB => 'check_uplink', DBUG => 0, MESS => "Trunking vlan uplink in ".$ref->{'hostname'}.", already add in DB ;-\)" );
	      }
		############# SET PORT PARAMETERS 
		$ref->{'zone_id'} = 1 if ( $ref->{'vlan_id'} > 1 and $ref->{'vlan_id'} < $conf->{'FIRST_ZONEVLAN'} );
		$head = GET_Terminfo( TYPE => $conf->{'CLI_VLAN_LINKTYPE'}, ZONE => $ref->{'zone_id'});
		$Querry_portfix .=", p.head_id=".$head->{'HEAD_ID'};

		# Прокидываем  VLAN по всем транковым портам вплоть до коммутатора непосредственно связанного с терминатором.
		dlog ( SUB => 'check_uplink', DBUG => 1, MESS => "linking trunk ports" );
		
		$res = VLAN_link(LIB => $ref->{'lib'}, ACT => 'add', TYPE => $conf->{'CLI_VLAN_LINKTYPE'}, 
		SWID => $ref->{'sw_id'}, IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'},
		VLAN => $ref->{'vlan_id'}, UPLINKPORT => $ref->{'uplink_port'}, UPLINKPORTPREF => $ref->{'uplink_portpref'},
		PARENT => $ref->{'parent'}, PARENTPORT => $ref->{'parent_port'}, PARENTPORTPREF => $ref->{'parent_portpref'},
		L2HEAD => $head->{'L2SW_ID'}, L2HEAD_PORT => $head->{'L2SW_PORT'}, L2HEAD_PORTPREF => $head->{'L2SW_PORTPREF'})
		if ( defined($ref->{'uplink_port'}) and defined($ref->{'parent'}) and defined($ref->{'parent_port'})); next if $res < 1;

		## Терминируем VLAN, согласно текущего типа подключения 
		if ( $ref->{'vlan_id'} >= $head->{'VLAN_MIN'} and $ref->{'vlan_id'} <= $head->{'VLAN_MAX'} ) {
		    if ( $head->{'TERM_USE'} > 1 ) {
			#IP LOGIN PASS ENA_PASS IFACE VLAN VLANNAME IPGW NETMASK ACLIN ACLOUT
			($ipcli, $ipgw, $netmask) = GET_GW_parms (SUBNET => $ref->{'ip_subnet'}, TYPE => $conf->{'CLI_VLAN_LINKTYPE'});
			%sw_arg = (
			    LIB => $head->{'TERM_LIB'}, ACT => 'term_'.$link_types[$conf->{'CLI_VLAN_LINKTYPE'}].'_add',  IP => $head->{'TERM_IP'}, 
			    LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'}, ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}, 
			    IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'}, VLAN => $ref->{'vlan_id'}, LOOP_IF => $head->{'LOOP_IF'}, IPGW => $ipgw,
			    IPCLI => $ipcli, NETMASK => $netmask, VLANNAME => $ref->{'hostname'}.'_port_'.$ref->{'portpref'}.$ref->{'port'}.'_'.$ref->{'login'},
			    UP_ACLIN => $head->{'UP_ACLIN'}, UP_ACLOUT => $head->{'UP_ACLOUT'}, DHCP_HELPER => $head->{'DHCP_HELPER'},
			);
			$res = SW_ctl ( \%sw_arg );

			next if $res < 1;
			# Сохраняем конфиг на терминаторе
			$res = SAVE_config(LIB => $head->{'TERM_LIB'}, SWID => -1, IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
			ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}); next if $res < 1;

		    } else {
			dlog ( SUB => 'check_uplink', DBUG => 1, MESS => "UPLINK VLAN terminate succesfull!!!" );
		    }
		} else {
		    dlog ( SUB => 'check_uplink', DBUG => 0, MESS => "Port VLAN '".$ref->{'vlan_id'}."' not in Terminator '".$link_types[$conf->{'CLI_VLAN_LINKTYPE'}]."' VLAN range '".$head->{'VLAN_MIN'}."' - '".$head->{'VLAN_MAX'}."'" );
		}
	    }
	    $SW{'change'} += 1;

######## Остальные типы линков начиная от 21-го и выше
	} elsif ( $ref->{'new_ltype'}  > $conf->{'STARTLINKCONF'} ) {


            next if $debug>2;
            next if ( $ref->{'vlan_id'} == 1 );
            $trunking_vlan = 1; $res = 1;
	    dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 1, MESS => "Start linking ".$ref->{'new_ltype'}  );

	    if ( defined($ref->{'clients_vlan'}) and ( $ref->{'new_ltype'}  == $conf->{'CLI_VLAN_LINKTYPE'} ||  $ref->{'new_ltype'}  ==  $link_type{'l3realnet'} ) ) {
                $trunking_vlan=0;
		if ( not defined($parm{'vlan_id'}) ) {
            	    $parm{'vlan_id'} = $ref->{'clients_vlan'};
		} elsif ($parm{'vlan_id'} != $ref->{'clients_vlan'}) {
		    $trunking_vlan = 1;
		}
	    }
	    
	    $ref->{'zone_id'} = 1 if ( $parm{'vlan_id'} < -1 || ( $parm{'vlan_id'} > 1 and $parm{'vlan_id'} < $conf->{'FIRST_ZONEVLAN'} ));
            $head = GET_Terminfo( TYPE => $ref->{'new_ltype'} , ZONE => $ref->{'zone_id'});
	    
	    ### Выясняем необходимость выделения и номер влана для использования
            if ( defined($parm{'vlan_id'}) and $parm{'vlan_id'} < 1 and defined($head->{'ZONE_ID'}) ) {
		( $parm{'vlan_id'}, $head->{'HEAD_ID'} ) = VLAN_get ( PORT_ID => $ref->{'port_id'}, LINK_TYPE => $ref->{'new_ltype'} , ZONE => $head->{'ZONE_ID'} );
	    }

            # Завершаем если нет вменяемого номера влана
	    if (not defined($ref->{'clients_vlan'}) and $parm{'vlan_id'} < 1 ) {
		if ($ref->{'new_ltype'}  == $conf->{'CLI_VLAN_LINKTYPE'}) {
		    dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 0, MESS => "Clients PPPoE VLAN not defined in switch ".$ref->{'hostname'}."! Next" );
		} else {
		    dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 0, MESS => "PORT VLAN not defined in port ".$ref->{'portpref'}.$ref->{'port'}."switch ".$ref->{'hostname'}."! Next" );
		}
		next;
	    }

	    $Querry_portfix  .=  ", p.status=".$link_type{'up'};
	    $Querry_portfix  .=  ", p.us_speed=".$parm{'us_speed'} if ( defined($parm{'us_speed'}));
	    $Querry_portfix  .=  ", p.ds_speed=".$parm{'ds_speed'} if ( defined($parm{'ds_speed'}));
	    $Querry_portfix  .=  ", p.vlan_id=".$parm{'vlan_id'} if ( defined($parm{'vlan_id'}));


            ## Прописываем VLAN на клиентском порту текущего коммутатора
	    dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 1, MESS => "Config CLIENT port parameters and set VLAN ".$parm{'vlan_id'} );

            %sw_arg = (
                LIB => $ref->{'lib'}, ACT => 'port_setparms',IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, 
		ENA_PASS => $ref->{'ena_pass'}, BLOCK_VLAN => $conf->{'BLOCKPORT_VLAN'}, PORTPREF => $ref->{'portpref'}, PORT => $ref->{'port'}, 
		UPLINKPORTPREF => $ref->{'uplink_portpref'}, UPLINKPORT => $ref->{'uplink_port'}, VLAN => $parm{'vlan_id'}, 
        	DS => ( $parm{'ds_speed'} ? $parm{'ds_speed'} : $ref->{'ds_speed'} ),
        	US => ( $parm{'us_speed'} ? $parm{'us_speed'} : $ref->{'us_speed'} ),
        	MAXHW => ( $parm{'maxhwaddr'} ? $parm{'maxhwaddr'} : $ref->{'maxhwaddr'} ),
        	AUTONEG => ( $parm{'autoneg'} ? $parm{'autoneg'} : $ref->{'autoneg'} ),
        	SPEED => ( $parm{'speed'} ? $parm{'speed'} : $ref->{'speed'} ),
        	DUPLEX => ( $parm{'duplex'} ? $parm{'duplex'} : $ref->{'duplex'} ),
		TAG => $ref->{'tag'}, 
            );
            $resport = SW_ctl ( \%sw_arg );
	    next if $resport < 1;
            $Querry_portfix .=", p.head_id=".$head->{'HEAD_ID'};

            if ($trunking_vlan) {
                ## Добавляем VLAN на UPLINK порту текущего коммутатора
	      if ($ref->{'uplink_port'} > 0 and DB_trunk_vlan(ACT => 'add', SWID => $ref->{'sw_id'}, VLAN => $parm{'vlan_id'}, PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'}) < 1) {
		dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 1, MESS => "ADD VLAN in UPLINK port" );
                %sw_arg = (
                    LIB => $ref->{'lib'}, ACT => 'vlan_trunk_add', IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'},
		    ENA_PASS => $ref->{'ena_pass'}, VLAN => $parm{'vlan_id'}, PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'},
		    UPLINKPORTPREF => $ref->{'uplink_portpref'}, UPLINKPORT => $ref->{'uplink_port'},
                );
                $resport = SW_ctl ( \%sw_arg );
		next if $resport < 1;

		$SW{'change'} += 1;
		DB_trunk_update(ACT => 'add', SWID => $ref->{'sw_id'}, PORTPREF => $ref->{'uplink_portpref'}, PORT => $ref->{'uplink_port'}, VLAN => $parm{'vlan_id'});
	      } elsif ($ref->{'uplink_port'} < 1) {
		dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 0, MESS => "Trunking vlan chains skip uplink in ".$ref->{'hostname'}.", UPLINK_PORT not SET  :-\(" );
	      } else {
		dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 0, MESS => "Trunking vlan uplink in ".$ref->{'hostname'}.", already add in DB ;-\)" );
	      }
		# Прокидываем  VLAN по всем транковым портам вплоть до коммутатора непосредственно связанного с терминатором.
                dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 1, MESS => "linking trunk ports" );
		
		$res = VLAN_link(LIB => $ref->{'lib'}, ACT => 'add', TYPE => $ref->{'new_ltype'} , 
		SWID => $ref->{'sw_id'}, IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'},
		VLAN => $parm{'vlan_id'}, UPLINKPORT => $ref->{'uplink_port'}, UPLINKPORTPREF => $ref->{'uplink_portpref'},
		PARENT => $ref->{'parent'}, PARENTPORT => $ref->{'parent_port'}, PARENTPORTPREF => $ref->{'parent_portpref'},
		L2HEAD => $head->{'L2SW_ID'}, L2HEAD_PORT => $head->{'L2SW_PORT'}, L2HEAD_PORTPREF => $head->{'L2SW_PORTPREF'})
		if ( defined($ref->{'parent'}) or $head->{'L2SW_ID'} == $ref->{'sw_id'} );
		if ($res < 1) {
            	    dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 0, MESS => "VLAN_link lost.. :-(" );
		    next;
		}

		## Терминируем VLAN, согласно текущего типа подключения 
		if ( $parm{'vlan_id'} >= $head->{'VLAN_MIN'} and $parm{'vlan_id'} <= $head->{'VLAN_MAX'} ) {
		    if ( $head->{'TERM_USE'} ) {
			if ( $head->{'TERM_USE'} > 1 ) {
			    #IP LOGIN PASS ENA_PASS IFACE VLAN VLANNAME IPGW NETMASK ACLIN ACLOUT
			    ($ipcli, $ipgw, $netmask) = GET_GW_parms ( SUBNET => $parm{'ip_subnet'}, TYPE => $ref->{'new_ltype'} );
			    %sw_arg = (
			        LIB => $head->{'TERM_LIB'}, ACT => 'term_'.$link_types[$ref->{'new_ltype'} ].'_add', IP => $head->{'TERM_IP'}, 
				LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},ENA_LOGIN => $head->{'TERM_LOGIN2'},
				ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'}, VLAN => $parm{'vlan_id'},
				VLANNAME => $ref->{'hostname'}.'_port_'.$ref->{'portpref'}.$ref->{'port'}.'_'.$ref->{'login'}, IPCLI => $ipcli,
				IPGW => $ipgw, NETMASK => $netmask, UP_ACLIN => $head->{'UP_ACLIN'}, UP_ACLOUT => $head->{'UP_ACLOUT'}, 
				DHCP_HELPER => $head->{'DHCP_HELPER'}, LOOP_IF => $head->{'LOOP_IF'},
			    );
			    $res = SW_ctl ( \%sw_arg );
			    next if $res < 1;
			    # Сохраняем конфиг на терминаторе
			    $res = SAVE_config(LIB => $head->{'TERM_LIB'}, SWID => -1, IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
			    ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}); next if $res < 1;
			}
		    } else {
			dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 1, MESS => "LINK '".$link_types[$ref->{'new_ltype'} ]."'".$point." terminate succesfull!!!" );
		    }
		} else {
		    dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 0, MESS => "Port VLAN '".$parm{'vlan_id'}."' not in Terminator '".$link_types[$ref->{'new_ltype'} ]."' VLAN range '".$head->{'VLAN_MIN'}."' - '".$head->{'VLAN_MAX'}."'" );
		}
	    }
	    if ( $res > 0 ) {
		my $head_if = 'unknown';
		if ( $ref->{'new_ltype'} eq $conf->{'CLI_VLAN_LINKTYPE'} ) {
		    $head_if = $conf->{'CLI_VLAN_LINKTYPE'};
		} elsif ( $head->{'TERM_PORT'} ne '' ) {
		    $head_if = $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'}.".".$parm{'vlan_id'};
		} elsif ( $ref->{'new_ltype'} eq $link_type{'l3realnet'} ) {
		    $head_if = "Vlan".$parm{'vlan_id'};
		}
		$head_if = ( $head->{'TERM_PORT'} ne '' ? $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'}.".".$parm{'vlan_id'} : "Vlan".$parm{'vlan_id'});
		my $Q_head_link = "INSERT Into head_link SET port_id=".$ref->{'port_id'};
		my $Q_head_link_upd = " vlan_id=".$parm{'vlan_id'}.", head_id=".$head->{'HEAD_ID'}.", head_iface='".$head_if."'";
		$Q_head_link_upd .= ( defined($parm{'inet_rate'}) ? ", inet_shape='".$parm{'inet_rate'}."'" : "" );
		$Q_head_link_upd .= ( defined($parm{'ip_subnet'}) ? ", ip_subnet='".$parm{'ip_subnet'}."'"  : ", ip_subnet=NULL " );
		$Q_head_link_upd .= ( defined($parm{'login'})     ? ", login='".$parm{'login'}."'"          : ", login=NULL "     );
		$Q_head_link .= ", ".$Q_head_link_upd;
		$Q_head_link .= " ON DUPLICATE KEY UPDATE ".$Q_head_link_upd;
		#print STDERR $Q_head_link."\n";
		$dbm->do($Q_head_link);
		$SW{'change'} += 1;
	    }
	}
	# Помечаем в BD изменения на порту
	$dbm->do($Querry_portfix.$Querry_portfix_where) if $resport > 0;
    }
    # SAVE LAST SWITCH CONFIG to NVRAM
    SAVE_config( LIB => $SW{'lib'}, SWID => $SW{'sw_id'}, IP => $SW{'swip'}, LOGIN => $SW{'admin'}, PASS => $SW{'adminpass'}, ENA_PASS => $SW{'ena_pass'} )
    if ($SW{'change'} and defined($libs{$SW{'lib'}}));
    $stm2->finish();

    exit if ( $script_name ne 'cycle_check.pl' );
    sleep($conf->{'CYCLE_SLEEP'});
    $cycle_run += 1;
  }

}

$dbm->disconnect();


