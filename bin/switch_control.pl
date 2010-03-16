#!/usr/bin/perl -w


use Getopt::Long;

use strict;
no strict qw(refs);

use POSIX qw(strftime);
#use DBI();
use locale;

my $debug=1;

use FindBin '$Bin';
require $Bin . '/../conf/config.pl';
require $Bin . '/../conf/lib.pl';
my $conf = \%main::conf;

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
dlog ( SUB => $script_name, DBUG => 2, MESS => "Use BIN directory - $Bin" );

my $cycle_name='cycle_check.pl';
if ( $script_name eq $cycle_name and $ARGV[0] ) {

    my $lockfile="/tmp/".$script_name."_".$ARGV[0];
    open(LOCK,">",$lockfile) or die "Can't open file $!";
    flock(LOCK,2|4) or die "$lockfile already run";
    
}


my $ver='2.00';

my $cycle_run=1;
my $cycle_sleep=30;
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
		$LIB_action = $ref1->{'lib'}.'_conf_first';
		$res = &$LIB_action( IP => $test_swip, LOGIN => $SW{'admin'}, PASS => $SW{'adminpass'},  ENA_PASS => $SW{'ena_pass'}, UPLINKPORT => $SW{'uplink'},
		UPLINKPORTPREF => $SW{'uplink_portpref'}, LASTPORT => $SW{'last_port'}, VLAN => $SW{'cli_vlan_num'}, VLANNAME => $SW{'cli_vlan'}, BLOCK_VLAN => $conf->{'BLOCKPORT_VLAN'},
		BWFREE => $SW{'bwfree'}, MONLOGIN => $SW{'monlogin'}, MONPASS => $SW{'monpass'}, COM_RO => $SW{'rocomunity'}, COM_RW => $SW{'rwcomunity'}) if $debug < 3;
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
	    $LIB_action = $ref->{'lib'}.'_pass_change';
	    $res = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'old_admin'}, PASS => $ref->{'old_pass'}, ENA_PASS => $ref->{'ena_pass'},
	    ADMINLOGIN => $ref->{'admin_login'}, ADMINPASS => $ref->{'admin_pass'}, MONLOGIN => $ref->{'mon_login'}, MONPASS => $ref->{'mon_pass'});
	    dlog ( SUB => 'pass_change', DBUG => 0, MESS => "Change accounts in host '".$ref->{'hostname'}."' failed!" );
	}
	$stm->finish();

} elsif ( $ARGV[0] eq "checkterm" ) {
  while ( $cycle_run < 2 or $script_name eq 'cycle_check.pl' ) {
    DB_mysql_check_connect(\$dbm);
    ################################ SYNC LINK STATES
    my $stml = $dbm->prepare("SELECT l.head_id, l.port_id, p.vlan_id, l.status, l.set_status, p.ltype_id, l.ip_subnet, l.login \
    FROM swports p, head_link l WHERE l.set_status>0 and l.port_id=p.port_id ORDER BY l.head_id");
    #my $stml = $dbm->prepare("SELECT head_id, port_id, vlan_id, status, set_status, ltype_id, ip_subnet, login \
    #FROM  head_link WHERE set_status>0 ORDER BY head_id");
    $stml->execute();
    if ( $stml->rows ) { dlog ( SUB => 'checkterm', DBUG => 1, MESS => "#" x 30 . " Checking cycle N $cycle_run " . "#" x 30 ); }

    while (my $ref = $stml->fetchrow_hashref()) {
    $point = " ip_subnet => ".$ref->{'ip_subnet'};

	if ( $ref->{'set_status'} == $link_type{'up'} || $ref->{'set_status'} == $link_type{'down'} ) {
	    dlog ( SUB => 'checkterm', DBUG => 1, MESS => "##############################\n Control <<".$link_types[$ref->{'set_status'}].">> LINK in Terminator ".$point."\n##############################" );

    	    $head = GET_Terminfo ( TERM_ID => $ref->{'head_id'} );

            $LIB_action = $head->{'TERM_LIB'}.'_term_'.$link_types[$ref->{'ltype_id'}].'_'.$link_types[$ref->{'set_status'}];
            $res = &$LIB_action( IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
            ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'},
            VLAN => $ref->{'vlan_id'}, LOOP_IF => $head->{'LOOP_IF'}, UP_ACLIN => $head->{'UP_ACLIN'}, UP_ACLOUT => $head->{'UP_ACLOUT'}, 
	    DOWN_ACLIN => $head->{'DOWN_ACLIN'}, DOWN_ACLOUT => $head->{'DOWN_ACLOUT'});
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
    DB_mysql_check_connect(\$dbm);

    $SW{'change'} = 0;
    $SW{'sw_id'}=0;
    my $act=''; my $trunking_vlan = 1;
    ############################ CHECK for UPDATES PORTS PARAMETERS CYCLE ########################
    my $stm2 = $dbm->prepare("SELECT h.hostname, h.clients_vlan, h.model_id, h.ip, h.uplink_port, h.uplink_portpref, h.parent, h.parent_port, \
    h.parent_portpref, h.zone_id, h.automanage, j.ltype_id as new_ltype, j.job_id, j.parm, \
    p.sw_id, p.port_id, p.port, p.portpref, p.ds_speed, p.us_speed, p.vlan_id, p.tag, p.ltype_id, \
    m.lib, m.bw_free, m.admin_login, m.admin_pass, m.ena_pass FROM hosts h, swports p, models m, bundle_jobs j \
    WHERE h.model_id=m.model_id and h.sw_id=p.sw_id and j.archiv<2 and p.type>0 and j.port_id=p.port_id \
    and h.automanage=1  and j.ltype_id in ".
    "\(".$link_type{'up'}.",".$link_type{'down'}.",".$link_type{'setparms'}.",".$link_type{'free'}.
    ",".$link_type{'pppoe'}.",".$link_type{'l2link'}.",".$link_type{'l3realnet'}.",".$link_type{'l3net4'}.
    #",".$link_type{'uplink'}.
    "\) order by h.model_id, p.sw_id, p.portpref, p.port, j.job_id ");
    
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
	    $Querry_portfix = "UPDATE swports p, bundle_jobs j SET j.archiv=1";
	} else {
	    $Querry_portfix = "UPDATE swports p, bundle_jobs j SET j.archiv=1, p.ltype_id=".$ref->{'new_ltype'};
	}
	$Querry_portfix_where = " WHERE j.job_id=".$ref->{'job_id'}." and j.port_id=p.port_id ";
	dlog ( SUB => 'checklink', DBUG => 0, MESS => "##############################\n Configure <<".$link_types[$ref->{'new_ltype'} ].">> LINK ".$point."\n##############################" );

#### FREE LINK
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
		    $LIB_action = $head->{'TERM_LIB'}.'_term_'.$link_types[$ref->{'ltype_id'} ].'_remove';
		    $res = &$LIB_action( IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
		    ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'},
		    VLAN => $ref->{'vlan_id'}, LOOP_IF => $head->{'LOOP_IF'});
		    next if $res < 1;
		    $res = SAVE_config(LIB => $head->{'TERM_LIB'}, SWID => -1, IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
		    ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}); next if $res < 1;
		    $dbm->do("DELETE FROM head_link WHERE port_id=".$ref->{'port_id'}." and vlan_id=".$ref->{'vlan_id'});
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
		$LIB_action = $ref->{'lib'}.'_vlan_trunk_remove';
    	        $res = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'},
		 VLAN => $ref->{'vlan_id'}, PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'}); next if $res < 1;
		$SW{'change'} += 1;
	        DB_trunk_update(ACT => 'remove', SWID => $ref->{'sw_id'}, PORTPREF => $ref->{'uplink_portpref'}, PORT => $ref->{'uplink_port'}, VLAN => $ref->{'vlan_id'});
	      } elsif ($ref->{'uplink_port'} < 1) {
		dlog ( SUB => 'check_free', DBUG => 0, MESS => "Trunking vlan chains skip uplink in ".$ref->{'hostname'}.", UPLINK_PORT not SET  :-(" );
	      } else {
		dlog ( SUB => 'check_free', DBUG => 0, MESS => "Trunking vlan uplink in ".$ref->{'hostname'}.", already remove in DB ;-)" );
	      }
	      
	      $LIB_action = $ref->{'lib'}.'_vlan_remove';
	      $res = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'},
	      VLAN => $ref->{'vlan_id'});
	    }
	    ## Освобождаем клиентский порт текущего коммутатора
	    $ref->{'clients_vlan'} = $conf->{'BLOCKPORT_VLAN'} if not defined($ref->{'clients_vlan'});
	    $Querry_portfix  .=  ", p.vlan_id=".$ref->{'clients_vlan'} if ( $ref->{'clients_vlan'} > 1 );

	    $LIB_action = $ref->{'lib'}.'_port_free';
	    $resport = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, VLAN => $ref->{'clients_vlan'}, 
	    PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}, DS => $ref->{'bw_free'}, US => $ref->{'bw_free'}, UPLINKPORT => $ref->{'uplink_port'}, BLOCK_VLAN => $conf->{'BLOCKPORT_VLAN'}, 
	    UPLINKPORTPREF => $ref->{'uplink_portpref'}) if defined($libs{$ref->{'lib'}}); next if $resport < 1;

 	    #$Querry_portfix  .=  " WHERE j.ltype_id= ".$link_type{'free'};
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

	    $LIB_action = $ref->{'lib'}.'_port_'.$link_types[$ref->{'new_ltype'} ];
	    $resport = &$LIB_action( IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, PORT => $ref->{'port'}, 
	    PORTPREF => $ref->{'portpref'}, 
	    DS => ( $parm{'ds_speed'} ? $parm{'ds_speed'} : $ref->{'ds_speed'} ),
	    US => ( $parm{'us_speed'} ? $parm{'us_speed'} : $ref->{'us_speed'} ),
	    VLAN => ( $parm{'vlan_id'} ? $parm{'vlan_id'} : $ref->{'vlan_id'} ),
	    MAXHW => ( $parm{'maxhwaddr'} ? $parm{'maxhwaddr'} : $ref->{'maxhwaddr'} ),
	    AUTONEG => ( $parm{'autoneg'} ? $parm{'autoneg'} : $ref->{'autoneg'} ),
	    SPEED => ( $parm{'speed'} ? $parm{'speed'} : $ref->{'speed'} ),
	    DUPLEX => ( $parm{'duplex'} ? $parm{'duplex'} : $ref->{'duplex'} ),
	    TAG => $ref->{'tag'},
	    BLOCK_VLAN => $conf->{'BLOCKPORT_VLAN'});
	    next if $resport < 1;
            $SW{'change'} += 1;
	    #$Querry_portfix  .=  " WHERE j.ltype_id= ".$ref->{'new_ltype'} ;

	#### UPLINK PORT - temporary not use
	} elsif ( $ref->{'new_ltype'}  == $link_type{'uplink'} ) {
	    ## Настройка UPLINK порта
            next if $debug>2;
	    next if $ref->{'vlan_id'} < 1;
	    $trunking_vlan = 1;

	    # Настройка непосредственно параметров порта
	    dlog ( SUB => 'check_uplink', DBUG => 0, MESS => "Configure  UPLINK port !!!" );

	    $LIB_action = $ref->{'lib'}.'_port_trunk';
	    $res = &$LIB_action( IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, PORT => $ref->{'port'},
            PORTPREF => $ref->{'portpref'}, 
	    DS => -1, US => -1, VLAN => $ref->{'vlan_id'}, MAXHW => -1, AUTONEG => $ref->{'autoneg'}, SPEED =>  $ref->{'speed'}, DUPLEX =>  $ref->{'duplex'},
	    TAG => $ref->{'tag'}, BLOCK_VLAN => $conf->{'BLOCKPORT_VLAN'}); next if $res < 1;
 
	    $trunking_vlan=0 if not defined($ref->{'clients_vlan'});
	    $ref->{'vlan_id'} = $ref->{'clients_vlan'};
	    $Querry_portfix  .=  ", p.status=".$link_type{'up'}.", p.us_speed=-1, p.ds_speed=-1, p.maxhwaddr=-1";

	    if ($trunking_vlan) {
	      ## Добавляем VLAN на UPLINK порту текущего коммутатора
	      if ($ref->{'port'} > 0 and DB_trunk_vlan(ACT => 'add', SWID => $ref->{'sw_id'}, VLAN => $ref->{'vlan_id'}, PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}) < 1) {
		dlog ( SUB => 'check_uplink', DBUG => 1, MESS => "ADD VLAN in UPLINK port" );
    		$LIB_action = $ref->{'lib'}.'_vlan_trunk_add';
    		$resport = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, 
		ENA_PASS => $ref->{'ena_pass'},	VLAN => $ref->{'vlan_id'} , PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}, 
		UPLINKPORTPREF => $ref->{'portpref'}, UPLINKPORT => $ref->{'port'}); next if $resport < 1;
		$SW{'change'} += 1;
		DB_trunk_update(ACT => 'add', SWID => $ref->{'sw_id'}, PORTPREF => $ref->{'portpref'}, PORT => $ref->{'port'}, VLAN => $ref->{'vlan_id'});
	      } elsif ($ref->{'port'} < 1) {
		dlog ( SUB => 'check_uplink', DBUG => 0, MESS => "Trunking vlan chains skip uplink in ".$ref->{'hostname'}.", UPLINK_PORT not SET  :-\(" );
	      } else {
		dlog ( SUB => 'check_uplink', DBUG => 0, MESS => "Trunking vlan uplink in ".$ref->{'hostname'}.", already add in DB ;-\)" );
	      }
		############# SET PORT PARAMETERS 
		$ref->{'zone_id'} = -1 if ( $ref->{'vlan_id'} > 1 and $ref->{'vlan_id'} < $conf->{'FIRST_ZONEVLAN'} );
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
		    if ( $head->{'TERM_USE'} ) {
			#IP LOGIN PASS ENA_PASS IFACE VLAN VLANNAME IPGW NETMASK ACLIN ACLOUT
			my ($ipcli, $ipgw, $netmask) = GET_GW_parms (SUBNET => $ref->{'ip_subnet'}, TYPE => $conf->{'CLI_VLAN_LINKTYPE'});
			$LIB_action = $head->{'TERM_LIB'}.'_term_'.$link_types[$conf->{'CLI_VLAN_LINKTYPE'}].'_add';
			$res = &$LIB_action( IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
			ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'},
			VLAN => $ref->{'vlan_id'}, VLANNAME => $ref->{'hostname'}.'_port_'.$ref->{'portpref'}.$ref->{'port'}.'_'.$ref->{'login'}, IPCLI => $ipcli,
			IPGW => $ipgw, NETMASK => $netmask, UP_ACLIN => $head->{'UP_ACLIN'}, UP_ACLOUT => $head->{'UP_ACLOUT'}, DHCP_HELPER => $head->{'DHCP_HELPER'}, LOOP_IF => $head->{'LOOP_IF'});
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
	    #$Querry_portfix  .=  " WHERE j.ltype_id= ".$link_type{'uplink'};
	    $SW{'change'} += 1;

######## Остальные типы линков начиная от 21-го и выше
	} elsif ( $ref->{'new_ltype'}  > $conf->{'STARTLINKCONF'} ) {


            next if $debug>2;
            next if ( $ref->{'vlan_id'} == 1 );
            $trunking_vlan = 1;
	    dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 1, MESS => "Start linking ".$ref->{'new_ltype'}  );

	    if ( $ref->{'new_ltype'}  ==  ($conf->{'CLI_VLAN_LINKTYPE'}||$link_type{'l3realnet'}) and defined($ref->{'clients_vlan'}) ) {
                $trunking_vlan=0;
		if ( not defined($parm{'vlan_id'}) ) {
            	    $parm{'vlan_id'} = $ref->{'clients_vlan'};
		} elsif ($parm{'vlan_id'} != $ref->{'clients_vlan'}) {
		    $trunking_vlan = 1;
		}
	    }
	    
	    $ref->{'zone_id'} = -1 if ( $parm{'vlan_id'} < -1 || ( $parm{'vlan_id'} > 1 and $parm{'vlan_id'} < $conf->{'FIRST_ZONEVLAN'} ));
            $head = GET_Terminfo( TYPE => $ref->{'new_ltype'} , ZONE => $ref->{'zone_id'});
	    
	    ### Выясняем необходимость выделения и номер влана для использования
            #if ( ( not defined($parm{'vlan_id'}) || $parm{'vlan_id'} < 1 ) and defined($head->{'ZONE_ID'}) ) {
            if ( $parm{'vlan_id'} < 1 and defined($head->{'ZONE_ID'}) ) {
		$parm{'vlan_id'} = VLAN_get( PORT_ID => $ref->{'port_id'}, LINK_TYPE => $ref->{'new_ltype'} , ZONE => $head->{'ZONE_ID'}, 
		VLAN_MIN => $head->{'VLAN_MIN'}, VLAN_MAX => $head->{'VLAN_MAX'});
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

            $LIB_action = $ref->{'lib'}.'_port_setparms';
            $resport = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, BLOCK_VLAN => $conf->{'BLOCKPORT_VLAN'}, 
	    PORTPREF => $ref->{'portpref'}, PORT => $ref->{'port'}, UPLINKPORTPREF => $ref->{'uplink_portpref'}, 
	    UPLINKPORT => $ref->{'uplink_port'}, VLAN => $parm{'vlan_id'}, 
            DS => ( $parm{'ds_speed'} ? $parm{'ds_speed'} : $ref->{'ds_speed'} ),
            US => ( $parm{'us_speed'} ? $parm{'us_speed'} : $ref->{'us_speed'} ),
            MAXHW => ( $parm{'maxhwaddr'} ? $parm{'maxhwaddr'} : $ref->{'maxhwaddr'} ),
            AUTONEG => ( $parm{'autoneg'} ? $parm{'autoneg'} : $ref->{'autoneg'} ),
            SPEED => ( $parm{'speed'} ? $parm{'speed'} : $ref->{'speed'} ),
            DUPLEX => ( $parm{'duplex'} ? $parm{'duplex'} : $ref->{'duplex'} ),
	    TAG => $ref->{'tag'}, ) if defined($libs{$ref->{'lib'}}); 
	    next if $resport < 1;
            $Querry_portfix .=", p.head_id=".$head->{'HEAD_ID'};

            if ($trunking_vlan) {
                ## Добавляем VLAN на UPLINK порту текущего коммутатора
	      if ($ref->{'uplink_port'} > 0 and DB_trunk_vlan(ACT => 'add', SWID => $ref->{'sw_id'}, VLAN => $parm{'vlan_id'}, PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'}) < 1) {
		dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 1, MESS => "ADD VLAN in UPLINK port" );

    		$LIB_action = $ref->{'lib'}.'_vlan_trunk_add';
    		$resport = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, VLAN => $parm{'vlan_id'},
		PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'}, UPLINKPORTPREF => $ref->{'uplink_portpref'}, UPLINKPORT => $ref->{'uplink_port'}); next if $resport < 1;
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
			#IP LOGIN PASS ENA_PASS IFACE VLAN VLANNAME IPGW NETMASK ACLIN ACLOUT
			my ($ipcli, $ipgw, $netmask) = GET_GW_parms ( SUBNET => $parm{'ip_subnet'}, TYPE => $ref->{'new_ltype'}  );
			
			$LIB_action = $head->{'TERM_LIB'}.'_term_'.$link_types[$ref->{'new_ltype'} ].'_add';
			$res = &$LIB_action( IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
			ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'},
			VLAN => $parm{'vlan_id'}, VLANNAME => $ref->{'hostname'}.'_port_'.$ref->{'portpref'}.$ref->{'port'}.'_'.$ref->{'login'}, IPCLI => $ipcli,
			IPGW => $ipgw, NETMASK => $netmask, UP_ACLIN => $head->{'UP_ACLIN'}, UP_ACLOUT => $head->{'UP_ACLOUT'}, DHCP_HELPER => $head->{'DHCP_HELPER'}, LOOP_IF => $head->{'LOOP_IF'});
			next if $res < 1;
			# Сохраняем конфиг на терминаторе
			$res = SAVE_config(LIB => $head->{'TERM_LIB'}, SWID => -1, IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
			ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}); next if $res < 1;

			my $head_if = ( $head->{'TERM_PORT'} ne '' ? $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'}.".".$parm{'vlan_id'} : "Vlan".$parm{'vlan_id'});

			my $Q_head_link = "INSERT Into head_link SET port_id=".$ref->{'port_id'}.", vlan_id=".$parm{'vlan_id'}.", head_id=".$head->{'HEAD_ID'}.
			", head_iface='".$head_if."'";
			my $Q_head_link1 = ( defined($parm{'ip_subnet'}) ? ", ip_subnet='".$parm{'ip_subnet'}."'" : ", ip_subnet=NULL " );
			$Q_head_link1   .= ( defined($parm{'login'})     ? ", login='".$parm{'login'}."'"         : ", login=NULL "     );
			$Q_head_link .= $Q_head_link1;
			$Q_head_link .= " ON DUPLICATE KEY UPDATE vlan_id=".$parm{'vlan_id'}.", head_id=".$head->{'HEAD_ID'}.", head_iface='".$head_if."' ";
			$Q_head_link .= $Q_head_link1;
			$dbm->do($Q_head_link);
		    } else {
			dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 1, MESS => "LINK '".$link_types[$ref->{'new_ltype'} ]."'".$point." terminate succesfull!!!" );
		    }
		} else {
		    dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 0, MESS => "Port VLAN '".$parm{'vlan_id'}."' not in Terminator '".$link_types[$ref->{'new_ltype'} ]."' VLAN range '".$head->{'VLAN_MIN'}."' - '".$head->{'VLAN_MAX'}."'" );
		}
	    }
	    #$Querry_portfix  .=  " WHERE ltype_id= ".$ref->{'new_ltype'} ;
	    $SW{'change'} += 1;
	}
	# Помечаем в BD изменения на порту
	dlog ( SUB => 'check_'.$link_types[$ref->{'new_ltype'} ] , DBUG => 1, MESS => $Querry_portfix.$Querry_portfix_where );
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


#################################################### SUBS ############################################################

sub SAVE_config {
    # сохраняем конфиг на коммутаторе
    my %argscfg = (
	    @_,		# список пар аргументов
    );
    dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Save config in sw_id => '".$argscfg{'SWID'}."' IP => '".$argscfg{'IP'}."' (debug)" );
    return 0 if $debug>1;
    my $res=0;
    $LIB_action = $argscfg{'LIB'}.'_conf_save';
    $res = &$LIB_action(IP => $argscfg{'IP'}, LOGIN => $argscfg{'LOGIN'}, PASS => $argscfg{'PASS'}, ENA_PASS => $argscfg{'ENA_PASS'}) if ($argscfg{'LIB'} ne '');

    $dbm->do("UPDATE swports p, bundle_jobs j SET j.archiv=j.job_id, date_exec=".time." WHERE j.port_id=p.port_id and j.archiv=1 and p.sw_id=".$argscfg{'SWID'}) if ($res>0 and $argscfg{'SWID'} > 0);
    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "Save config in host '".$argscfg{'IP'}."' failed!" ) if $res < 1;
    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "Save config in host '".$argscfg{'IP'}."' complete" ) if $res > 0;
    return $res;
}


sub GET_GW_parms {
    dlog ( SUB => (caller(0))[3], DBUG => 2, MESS => 'GET IP GW info (debug)' );

    my %arg = (
        @_,         # список пар аргументов
    );
    my $GW = ''; my $GW1 = ''; my $MASK ='';  my $CLI_IP ='';
    my $Querry_start = ''; my $Querry_end = '';
    # SUBNET TYPE
    if ( $arg{'TYPE'} >= $conf->{'STARTLINKCONF'} ) {
    my @ln = `/usr/local/bin/ipcalc $arg{SUBNET}`;
        foreach (@ln) {
	    #Netmask:   255.255.248.0 = 21   11111111.11111111.11111 000.00000000
	    #HostMin:   10.13.64.1           00001010.00001101.01000 000.00000001
	    if      ( /Netmask\:\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+/ ) {
		$MASK = "$1";
	    } elsif ( /HostMin\:\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+/  ) {
		$GW = "$1";
	    }
	}
	if ( $arg{'SUBNET'} =~ /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/\d+/ and $GW ne $1 ) { $CLI_IP = $1; } 
    }
    return ( $CLI_IP, $GW, $MASK );
}

sub GET_Terminfo {
    dlog ( SUB => (caller(0))[3], DBUG => 2, MESS => 'GET Terminator info (debug)' );

    my %arg = (
        @_,         # список пар аргументов
    );
    # TYPE ZONE TERM_ID
    my %headinfo; my $res = 0;
    $Querry_start = "SELECT * FROM heads WHERE ";
    if ( defined($arg{'TERM_ID'}) and $arg{'TERM_ID'} > 0) {
	$Querry_start .= " head_id=".$arg{'TERM_ID'};
    } else {
	$Querry_start .= " ltype_id=".$arg{'TYPE'};
	$Querry_end = " and zone_id=".$arg{'ZONE'};
    }
    my $stm31 = $dbm->prepare($Querry_start.$Querry_end);
    $stm31->execute();
    if (not $stm31->rows) {
	$stm31->finish();
	$Querry_end = " and zone_id = -1";
	$stm31 = $dbm->prepare($Querry_start.$Querry_end);
	$stm31->execute();
    }
    if ($stm31->rows == 1) {
	while (my $ref31 = $stm31->fetchrow_hashref()) {
    	    $headinfo{'HEAD_ID'} = $ref31->{'head_id'};
	    $headinfo{'L2SW_ID'} = $ref31->{'l2sw_id'};
	    $headinfo{'L2SW_PORT'} = $ref31->{'l2sw_port'};
	    $headinfo{'L2SW_PORTPREF'} = $ref31->{'l2sw_portpref'};
	    $headinfo{'TERM_USE'} = $ref31->{'term_use'};
	    $headinfo{'TERM_LIB'} = $ref31->{'term_lib'};
	    $headinfo{'TERM_ID'} = $ref31->{'term_id'};
	    $headinfo{'TERM_IP'} = $ref31->{'term_ip'};
	    $headinfo{'TERM_PORT'} = $ref31->{'term_port'};
	    $headinfo{'TERM_PORTPREF'} = $ref31->{'term_portpref'};
	    $headinfo{'TERM_LOGIN1'} = $ref31->{'login1'};
	    $headinfo{'TERM_LOGIN2'} = $ref31->{'login2'};
	    $headinfo{'TERM_PASS1'} = $ref31->{'pass1'};
	    $headinfo{'TERM_PASS2'} = $ref31->{'pass2'};
	    $headinfo{'VLAN_MIN'} = $ref31->{'vlan_min'};
	    $headinfo{'VLAN_MAX'} = $ref31->{'vlan_max'};
	    $headinfo{'UP_ACLIN'} = $ref31->{'up_acl-in'};
	    $headinfo{'UP_ACLOUT'} = $ref31->{'up_acl-out'};
	    $headinfo{'DOWN_ACLIN'} = $ref31->{'down_acl-in'};
	    $headinfo{'DOWN_ACLOUT'} = $ref31->{'down_acl-out'};
	    $headinfo{'LOOP_IF'} = $ref31->{'loop_if'};
	    $headinfo{'DHCP_HELPER'} = $ref31->{'dhcp_helper'};
	    $headinfo{'ZONE_ID'} = $ref31->{'zone_id'};
	}
	$res = 1;
	#$stm31->finish();
	#return \%headinfo;
    } elsif ($stm31->rows > 1)  {
	dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "MULTI TERMINATOR! 8-), count = ".$stm31->rows );
    } else {
	dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => 'TERMINATOR NOT FOUND :-(' );
    }
    $stm31->finish();
    return \%headinfo if ($res > 0);
}


sub VLAN_link {

	dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "LINKING VLAN to HEAD (debug)" );
	return -1 if $debug>2;
	## Пробрасываем VLAN до головного свича
	my %arglnk = (
	    @_,
	);

	my $res=0; my $count = 0; my $LIB_action =''; my $LIB_action1 =''; my %PAR = ();
	$PAR{'change'} = 0;
	$PAR{'sw_id'} = $arglnk{'PARENT'};
	$PAR{'low_port'} = $arglnk{'PARENTPORT'};
	$PAR{'low_portpref'} = $arglnk{'PARENTPORTPREF'}; 
	## Выбираем коммутаторы по цепочке вплоть до head_id или головного по зоне, центрального.
	while ( $PAR{'sw_id'}>0 and $count < $conf->{'MAXPARENTS'} ) {
	    $PAR{'change'} = 0; 
	    $count +=1;
	    my $stm21 = $dbm->prepare("SELECT h.hostname, h.model_id, h.sw_id, h.ip, h.uplink_port, h.uplink_portpref, h.parent, h.parent_port, h.parent_portpref, ".
	    "m.lib, m.admin_login, m.admin_pass, m.ena_pass FROM hosts h, models m WHERE h.model_id=m.model_id and h.sw_id=".$PAR{'sw_id'}." order by h.sw_id");
	    $stm21->execute();
	    while (my $ref21 = $stm21->fetchrow_hashref()) {
		if ( 'x'.$ref21->{'lib'} eq 'x' ) {
		    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "LIB not defined for switch ".$ref21->{'hostname'}.", Vlan link break :-( !!!" );
		    $stm21->finish;
		    return -1;
		}
	      $LIB_action = $ref21->{'lib'}.'_vlan_trunk_'.$arglnk{'ACT'};
	      if ( $PAR{'low_port'} > 0 and DB_trunk_vlan(ACT => $arglnk{'ACT'}, SWID => $ref21->{'sw_id'}, VLAN => $arglnk{'VLAN'}, 
		PORTPREF => $PAR{'low_portpref'}, PORT => $PAR{'low_port'}) < 1) {
		## пробрасываем/убираем тэгированный VLAN на присоединённом порту вышестоящего коммутатора
		dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DOWNLINK vlan ".$arglnk{'ACT'}."\n LIB => .$ref21->{'lib'},  IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, VLAN => $arglnk{'VLAN'}, ".
		"PORT => $PAR{'low_port'}, PORTPREF => $PAR{'low_portpref'}" );
	    	$res = &$LIB_action(IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, PASS => $ref21->{'admin_pass'}, ENA_PASS => $ref21->{'ena_pass'},
		VLAN => $arglnk{'VLAN'}, PORT => $PAR{'low_port'}, PORTPREF => $PAR{'low_portpref'}, UPLINKPORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORT => $ref21->{'uplink_port'});
		if ($res < 1) {
		    $stm21->finish();
		    return $res;
		}
		$PAR{'change'} += 1;
		# DB Update 
		DB_trunk_update(ACT => $arglnk{'ACT'}, SWID => $ref21->{'sw_id'}, PORTPREF => $PAR{'low_portpref'}, PORT => $PAR{'low_port'}, VLAN => $arglnk{'VLAN'});
	      } elsif ( $PAR{'low_port'} < 1 ) {
		    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "Trunking vlan chains skip parent link for switch ".$ref21->{'hostname'}.", PARENT_PORT not SET  :-(" );
	      } else {
		    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "Trunking vlan downlink in ".$ref21->{'hostname'}.", already ".$arglnk{'ACT'}." in DB :-)" );
		    $res = 1;
	      }	
		if ( $PAR{'sw_id'} == $arglnk{'L2HEAD'} ) {
		    if (defined($arglnk{'L2HEAD_PORT'}) and DB_trunk_vlan(ACT => $arglnk{'ACT'}, SWID => $ref21->{'sw_id'}, VLAN => $arglnk{'VLAN'}, PORTPREF => $arglnk{'L2HEAD_PORTPREF'}, PORT => $arglnk{'L2HEAD_PORT'}) < 1) {
			# Пробрасываем/убираем VLAN на порту стыковки последнего свича с терминатором
			dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "SWITCHTERM vlan ".$arglnk{'ACT'}."\n LIB => $ref21->{'lib'}, IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, VLAN => $arglnk{'VLAN'}, ".
			"PORT => $arglnk{'L2HEAD_PORT'}, PORTPREF => $arglnk{'L2HEAD_PORTPREF'}" );
			$res = &$LIB_action(IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, PASS => $ref21->{'admin_pass'}, ENA_PASS => $ref21->{'ena_pass'},
                	VLAN => $arglnk{'VLAN'}, PORT => $arglnk{'L2HEAD_PORT'}, PORTPREF => $arglnk{'L2HEAD_PORTPREF'}, UPLINKPORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORT => $ref21->{'uplink_port'});
			if ($res < 1) {
			    $stm21->finish();
			    return $res;
			}
			$PAR{'change'} += 1;
			DB_trunk_update(ACT => $arglnk{'ACT'}, SWID => $ref21->{'sw_id'}, PORTPREF => $arglnk{'L2HEAD_PORTPREF'}, PORT => $arglnk{'L2HEAD_PORT'}, VLAN => $arglnk{'VLAN'});
		    }
		    $count = $conf->{'MAXPARENTS'}; # завершаем  если добрались до головного коммутатора цепочки!
		} elsif ( defined($ref21->{'uplink_port'}) and DB_trunk_vlan(ACT => $arglnk{'ACT'}, SWID => $ref21->{'sw_id'}, VLAN => $arglnk{'VLAN'}, PORT => $ref21->{'uplink_port'}, PORTPREF => $ref21->{'uplink_portpref'}) < 1 ) {
		    ## пробрасываем/убираем тэгированный VLAN на UPLINK порту текущего коммутатора цепочки 
		    dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "UPLINK vlan ".$arglnk{'ACT'}."\n LIB => $ref21->{'lib'}, IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, VLAN => $arglnk{'VLAN'}, ".
		    "PORT => $ref21->{'uplink_port'}, PORTPREF => $ref21->{'uplink_portpref'}\n" );
		    $res = &$LIB_action(IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, PASS => $ref21->{'admin_pass'}, ENA_PASS => $ref21->{'ena_pass'},
		    VLAN => $arglnk{'VLAN'}, PORT => $ref21->{'uplink_port'}, PORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORT => $ref21->{'uplink_port'});
		    if ($res < 1) {
			$stm21->finish();
			return $res;
		    }
		    $PAR{'change'} += 1;
		    DB_trunk_update(ACT => $arglnk{'ACT'}, SWID => $ref21->{'sw_id'}, PORTPREF => $ref21->{'uplink_portpref'}, PORT => $ref21->{'uplink_port'}, VLAN => $arglnk{'VLAN'});
		} elsif (not defined($ref21->{'uplink_port'})) {
		    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "Trunking vlan chains skip uplink in ".$ref21->{'hostname'}.", UPLINK_PORT not SET  :-(" );
		} else {
		    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "Trunking vlan uplink in ".$ref21->{'hostname'}.", already ".$arglnk{'ACT'}." in DB :-)" );
		    $res = 1;
		}

		if ($PAR{'change'}) {
		    if ( $arglnk{'ACT'} eq 'remove' ) {
			# Ппри убирании линка - убираем VLAN с текущего свича
    			$LIB_action1 = $ref21->{'lib'}.'_vlan_remove';
			$res = &$LIB_action1(IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, PASS => $ref21->{'admin_pass'}, ENA_PASS => $ref21->{'ena_pass'}, VLAN => $arglnk{'VLAN'});
		    }
		    # Сохраняем конфигурацию текущего коммутатора цепочки
		    SAVE_config(LIB => $ref21->{'lib'}, SWID => $ref21->{'sw_id'}, IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, PASS => $ref21->{'admin_pass'}, 
		    ENA_PASS => $ref21->{'ena_pass'});
		}
		# Прекращаем, если не найден вышестоящий коммутатор и текущий коммутатор не является головным свичём цепочки терминирования
		if ( not defined($ref21->{'parent'}) and $PAR{'sw_id'} != $arglnk{'L2HEAD'} ) {
		    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "Trunking vlan chains lost in switch ".$ref21->{'hostname'}.", PARENT not SET  :-(" );
		    $stm21->finish();
		    return -1;
		}
		# Запоминаем параметры DOWNLINK на следующем коммутаторе цепочки
		$PAR{'sw_id'}=$ref21->{'parent'};
		$PAR{'low_port'} = $ref21->{'parent_port'};
		$PAR{'low_portpref'} = $ref21->{'parent_portpref'};
	    }
	    $stm21->finish();
	}
	return $res;
}

sub DB_trunk_update {
	# Делаем запись об изменении влана в текущем транковом порту
        my %argdb = (
            @_,         # список пар аргументов
        );
	# ACT SWID VLAN PORTPREF PORT
        dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Save to DB change trunk VLAN => '".$argdb{'VLAN'}."', sw_id => '".$argdb{'SWID'}."' portpref => '".$argdb{'PORTPREF'}."', port => ".$argdb{'PORT'}." (debug)" );
	return 1 if $debug>1;
	my $Qr_in = "SELECT port_id FROM swports WHERE sw_id=".$argdb{'SWID'}." and port=".$argdb{'PORT'};
	if ( defined($argdb{'PORTPREF'}) and 'x'.$argdb{'PORTPREF'} ne 'x' ) {
	    $Qr_in .= " and portpref='".$argdb{'PORTPREF'}."'";
	} else {
	    $Qr_in .= " and portpref is NULL";
	}
	my $stm33 = $dbm->prepare($Qr_in);
	$stm33->execute();
        while (my $ref33 = $stm33->fetchrow_hashref() and $stm33->rows == 1 ) {
	    my $Qr_add = "INSERT INTO port_vlantag set port_id=".$ref33->{'port_id'}.", vlan_id=".$argdb{'VLAN'}." ON DUPLICATE KEY UPDATE vlan_id=".$argdb{'VLAN'};
	    my $Qr_remove = "DELETE FROM port_vlantag WHERE port_id=".$ref33->{'port_id'}." and vlan_id=".$argdb{'VLAN'};

	    if ( "x".$argdb{'ACT'} eq 'xadd') {
		$dbm->do($Qr_add);
	    }
	    $dbm->do($Qr_remove) if ( "x".$argdb{'ACT'} eq 'xremove');
	}
	$stm33->finish();
}

sub DB_trunk_vlan {
	# Делаем запись об изменении влана в текущем транковом порту
        my %argdb = (
            @_,         # список пар аргументов
        );
	# ACT SWID VLAN PORTPREF PORT
	my $res = 0;
	# Умолчания для результата процедуры поиска
	$res = -1 if ("x".$argdb{'ACT'} eq 'xadd');    #Прокидывание VLAN'а: нет в транке - добавить
	$res =  1 if ("x".$argdb{'ACT'} eq 'xremove'); #Убирание     VLAN'а: нет в транке - не удалять
        dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Check Vlan in trunk port => '".$argdb{'VLAN'}."', sw_id => '".$argdb{'SWID'}."' portpref => '".$argdb{'PORTPREF'}."', port => ".$argdb{'PORT'}." (debug)" );

	return 1 if $debug>1;
	my $Qr_in = "SELECT port_id FROM swports WHERE sw_id=".$argdb{'SWID'}." and port=".$argdb{'PORT'};
	if ( defined($argdb{'PORTPREF'}) and 'x'.$argdb{'PORTPREF'} ne 'x' ) {
	    $Qr_in .= " and portpref='".$argdb{'PORTPREF'}."'";
	} else {
	    $Qr_in .= " and portpref is NULL";
	}
	my $stm33 = $dbm->prepare($Qr_in);
	$stm33->execute();
        while (my $ref33 = $stm33->fetchrow_hashref() and $stm33->rows == 1 ) {
	    my $Qr_check = "SELECT port_id FROM port_vlantag WHERE port_id=".$ref33->{'port_id'}." and vlan_id=".$argdb{'VLAN'};
	    my $stm331 = $dbm->prepare($Qr_check);
	    $stm331->execute();
	    # Temp 
	    if ( $stm331->rows > 0 ) {
		if ("x".$argdb{'ACT'} eq 'xadd')    { $res =  1; }   # VLAN найден в транке, не добавлять
		#if ("x".$argdb{'ACT'} eq 'xremove') { $res = -1; } # VLAN найден в транке, удалить
	    }
	    if ("x".$argdb{'ACT'} eq 'xremove') { $res = -1; }  # VLAN в транке удалить

	    $stm331->finish();
	}
	$stm33->finish();
	return $res;
}

sub VLAN_remove {

        my %arg = (
            @_,         # список пар аргументов
        );
	# PORT_ID VLAN HEAD
	my $res = -1;
	return if ( not defined($arg{'HEAD'}) || not defined($arg{'PORT_ID'}) || not defined($arg{'VLAN'}) );

	return $res if $debug>1;
	my $Qr_zone = "SELECT zone_id FROM heads where head_id=".$arg{'HEAD'};
	my $stm341 = $dbm->prepare($Qr_zone);
        $stm341->execute();
	while (my $ref341 = $stm341->fetchrow_hashref()) {
	    $arg{'ZONE'} = $ref341->{'zone_id'};
	}
	$stm341->finish();

	my $Qr_in = "SELECT p.port_id FROM swports p, heads h WHERE h.head_id=p.head_id and p.port_id<>".$arg{'PORT_ID'}.
	" and p.vlan_id=".$arg{'VLAN'}." and h.zone_id=".$arg{'ZONE'};

	my $stm34 = $dbm->prepare($Qr_in);
	$stm34->execute();
	if ( $stm34->rows > 0 ) {
	    $res =  0;
	} else {
	    dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DELETE from vlan_list VLAN=".$arg{'VLAN'}." ZONE=".$arg{'ZONE'} );
	    $dbm->do("DELETE from vlan_list WHERE vlan_id=".$arg{'VLAN'}." and zone_id=".$arg{'ZONE'});
	    $res =  1;
	}
	$stm34->finish();
	return $res;
}


sub VLAN_get {

        my %arg = (
            @_,         # список пар аргументов
        );
	# PORT_ID VLAN_MIN VLAN_MAX LINK_TYPE ZONE 

	my $res = -1; my $increment = 1;

#	return $res if $debug>1;
	my %vlanuse = ();
	my $Qr_range = "SELECT vlan_id FROM vlan_list WHERE vlan_id>=".$arg{'VLAN_MIN'}." and vlan_id<=".$arg{'VLAN_MAX'}." and zone_id=".$arg{'ZONE'};
        my $stm35 = $dbm->prepare($Qr_range);
        $stm35->execute();
	while (my $ref35 = $stm35->fetchrow_hashref()) {
	    $vlanuse{$ref35->{'vlan_id'}} = 1;
	}
	$stm35->finish();
		
	my $vlan_id=0; 
	if ($increment) {
	    $vlan_id = $arg{'VLAN_MIN'};
	    while ( $res < 1 and $vlan_id <= $arg{'VLAN_MAX'} ) {
		dlog ( SUB => (caller(0))[3], DBUG => 2, MESS => "PROBE VLAN N".$vlan_id." VLANDB -> '".$vlanuse{$vlan_id}."'" );
		$res = $vlan_id if not defined($vlanuse{$vlan_id});
		$vlan_id += 1;
	    }
	} else {
	    $vlan_id = $arg{'VLAN_MAX'};
	    while ( $res < 1 and $vlan_id >= $arg{'VLAN_MIN'} ) {
		dlog ( SUB => (caller(0))[3], DBUG => 2, MESS => "PROBE VLAN N".$vlan_id." VLANDB -> '".$vlanuse{$vlan_id}."'" );
		$res = $vlan_id if not defined($vlanuse{$vlan_id});
		$vlan_id -= 1;
	    }
	}

	$dbm->do("INSERT into vlan_list SET info='AUTO INSERT VLAN record from vlan range', vlan_id=".$res.", zone_id=".$arg{'ZONE'}.
	", port_id=".$arg{'PORT_ID'}.", ltype_id=".$arg{'LINK_TYPE'}." ON DUPLICATE KEY UPDATE info='AUTO UPDATE VLAN record', port_id=".
	$arg{'PORT_ID'}.", ltype_id=".$arg{'LINK_TYPE'}) if ($res > 0 and $debug < 2);
	return $res;
}

