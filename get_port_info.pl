#!/usr/bin/perl

$debug=1;
my $ver='1.092';
#$VERSION = 0.97;

use Getopt::Long;

#use strict;
use POSIX qw(strftime);
use DBI();
use locale;


my $PROG=$0;
if ( $PROG =~ /(\S+)\/(\S+)$/ ) {
    require $1.'/conf/config.pl';
    print STDERR "USE PROGRAMM DIRECTORY => $1\n\n" if $debug;
} else {
    require '/usr/local/swctl/conf/config.pl';
    print STDERR "USE STANDART PROGRAMM DIRECTORY\n\n";
}

my $dbm = DBI->connect("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'}) or die("connect");
$dbm->do("SET NAMES 'koi8r'");

my %libs = ();
$stm0 = $dbm->prepare("SELECT id, lib FROM models order by id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $libs{$ref0->{'lib'}}=$ref0->{'id'} if defined($ref0->{'lib'});
#    $libctl= "$ref0->{'lib'}Ctl";
}
$stm0->finish();

my %port_status = ();
$stm0 = $dbm->prepare("SELECT id, name FROM port_status order by id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $port_status{$ref0->{'name'}}=$ref0->{'id'} if defined($ref0->{'name'});
}
$stm0->finish();

my %link_type = ();
my @link_types = '';

$stm0 = $dbm->prepare("SELECT id, name FROM link_types order by id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $link_type{$ref0->{'name'}}=$ref0->{'id'} if defined($ref0->{'name'});
    $link_types[$ref0->{'id'}]=$ref0->{'name'} if defined($ref0->{'name'});
}
$stm0->finish();

my @sw_models = '';

$stm0 = $dbm->prepare("SELECT id, model FROM models order by id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $sw_models[$ref0->{'id'}]=$ref0->{'model'} if defined($ref0->{'model'});
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

my $LIB_action = '';
my $res=0;
my $resport=0;
my $point='';
my $Querry_portfix = '';

if (not defined($ARGV[0])) {
    print STDERR "Usage: get_port_info.pl ( host <hostname switch> | ip <IP switch> | allhosts )\n"

} elsif ( $ARGV[0] eq "host" ) {
    ################################ SYNC LINK STATES
    my $stml = $dbm->prepare("SELECT l.head_id, l.port_id, l.vlan_id, l.status, l.set_status, p.link_type, p.login, p.ip_subnet, p.login \
    FROM swports p, head_link l WHERE l.set_status>0 and l.port_id=p.port_id ORDER BY l.head_id");
    $stml->execute();

    while (my $ref = $stml->fetchrow_hashref()) {
    $point = "\nLINK: ip_subnet => ".$ref->{'ip_subnet'}.", conf_type => ".$link_types[$ref->{'set_status'}];

	if ( $ref->{'set_status'} == $link_type{'up'} || $ref->{'set_status'} == $link_type{'down'} ) {
	    print STDERR "\n\n#############\n Control <<".$link_types[$ref->{'set_status'}].">> LINK in Terminator $point\n##############\n";

    	    $head = GET_Terminfo ( TERM_ID => $ref->{'head_id'} );

            $LIB_action = $head->{'TERM_LIB'}.'_term_'.$link_types[$ref->{'link_type'}].'_'.$link_types[$ref->{'set_status'}];
            $res = &$LIB_action( IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
            ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'},
            VLAN => $ref->{'vlan_id'}, LOOP_IF => $head->{'LOOP_IF'}, UP_ACLIN => $head->{'UP_ACLIN'}, UP_ACLOUT => $head->{'UP_ACLOUT'}, 
	    DOWN_ACLIN => $head->{'DOWN_ACLIN'}, DOWN_ACLOUT => $head->{'DOWN_ACLOUT'});
    	    next if $res < 1;
	    $res = SAVE_config(LIB => $head->{'TERM_LIB'}, SWID => -1, IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
	    ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}); next if $res < 1;

	    $dbm->do("UPDATE head_link SET status=".$ref->{'set_status'}.", set_status=0 WHERE port_id=".$ref->{'port_id'}." and vlan_id=".$ref->{'vlan_id'});
	}
    }
    $stml->finish;

} elsif ( $ARGV[0] eq "ip" ) {

    #print STDERR "Switch ports configuring\n";
    ################################ SET PORT PARAMETERS
    $SW{'change'} = 0;
    $SW{'sw_id'}=0;
    my $act=''; my $ds=64; my $us=64;
    ############################ CHECK for UPDATES PORTS PARAMETERS CYCLE ########################
    $stm2 = $dbm->prepare("SELECT h.hostname, h.clients_vlan, h.model, h.ip, h.uplink_port, h.uplink_portpref, h.parent, h.parent_port, \
    h.parent_portpref, h.vlan_zone, h.automanage, \
    p.sw_id, p.port_id, p.port, p.portpref, p.ds_speed, p.us_speed, p.autoconf, p.portvlan, p.link_head, p.autoneg, p.speed, p.duplex, p.maxhwaddr, p.tag, \
    p.link_type, p.login, p.ip_subnet, p.login, \
    m.lib, m.bw_free, m.admin_login, m.admin_pass, m.ena_pass FROM hosts h, swports p, models m \
    WHERE h.model=m.id and h.id=p.sw_id and p.type>0 and p.autoconf>0 and p.autoconf<=".$conf{'STARTLINKCONF'}." and p.autoconf<>".$link_type{'uplink'}." and h.automanage=1 order by h.model, p.sw_id, p.portpref, p.port");
    $stm2->execute();

    while (my $ref = $stm2->fetchrow_hashref()) {
    #print STDERR "Switch ports configuring ".$conf{'STARTLINKCONF'}."\n";

	############ SAVE PREVIOUS SWITCH CONFIG
	if ( $SW{'change'} and $SW{'sw_id'} != $ref->{'sw_id'} and defined($libs{$SW{'lib'}}) ) {
    	    $SW{'change'} = 0;
	    SAVE_config( LIB => $SW{'lib'}, SWID => $SW{'sw_id'}, IP => $SW{'swip'}, LOGIN => $SW{'admin'}, PASS => $SW{'adminpass'}, ENA_PASS => $SW{'ena_pass'}); 
	}
	
	print STDERR "Switch LIB '".$ref->{'lib'}."' not exists!!! for switch '".$ref->{'hostname'}."'\n" if not defined($libs{$ref->{'lib'}});

	$res=0;
        $point = "\nPOINT: switch => ".$ref->{'hostname'}.", port => ".$ref->{'portpref'}.$ref->{'port'}.", model => ".$sw_models[$ref->{'model'}].
	", conf_type => ".$link_types[$ref->{'autoconf'}];

        $SW{'sw_id'}=$ref->{'sw_id'};
        $SW{'swip'}=$ref->{'ip'}		if defined($ref->{'ip'});
	$SW{'lib'}=$ref->{'lib'} 		if defined($ref->{'lib'});
	$SW{'admin'}=$ref->{'admin_login'} 	if defined($ref->{'admin_login'});
	$SW{'adminpass'}=$ref->{'admin_pass'}	if defined($ref->{'admin_pass'});
	$SW{'ena_pass'}=$ref->{'ena_pass'}      if defined($ref->{'ena_pass'});

	if ($ref->{'autoconf'} < $conf{'STARTPORTCONF'}) {
	    $Querry_portfix = "UPDATE swports SET complete_q=1 ";
	} else {
	    $Querry_portfix = "UPDATE swports SET complete_q=1, link_type=".$ref->{'autoconf'};
	}
	print STDERR "\n\n#############\n Configure <<".$link_types[$ref->{'autoconf'}].">> LINK $point\n##############\n";

## CONFIGURE FREE PORT
	if ( $ref->{'autoconf'} == $link_type{'free'} and ($ref->{'portvlan'} == $ref->{'clients_vlan'} || $ref->{'portvlan'} < 1 ) ) {
	    next if $debug>2;
	    next if $ref->{'portvlan'} == 1;

	    $Querry_portfix  .=  ", status=".$port_status{'enable'}.", us_speed=".$ref->{'bw_free'}.", ds_speed=".$ref->{'bw_free'}.
	    ", client_address=NULL, tag=0, start_date=NULL, mac_port=NULL, info=NULL, login=NULL, maxhwaddr=-1, link_head=NULL, \
	    autoneg=1, speed=NULL, duplex=NULL";
	    $ds=$ref->{'bw_free'}; $us=$ref->{'bw_free'};

	    ## Освобождаем клиентский порт текущего коммутатора
	    $LIB_action = $ref->{'lib'}.'_port_free';
	    $res = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, 
	    VLAN => $ref->{'clients_vlan'}, PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}, DS => $ref->{'bw_free'}, US => $ref->{'bw_free'}, 
	    UPLINKPORT => $ref->{'uplink_port'}, UPLINKPORTPREF => $ref->{'uplink_portpref'}) if defined($libs{$ref->{'lib'}}); next if $res < 1;
            $SW{'change'} += 1;
	    $Querry_portfix  .=  " WHERE autoconf=".$link_type{'free'};

## CONFIGURE PORT SETTINGS
	} elsif ( $ref->{'autoconf'} < $conf{'STARTLINKCONF'} and $ref->{'autoconf'} != $link_type{'uplink'} ) {
	    next if $debug>2;

	    ############# PORT DISABLE
	    if ($ref->{'autoconf'} == $link_type{'down'}) {
	    $Querry_portfix  .=  ", status=".$port_status{'disable'};

	    ############# SET PORT is DEFECT 
	    } elsif ($ref->{'autoconf'} == $link_type{'defect'}) {
	    $Querry_portfix  .=  ", status=".$port_status{'disable'}.", us_speed=NULL, ds_speed=NULL, client_address=NULL, tag=0, \
	    portvlan=-1, start_date=NULL, mac_port=NULL, info=NULL, login=NULL, maxhwaddr=-1, link_head=NULL, autoneg=1, speed=NULL, duplex=NULL";

	    ############# PORT TYPE TRUNK
	    } elsif ($ref->{'autoconf'} == $link_type{'trunk'}) {
	    $Querry_portfix .= ", status=".$port_status{'enable'}.", ds_speed=-1, us_speed=-1"

	    } elsif ($ref->{'autoconf'} == $link_type{'uplink'}) {
	    $Querry_portfix .= ", status=".$port_status{'enable'}.", ds_speed=-1, us_speed=-1"

	    ############# PORT TYPE SYSTEM
	    #} elsif ($ref->{'autoconf'} == $link_type{'system'}) {
	    #$Querry_portfix .= ", status=".$port_status{'enable'};

	    ############# PORT SET PARAMETERS
	    #} elsif ($ref->{'autoconf'} == $link_type{'setparms'}) {
	    #$Querry_portfix .= ", status=".$port_status{'enable'};

	    ############# PORT ENABLE
	    #} elsif ($ref->{'autoconf'} == $link_type{'up'}) {
	    #$Querry_portfix .= ", status=".$port_status{'enable'};
	    } else {
	    	$Querry_portfix .= ", status=".$port_status{'enable'};
	    }

	    $LIB_action = $ref->{'lib'}.'_port_'.$link_types[$ref->{'autoconf'}];
	    $res = &$LIB_action( IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, PORT => $ref->{'port'}, 
	    PORTPREF => $ref->{'portpref'}, DS => $ref->{'ds_speed'}, US => $ref->{'us_speed'}, VLAN => $ref->{'portvlan'}, TAG => $ref->{'tag'},
	    MAXHW => $ref->{'maxhwaddr'}, AUTONEG => $ref->{'autoneg'}, SPEED => $ref->{'speed'}, DUPLEX => $ref->{'duplex'});
	    next if $res < 1;
            $SW{'change'} += 1;
	    $Querry_portfix  .=  " WHERE autoconf=".$ref->{'autoconf'};

	}
	# Помечаем в BD изменения на порту
	$Querry_portfix  .=  " and port_id=".$ref->{'port_id'};
	#print STDERR $Querry_portfix."\n" if $debug;
	$dbm->do($Querry_portfix) if $res > 0;
    }
    # SAVE LAST SWITCH CONFIG to NVRAM
    SAVE_config( LIB => $SW{'lib'}, SWID => $SW{'sw_id'}, IP => $SW{'swip'}, LOGIN => $SW{'admin'}, PASS => $SW{'adminpass'}, ENA_PASS => $SW{'ena_pass'})
    if ($SW{'change'} and defined($libs{$SW{'lib'}}));
    $stm2->finish();

} elsif ( $ARGV[0] eq "checklink" ) {
    ################################ SET PORT PARAMETERS

    $SW{'change'} = 0;
    $SW{'sw_id'}=0;
    my $act=''; my $ds=64; my $us=64; my $trunking_vlan = 1;
    ############################ CHECK for UPDATES PORTS PARAMETERS CYCLE ########################
    $stm2 = $dbm->prepare("SELECT h.hostname, h.clients_vlan, h.model, h.ip, h.uplink_port, h.uplink_portpref, h.parent, h.parent_port, \
    h.parent_portpref, h.vlan_zone, h.automanage, \
    p.sw_id, p.port_id, p.port, p.portpref, p.ds_speed, p.us_speed, p.autoconf, p.portvlan, p.link_head, p.autoneg, p.speed, p.duplex, p.maxhwaddr, p.tag, \
    p.link_type, p.login, p.ip_subnet, p.login, \
    m.lib, m.bw_free, m.admin_login, m.admin_pass, m.ena_pass FROM hosts h, swports p, models m \
    WHERE h.model=m.id and h.id=p.sw_id and p.type>0 and p.autoconf>=".$conf{'STARTPORTCONF'}." and h.automanage=1 order by h.model, p.sw_id, p.portpref, p.port");

    $stm2->execute();

    while (my $ref = $stm2->fetchrow_hashref()) {
	############ SAVE PREVIOUS SWITCH CONFIG
	if ( $SW{'change'} and $SW{'sw_id'} != $ref->{'sw_id'} and defined($libs{$SW{'lib'}}) and 
	( $ref->{'autoconf'} == $link_type{'uplink'} || $ref->{'autoconf'} >= $conf{'STARTLINKCONF'} )) {
	    $SW{'change'} = 0;
 	    $res = SAVE_config(LIB => $SW{'lib'}, SWID => $SW{'sw_id'}, IP => $SW{'swip'}, LOGIN => $SW{'admin'}, 
	    PASS => $SW{'adminpass'}, ENA_PASS => $SW{'ena_pass'}); 
	    next if $res < 1;
	}
	
	print STDERR "Switch LIB '".$ref->{'lib'}."' not exists!!! for switch '".$ref->{'hostname'}."'\n" if not defined($libs{$ref->{'lib'}});

	$res=0;
	$resport=0;
        $point = "\nPOINT: switch => ".$ref->{'hostname'}.", port => ".$ref->{'portpref'}.$ref->{'port'}.", model => ".$sw_models[$ref->{'model'}].
	", conf_type => ".$link_types[$ref->{'autoconf'}];

        $SW{'sw_id'}=$ref->{'sw_id'};
        $SW{'swip'}=$ref->{'ip'}		if defined($ref->{'ip'});
	$SW{'lib'}=$ref->{'lib'} 		if defined($ref->{'lib'});
	$SW{'admin'}=$ref->{'admin_login'} 	if defined($ref->{'admin_login'});
	$SW{'adminpass'}=$ref->{'admin_pass'}	if defined($ref->{'admin_pass'});
	$SW{'ena_pass'}=$ref->{'ena_pass'}      if defined($ref->{'ena_pass'});

	if ($ref->{'autoconf'} < $conf{'STARTPORTCONF'}) {
	    $Querry_portfix = "UPDATE swports SET complete_q=1 ";
	} else {
	    $Querry_portfix = "UPDATE swports SET complete_q=1, link_type=".$ref->{'autoconf'};
	}
	print STDERR "\n\n#############\n Configure <<".$link_types[$ref->{'autoconf'}].">> LINK $point\n##############\n";


#### FREE LINK
	if ($ref->{'autoconf'} == $link_type{'free'} and $ref->{'portvlan'} != $ref->{'clients_vlan'}) {

	    #print STDERR "Configure FREE LINK $point\n";
	    next if $debug>2;
	    next if $ref->{'portvlan'} == 1;
    	    $head = GET_Terminfo( TYPE => $ref->{'link_type'}, ZONE => $ref->{'vlan_zone'}, TERM_ID => $ref->{'link_head'});

	    $Querry_portfix  .=  ", status=".$port_status{'enable'}.", us_speed=".$ref->{'bw_free'}.", ds_speed=".$ref->{'bw_free'}.
	    ", client_address=NULL, tag=0, start_date=NULL, mac_port=NULL, info=NULL, login=NULL, maxhwaddr=-1, link_head=NULL, \
	    autoneg=1, speed=NULL, duplex=NULL";
	    $ds=$ref->{'bw_free'}; $us=$ref->{'bw_free'}; $trunking_vlan = 1; 
		
	    $Querry_portfix  .=  ", portvlan=".$ref->{'clients_vlan'} if ( $ref->{'clients_vlan'} > 1 );

	    # если VLAN на свиче установлен, а на порту не установлен 
	    if ( $ref->{'clients_vlan'} > 1 and $ref->{'portvlan'} < 1 ) {
	        $trunking_vlan = 0;
	    # Если тип порта вне диапазоне линкуемых типов
	    } elsif ( not $ref->{'link_type'} > $link_type{'free'} ) {
		$trunking_vlan = 0;
	    } elsif ( not defined($ref->{'clients_vlan'}) and $ref->{'portvlan'} < 1 ) {
	        $trunking_vlan = 0;
	    } elsif ( $ref->{'portvlan'} > 0 ) {
	        my $stm32 = $dbm->prepare("SELECT port_id FROM swports WHERE portvlan=".$ref->{'portvlan'}." and port_id<>".$ref->{'port_id'});
	        $stm32->execute();
	        # если VLAN используется на других точках подключения, кроме текущей
	        $trunking_vlan = 0 if ($stm32->rows > 0 );
 	        $stm32->finish();
	    } else {
	        $trunking_vlan = 0;
	    }
	    if ($trunking_vlan) {
		## Убираем VLAN c Терминатора, согласно типа подключения.
		if ( $head->{'TERM_USE'} ) {
		    my ($ipcli, $ipgw, $netmask ) = GET_GW_parms (SUBNET => $ref->{'ip_subnet'}, TYPE => $ref->{'autoconf'});
		    $LIB_action = $head->{'TERM_LIB'}.'_term_'.$link_types[$ref->{'link_type'}].'_remove';
		    $res = &$LIB_action( IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
		    ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'},
		    VLAN => $ref->{'portvlan'}, LOOP_IF => $head->{'LOOP_IF'}, IPCLI => $ipcli, IPGW => $ipgw, NETMASK => $netmask);
		    next if $res < 1;
		    $res = SAVE_config(LIB => $head->{'TERM_LIB'}, SWID => -1, IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
		    ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}); next if $res < 1;
		    $dbm->do("DELETE FROM head_link WHERE port_id=".$ref->{'port_id'}." and vlan_id=".$ref->{'portvlan'});
		} else {
		    print STDERR "Head link not USE for this link type, AP '".$point."'\n" if $debug;
		}
	        # Убираем VLAN по всей цепочке транковых портов вплоть до коммутатора непосредственно связанного с терминатором.
		$res = VLAN_link(LIB => $ref->{'lib'}, ACT => 'remove', TYPE => $ref->{'link_type'}, SWID => $ref->{'sw_id'}, IP => $ref->{'ip'}, 
		LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, VLAN => $ref->{'portvlan'}, 
		PARENT => $ref->{'parent'}, PARENTPORT => $ref->{'parent_port'}, PARENTPORTPREF => $ref->{'parent_portpref'},
		L2HEAD => $head->{'L2SW_ID'}, L2HEAD_PORT => $head->{'L2SW_PORT'}, L2HEAD_PORTPREF => $head->{'L2SW_PORTPREF'}) 
		if ( defined($ref->{'uplink_port'}) and defined($ref->{'parent'}) and defined($ref->{'parent_port'}));
		#next if $res < 1;
		## Убираем VLAN на UPLINK порту текущего коммутатора
                print STDERR "REMOVE VLAN in UPLINK port\n" if $debug;
	      if ($ref->{'uplink_port'} > 0 and DB_trunk_vlan(ACT => 'remove', SWID => $ref->{'sw_id'}, VLAN => $ref->{'portvlan'}, PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'}) < 1) {
		$LIB_action = $ref->{'lib'}.'_vlan_trunk_remove';
    	        $res = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, VLAN => $ref->{'portvlan'},
	        PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'}); next if $res < 1;
		$SW{'change'} += 1;
	        DB_trunk_update(ACT => 'remove', SWID => $ref->{'sw_id'}, PORTPREF => $ref->{'uplink_portpref'}, PORT => $ref->{'uplink_port'}, VLAN => $ref->{'portvlan'});
	      } elsif ($ref->{'uplink_port'} < 1) {
		print STDERR "Trunking vlan chains skip uplink in ".$ref->{'hostname'}.", UPLINK_PORT not SET  :-( ...\n";
	      } else {
		print STDERR "Trunking vlan uplink in ".$ref->{'hostname'}.", already remove in DB :-) ...\n";
	      }


	    }
	    ## Освобождаем клиентский порт текущего коммутатора
	    $LIB_action = $ref->{'lib'}.'_port_free';
	    $resport = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, VLAN => $ref->{'clients_vlan'}, 
	    PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}, DS => $ref->{'bw_free'}, US => $ref->{'bw_free'}, UPLINKPORT => $ref->{'uplink_port'}, 
	    UPLINKPORTPREF => $ref->{'uplink_portpref'}) if defined($libs{$ref->{'lib'}}); next if $resport < 1;
	    $SW{'change'} += 1;
 	    $Querry_portfix  .=  " WHERE autoconf=".$link_type{'free'};
	    VLAN_remove(PORT_ID => $ref->{'port_id'}, VLAN => $ref->{'portvlan'}, LINK_TYPE => $ref->{'link_type'}, ZONE => $ref->{'vlan_zone'});

#### UPLINK PORT
	} elsif ( $ref->{'autoconf'} == $link_type{'uplink'} ) {
	    ## Настройка UPLINK порта
            next if $debug>2;
	    next if $ref->{'portvlan'} < 1;
	    $ds=$ref->{'ds_speed'}; $us=$ref->{'us_speed'}; $trunking_vlan = 1;


	    # Настройка непосредственно параметров порта
	    print STDERR "Configure  UPLINK port !!!\n";
	    $LIB_action = $ref->{'lib'}.'_port_trunk';
	    $res = &$LIB_action( IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, PORT => $ref->{'port'},
            PORTPREF => $ref->{'portpref'}, DS => $ref->{'ds_speed'}, US => $ref->{'us_speed'}, VLAN => $ref->{'portvlan'}, TAG => $ref->{'tag'},
            MAXHW => $ref->{'maxhwaddr'}, AUTONEG => $ref->{'autoneg'}, SPEED => $ref->{'speed'}, DUPLEX => $ref->{'duplex'}); next if $res < 1;
	    $SW{'change'} += 1;
 
	    $trunking_vlan=0 if not defined($ref->{'clients_vlan'});
	    $ref->{'portvlan'} = $ref->{'clients_vlan'};
	    $Querry_portfix .=", status=".$port_status{'enable'};
	    if ($trunking_vlan) {
	      ## Добавляем VLAN на UPLINK порту текущего коммутатора
	      if ($ref->{'port'} > 0 and DB_trunk_vlan(ACT => 'add', SWID => $ref->{'sw_id'}, VLAN => $ref->{'portvlan'}, PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}) < 1) {
        	print STDERR "ADD VLAN in UPLINK port\n" if $debug;
    		$LIB_action = $ref->{'lib'}.'_vlan_trunk_add';
    		$resport = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, VLAN => $ref->{'portvlan'},
		PORT => $ref->{'port'}, PORTPREF => $ref->{'portpref'}, UPLINKPORTPREF => $ref->{'portpref'}, UPLINKPORT => $ref->{'port'}); next if $resport < 1;
		$SW{'change'} += 1;
		DB_trunk_update(ACT => 'add', SWID => $ref->{'sw_id'}, PORTPREF => $ref->{'portpref'}, PORT => $ref->{'port'}, VLAN => $ref->{'portvlan'});
	      } elsif ($ref->{'port'} < 1) {
		print STDERR "Trunking vlan chains skip uplink in ".$ref->{'hostname'}.", UPLINK_PORT not SET  :-( ...\n";
	      } else {
		print STDERR "Trunking vlan uplink in ".$ref->{'hostname'}.", already add in DB :-) ...\n";
	      }

		$head = GET_Terminfo( TYPE => $conf{'CLI_VLAN_LINKTYPE'}, ZONE => $ref->{'vlan_zone'});
		$Querry_portfix .=", link_head=".$head->{'HEAD_ID'};

		# Прокидываем  VLAN по всем транковым портам вплоть до коммутатора непосредственно связанного с терминатором.
		print STDERR "linking trunk ports \n" if $debug;
		#print STDERR " L2SW - ".$head->{'L2SW_PORTPREF'}."_".$head->{'L2SW_PORT'}."\n" if $debug;
		
		$res = VLAN_link(LIB => $ref->{'lib'}, ACT => 'add', TYPE => $conf{'CLI_VLAN_LINKTYPE'}, 
		SWID => $ref->{'sw_id'}, IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'},
		VLAN => $ref->{'portvlan'}, UPLINKPORT => $ref->{'uplink_port'}, UPLINKPORTPREF => $ref->{'uplink_portpref'},
		PARENT => $ref->{'parent'}, PARENTPORT => $ref->{'parent_port'}, PARENTPORTPREF => $ref->{'parent_portpref'},
		L2HEAD => $head->{'L2SW_ID'}, L2HEAD_PORT => $head->{'L2SW_PORT'}, L2HEAD_PORTPREF => $head->{'L2SW_PORTPREF'})
		if ( defined($ref->{'uplink_port'}) and defined($ref->{'parent'}) and defined($ref->{'parent_port'})); next if $res < 1;

		## Терминируем VLAN, согласно текущего типа подключения 
		if ( $ref->{'portvlan'} >= $head->{'VLAN_MIN'} and $ref->{'portvlan'} <= $head->{'VLAN_MAX'} ) {
		    if ( $head->{'TERM_USE'} ) {
			#IP LOGIN PASS ENA_PASS IFACE VLAN VLANNAME IPGW NETMASK ACLIN ACLOUT
			my ($ipcli, $ipgw, $netmask) = GET_GW_parms (SUBNET => $ref->{'ip_subnet'}, TYPE => $conf{'CLI_VLAN_LINKTYPE'});
			$LIB_action = $head->{'TERM_LIB'}.'_term_'.$link_types[$conf{'CLI_VLAN_LINKTYPE'}].'_add';
			$res = &$LIB_action( IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
			ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'},
			VLAN => $ref->{'portvlan'}, VLANNAME => $ref->{'hostname'}.'_port_'.$ref->{'portpref'}.$ref->{'port'}.'_'.$ref->{'login'}, IPCLI => $ipcli,
			IPGW => $ipgw, NETMASK => $netmask, UP_ACLIN => $head->{'UP_ACLIN'}, UP_ACLOUT => $head->{'UP_ACLOUT'}, LOOP_IF => $head->{'LOOP_IF'});
			next if $res < 1;
			# Сохраняем конфиг на терминаторе
			$res = SAVE_config(LIB => $head->{'TERM_LIB'}, SWID => -1, IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
			ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}); next if $res < 1;

		    } else {
			print STDERR "\nUPLINK VLAN terminate succesfull\n" if $debug;
		    }
		} else {
		     print STDERR "Port VLAN '".$ref->{'portvlan'}."' not in Terminator '".$link_types[$conf{'CLI_VLAN_LINKTYPE'}]."' VLAN range '".$head->{'VLAN_MIN'}."' - '".$head->{'VLAN_MAX'}."'\n";
		}
	    }
	    $Querry_portfix  .=  " WHERE autoconf=".$link_type{'uplink'};


######## Остальные типы линков
	} elsif ( $ref->{'autoconf'} > $conf{'STARTLINKCONF'} ) {


            next if $debug>2;
            next if ( $ref->{'portvlan'} == 1 );
            $ds=$ref->{'ds_speed'}; $us=$ref->{'us_speed'}; $trunking_vlan = 1;
            print STDERR "Start linking\n" if $debug;
            # Завершаем если нет вменяемого номера влана
            next if ( $ref->{'portvlan'} < 1 and not defined($ref->{'clients_vlan'}));

	    if (not defined($ref->{'clients_vlan'}) and $ref->{'portvlan'} < 1 ) {
		if ($ref->{'autoconf'} == $conf{'CLI_VLAN_LINKTYPE'}) {
		    print STDERR " Clients VLAN not defined in switch ".$ref->{'hostname'}."! Next\n" 
		} else {
		    print STDERR " PORT VLAN not defined in port ".$ref->{'portpref'}.$ref->{'port'}."switch ".$ref->{'hostname'}."! Next\n" 
		}
		next;
	    }
	    if ( $ref->{'autoconf'} == $conf{'CLI_VLAN_LINKTYPE'} and defined($ref->{'clients_vlan'}) ) {
                $trunking_vlan=0;
		if ( $ref->{'portvlan'} < 1 ) {
            	    $ref->{'portvlan'} = $ref->{'clients_vlan'};
		    $Querry_portfix  .=  ", portvlan=".$ref->{'clients_vlan'} 
		} elsif ($ref->{'portvlan'} != $ref->{'clients_vlan'}) {
		    $trunking_vlan=1;
		}
	    } 
            $head = GET_Terminfo( TYPE => $ref->{'autoconf'}, ZONE => $ref->{'vlan_zone'});
	    ### Выясняем необходимость выделения и номер влана для использования
	    if ( $ref->{'portvlan'} < 2 and $ref->{'link_type'} != $link_type{'uplink'}) {
		$ref->{'portvlan'} = VLAN_get(PORT_ID => $ref->{'port_id'}, LINK_TYPE => $ref->{'autoconf'}, ZONE => $ref->{'vlan_zone'}, VLAN_MIN => $head->{'VLAN_MIN'}, VLAN_MAX => $head->{'VLAN_MAX'});
		next if $ref->{'portvlan'} < 1;
	    }

            ## Прописываем VLAN на клиентском порту текущего коммутатора
            print STDERR "Config CLIENT port parameters and set VLAN ".$ref->{'portvlan'}."\n" if $debug;
            $LIB_action = $ref->{'lib'}.'_port_setparms';
            $resport = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, 
	    VLAN => $ref->{'portvlan'}, PORTPREF => $ref->{'portpref'}, PORT => $ref->{'port'}, UPLINKPORTPREF => $ref->{'uplink_portpref'}, 
	    UPLINKPORT => $ref->{'uplink_port'}, DS => $ref->{'ds_speed'}, US => $ref->{'us_speed'}, TAG => $ref->{'tag'}, MAXHW => $ref->{'maxhwaddr'},
	    AUTONEG => $ref->{'autoneg'}, SPEED => $ref->{'speed'}, DUPLEX => $ref->{'duplex'}) if defined($libs{$ref->{'lib'}}); next if $resport < 1;
	    $SW{'change'} += 1;
            $Querry_portfix .=", link_head=".$head->{'HEAD_ID'}.", status=".$port_status{'enable'};

            if ($trunking_vlan) {
                ## Добавляем VLAN на UPLINK порту текущего коммутатора
	      if ($ref->{'uplink_port'} > 0 and DB_trunk_vlan(ACT => 'add', SWID => $ref->{'sw_id'}, VLAN => $ref->{'portvlan'}, PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'}) < 1) {
                print STDERR "ADD VLAN in UPLINK port\n" if $debug;
    		$LIB_action = $ref->{'lib'}.'_vlan_trunk_add';
    		$resport = &$LIB_action(IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'}, VLAN => $ref->{'portvlan'},
		PORT => $ref->{'uplink_port'}, PORTPREF => $ref->{'uplink_portpref'}, UPLINKPORTPREF => $ref->{'uplink_portpref'}, UPLINKPORT => $ref->{'uplink_port'}); next if $resport < 1;
		$SW{'change'} += 1;
		DB_trunk_update(ACT => 'add', SWID => $ref->{'sw_id'}, PORTPREF => $ref->{'uplink_portpref'}, PORT => $ref->{'uplink_port'}, VLAN => $ref->{'portvlan'});
	      } elsif ($ref->{'uplink_port'} < 1) {
		print STDERR "Trunking vlan chains skip uplink in ".$ref->{'hostname'}.", UPLINK_PORT not SET  :-( ...\n";
	      } else {
		print STDERR "Trunking vlan uplink in ".$ref->{'hostname'}.", already add in DB :-) ...\n";
	      }
		# Прокидываем  VLAN по всем транковым портам вплоть до коммутатора непосредственно связанного с терминатором.
		print STDERR "linking trunk ports \n" if $debug;
		#print STDERR " L2SW - ".$head->{'L2SW_PORTPREF'}."_".$head->{'L2SW_PORT'}."\n" if $debug;
		
		$res = VLAN_link(LIB => $ref->{'lib'}, ACT => 'add', TYPE => $ref->{'autoconf'}, 
		SWID => $ref->{'sw_id'}, IP => $ref->{'ip'}, LOGIN => $ref->{'admin_login'}, PASS => $ref->{'admin_pass'}, ENA_PASS => $ref->{'ena_pass'},
		VLAN => $ref->{'portvlan'}, UPLINKPORT => $ref->{'uplink_port'}, UPLINKPORTPREF => $ref->{'uplink_portpref'},
		PARENT => $ref->{'parent'}, PARENTPORT => $ref->{'parent_port'}, PARENTPORTPREF => $ref->{'parent_portpref'},
		L2HEAD => $head->{'L2SW_ID'}, L2HEAD_PORT => $head->{'L2SW_PORT'}, L2HEAD_PORTPREF => $head->{'L2SW_PORTPREF'})
		if ( defined($ref->{'parent'}) or $head->{'L2SW_ID'} == $ref->{'sw_id'} );
		if ($res < 1) {
		    print STDERR "VLAN_link lost...\n";
		    next;
		}

		## Терминируем VLAN, согласно текущего типа подключения 
		if ( $ref->{'portvlan'} >= $head->{'VLAN_MIN'} and $ref->{'portvlan'} <= $head->{'VLAN_MAX'} ) {
		    if ( $head->{'TERM_USE'} ) {
			#IP LOGIN PASS ENA_PASS IFACE VLAN VLANNAME IPGW NETMASK ACLIN ACLOUT
			my ($ipcli, $ipgw, $netmask) = GET_GW_parms ( SUBNET => $ref->{'ip_subnet'}, TYPE => $ref->{'autoconf'} );
			
			$LIB_action = $head->{'TERM_LIB'}.'_term_'.$link_types[$ref->{'autoconf'}].'_add';
			$res = &$LIB_action( IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
			ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}, IFACE => $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'},
			VLAN => $ref->{'portvlan'}, VLANNAME => $ref->{'hostname'}.'_port_'.$ref->{'portpref'}.$ref->{'port'}.'_'.$ref->{'login'}, IPCLI => $ipcli,
			IPGW => $ipgw, NETMASK => $netmask, UP_ACLIN => $head->{'UP_ACLIN'}, UP_ACLOUT => $head->{'UP_ACLOUT'}, LOOP_IF => $head->{'LOOP_IF'});
			#print STDERR " Terminate end\n";
			next if $res < 1;
			# Сохраняем конфиг на терминаторе
			$res = SAVE_config(LIB => $head->{'TERM_LIB'}, SWID => -1, IP => $head->{'TERM_IP'}, LOGIN => $head->{'TERM_LOGIN1'}, PASS => $head->{'TERM_PASS1'},
			ENA_LOGIN => $head->{'TERM_LOGIN2'}, ENA_PASS => $head->{'TERM_PASS2'}); next if $res < 1;

			my $head_if= ( $head->{'TERM_PORT'} ne '' ? $head->{'TERM_PORTPREF'}.$head->{'TERM_PORT'}.".".$ref->{'portvlan'} : "Vlan".$ref->{'portvlan'});
			$dbm->do("INSERT Into head_link SET port_id=".$ref->{'port_id'}.", vlan_id=".$ref->{'portvlan'}.", head_id=".$head->{'HEAD_ID'}.
			", ip_subnet='".$ref->{'ip_subnet'}."', login='".$ref->{'login'}."', head_iface='".$head_if."' ON DUPLICATE KEY UPDATE vlan_id=".$ref->{'portvlan'}.
			", head_id=".$head->{'HEAD_ID'}.", ip_subnet='".$ref->{'ip_subnet'}."', login='".$ref->{'login'}."', head_iface='".$head_if."'");

		    } else {
			print STDERR "\nLINK '".$link_types[$ref->{'autoconf'}]."'".$point." terminate succesfull\n" if $debug;
		    }
		} else {
		     print STDERR "Port VLAN '".$ref->{'portvlan'}."' not in Terminator '".$link_types[$ref->{'autoconf'}]."' VLAN range '".$head->{'VLAN_MIN'}."' - '".$head->{'VLAN_MAX'}."'\n";
		}
	    }
	    $Querry_portfix  .=  " WHERE autoconf=".$ref->{'autoconf'};
	}
	# Помечаем в BD изменения на порту
	$Querry_portfix  .=  " and port_id=".$ref->{'port_id'};
	#print STDERR $Querry_portfix."\nresport = $resport\n" if $debug;
	$dbm->do($Querry_portfix) if $resport > 0;
    }
    # SAVE LAST SWITCH CONFIG to NVRAM
    SAVE_config( LIB => $SW{'lib'}, SWID => $SW{'sw_id'}, IP => $SW{'swip'}, LOGIN => $SW{'admin'}, PASS => $SW{'adminpass'}, ENA_PASS => $SW{'ena_pass'} )
    if ($SW{'change'} and defined($libs{$SW{'lib'}}));
    $stm2->finish();
}

$dbm->disconnect();


#################################################### SUBS ############################################################

sub GET_GW_parms {
    print STDERR "GET IP GW info (debug)\n" if $debug > 1;
    my %arg = (
        @_,         # список пар аргументов
    );
    my $GW = ''; my $GW1 = ''; my $MASK ='';  my $CLI_IP ='';
    my $Querry_start = ''; my $Querry_end = '';
    # SUBNET TYPE
    if ( $arg{'TYPE'} >= $conf{'STARTLINKCONF'} ) {
    my @ln = `/usr/local/bin/ipcalc $arg{SUBNET}`;
        foreach (@ln) {
    	    #   print STDERR "lines - $lnv\n";
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
    print STDERR "GET Terminator info (debug)\n" if $debug > 1;
    my %arg = (
        @_,         # список пар аргументов
    );
    # TYPE ZONE
    my %headinfo; my $res = 0;
    $Querry_start = "SELECT * FROM heads WHERE ";
    if ($arg{'TERM_ID'} > 0) {
	$Querry_start .= " head_id=".$arg{'TERM_ID'};
    } else {
	$Querry_start .= " head_type=".$arg{'TYPE'};
	$Querry_end = " and vlan_zone=".$arg{'ZONE'};
    }
    my $stm31 = $dbm->prepare($Querry_start.$Querry_end);
    $stm31->execute();
    if (not $stm31->rows) {
	$stm31->finish();
	$Querry_end = " and vlan_zone = -1";
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
	    #print STDERR "\nHEAD ID - ".$ref31->{'head_id'}."\n";
	}
	$res = 1;
	#$stm31->finish();
	#return \%headinfo;
    } elsif ($stm31->rows > 1)  {
	print STDERR "MULTI TERMINATOR, count = ".$stm31->rows." ;-)\n";
    } else {
	print STDERR "TERMINATOR NOT FOUND :-(\n";
    }
    $stm31->finish();
    return \%headinfo if ($res > 0);
}


sub VLAN_link {

	print "LINKING VLAN to HEAD (debug)\n" if $debug;
	return -1 if $debug>2;
	## Пробрасываем VLAN до головного свича
	my %arglnk = (
	    @_,
	);
	my $res=0; my $count = 0;
	$PAR{'change'} = 0;
	$PAR{'id'} = $arglnk{'PARENT'};
	$PAR{'low_port'} = $arglnk{'PARENTPORT'};
	$PAR{'low_portpref'} = $arglnk{'PARENTPORTPREF'}; 
	## Выбираем коммутаторы по цепочке вплоть до link_head или головного по зоне, центрального.
	while ( $PAR{'id'}>0 and $count < $conf{'MAXPARENTS'} ) {
	    $PAR{'change'} = 0; 
	    $count +=1;
	    $stm21 = $dbm->prepare("SELECT h.hostname, h.model, h.id, h.ip, h.uplink_port, h.uplink_portpref, h.parent, h.parent_port, h.parent_portpref, ".
	    "m.lib, m.admin_login, m.admin_pass, m.ena_pass FROM hosts h, models m WHERE h.model=m.id and h.id=".$PAR{'id'}." order by h.id");
	    $stm21->execute();
	    while (my $ref21 = $stm21->fetchrow_hashref()) {
		if ( 'x'.$ref21->{'lib'} eq 'x' ) {
		    print STDERR "\nLIB not defined for switch ".$ref21->{'hostname'}.", Vlan link break :-( !!!\n" ;
		    $stm21->finish;
		    return -1;
		}
	      $LIB_action = $ref21->{'lib'}.'_vlan_trunk_'.$arglnk{'ACT'};
	      if ( $PAR{'low_port'} > 0 and DB_trunk_vlan(ACT => $arglnk{'ACT'}, SWID => $ref21->{'id'}, VLAN => $arglnk{'VLAN'}, PORTPREF => $PAR{'low_portpref'}, PORT => $PAR{'low_port'}) < 1) {
		## пробрасываем/убираем тэгированный VLAN на присоединённом порту вышестоящего коммутатора
		print STDERR "\n============\nDOWNLINK vlan ".$arglnk{'ACT'}."\n LIB => $ref21->{'lib'},  IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, VLAN => $arglnk{'VLAN'}, ".
		"PORT => $PAR{'low_port'}, PORTPREF => $PAR{'low_portpref'}\n" if $debug;
	    	$res = &$LIB_action(IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, PASS => $ref21->{'admin_pass'}, ENA_PASS => $ref21->{'ena_pass'},
		VLAN => $arglnk{'VLAN'}, PORT => $PAR{'low_port'}, PORTPREF => $PAR{'low_portpref'}, UPLINKPORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORT => $ref21->{'uplink_port'});
		if ($res < 1) {
		    $stm21->finish();
		    return $res;
		}
		$PAR{'change'} += 1;
		# DB Update 
		DB_trunk_update(ACT => $arglnk{'ACT'}, SWID => $ref21->{'id'}, PORTPREF => $PAR{'low_portpref'}, PORT => $PAR{'low_port'}, VLAN => $arglnk{'VLAN'});
	      } elsif ( $PAR{'low_port'} < 1 ) {
		    print STDERR "Trunking vlan chains skip parent link for switch ".$ref21->{'hostname'}.", PARENT_PORT not SET  :-( ...\n";
	      } else {
		    print STDERR "Trunking vlan downlink in ".$ref21->{'hostname'}.", already ".$arglnk{'ACT'}." in DB :-) ...\n";
		    $res = 1;
	      }	
		if ( $PAR{'id'} == $arglnk{'L2HEAD'} ) {
		    if (defined($arglnk{'L2HEAD_PORT'}) and DB_trunk_vlan(ACT => $arglnk{'ACT'}, SWID => $ref21->{'id'}, VLAN => $arglnk{'VLAN'}, PORTPREF => $arglnk{'L2HEAD_PORTPREF'}, PORT => $arglnk{'L2HEAD_PORT'}) < 1) {
			# Пробрасываем/убираем VLAN на порту стыковки последнего свича с терминатором
			print STDERR "\n============\nSWITCHTERM vlan ".$arglnk{'ACT'}."\n LIB => $ref21->{'lib'}, IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, VLAN => $arglnk{'VLAN'}, ".
			"PORT => $arglnk{'L2HEAD_PORT'}, PORTPREF => $arglnk{'L2HEAD_PORTPREF'}\n" if $debug;
			$res = &$LIB_action(IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, PASS => $ref21->{'admin_pass'}, ENA_PASS => $ref21->{'ena_pass'},
                	VLAN => $arglnk{'VLAN'}, PORT => $arglnk{'L2HEAD_PORT'}, PORTPREF => $arglnk{'L2HEAD_PORTPREF'}, UPLINKPORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORT => $ref21->{'uplink_port'});
			if ($res < 1) {
			    $stm21->finish();
			    return $res;
			}
			$PAR{'change'} += 1;
			DB_trunk_update(ACT => $arglnk{'ACT'}, SWID => $ref21->{'id'}, PORTPREF => $arglnk{'L2HEAD_PORTPREF'}, PORT => $arglnk{'L2HEAD_PORT'}, VLAN => $arglnk{'VLAN'});
		    }
		    $count = $conf{'MAXPARENTS'}; # завершаем  если добрались до головного коммутатора цепочки!
		} elsif ( defined($ref21->{'uplink_port'}) and DB_trunk_vlan(ACT => $arglnk{'ACT'}, SWID => $ref21->{'id'}, VLAN => $arglnk{'VLAN'}, PORT => $ref21->{'uplink_port'}, PORTPREF => $ref21->{'uplink_portpref'}) < 1 ) {
		    ## пробрасываем/убираем тэгированный VLAN на UPLINK порту текущего коммутатора цепочки 
		    print STDERR "\n============\nUPLINK vlan ".$arglnk{'ACT'}."\n LIB => $ref21->{'lib'}, IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, VLAN => $arglnk{'VLAN'}, ".
		    "PORT => $ref21->{'uplink_port'}, PORTPREF => $ref21->{'uplink_portpref'}\n" if $debug;
		    $res = &$LIB_action(IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, PASS => $ref21->{'admin_pass'}, ENA_PASS => $ref21->{'ena_pass'},
		    VLAN => $arglnk{'VLAN'}, PORT => $ref21->{'uplink_port'}, PORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORT => $ref21->{'uplink_port'});
		    if ($res < 1) {
			$stm21->finish();
			return $res;
		    }
		    $PAR{'change'} += 1;
		    DB_trunk_update(ACT => $arglnk{'ACT'}, SWID => $ref21->{'id'}, PORTPREF => $ref21->{'uplink_portpref'}, PORT => $ref21->{'uplink_port'}, VLAN => $arglnk{'VLAN'});
		} elsif (not defined($ref21->{'uplink_port'})) {
		    print STDERR "Trunking vlan chains skip uplink in ".$ref21->{'hostname'}.", UPLINK_PORT not SET  :-( ...\n";
		} else {
		    print STDERR "Trunking vlan uplink in ".$ref21->{'hostname'}.", already ".$arglnk{'ACT'}." in DB :-) ...\n";
		    $res = 1;
		}

		# Сохраняем конфигурацию текущего коммутатора цепочки
		if ($PAR{'change'}) {
		    SAVE_config(LIB => $ref21->{'lib'}, SWID => $ref21->{'id'}, IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, PASS => $ref21->{'admin_pass'}, 
		    ENA_PASS => $ref21->{'ena_pass'});
		}
		#$count = $conf{'MAXPARENTS'} if ($PAR{'id'} == $arglnk{'L2HEAD'}); # завершаем  если добрались до головного коммутатора цепочки!
		# Прекращаем, если не найден вышестоящий коммутатор и текущий коммутатор не является головным свичём цепочки терминирования
		if ( not defined($ref21->{'parent'}) and $PAR{'id'} != $arglnk{'L2HEAD'} ) {
		    print STDERR "Trunking vlan chains lost in switch ".$ref21->{'hostname'}.", PARENT not SET  :-( ...\n";
		    $stm21->finish();
		    return -1;
		}
		# Запоминаем параметры DOWNLINK на следующем коммутаторе цепочки
		$PAR{'id'}=$ref21->{'parent'};
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
        print "Save to DB change trunk VLAN => '".$argdb{'VLAN'}."', sw_id => '".$argdb{'SWID'}."' portpref => '".$argdb{'PORTPREF'}."', port => ".$argdb{'PORT'}." (debug)\n" if $debug;
	return 1 if $debug>1;
	my $Qr_in = "SELECT port_id FROM swports WHERE sw_id=".$argdb{'SWID'}." and port=".$argdb{'PORT'};
	if ( defined($argdb{'PORTPREF'}) and 'x'.$argdb{'PORTPREF'} ne 'x' ) {
	    $Qr_in .= " and portpref='".$argdb{'PORTPREF'}."'";
	} else {
	    $Qr_in .= " and portpref is NULL";
	}
	$stm33 = $dbm->prepare($Qr_in);
	$stm33->execute();
        while (my $ref33 = $stm33->fetchrow_hashref() and $stm33->rows == 1 ) {
	    my $Qr_add = "INSERT INTO port_vlantag set port_id=".$ref33->{'port_id'}.", vlan_id=".$argdb{'VLAN'}." ON DUPLICATE KEY UPDATE vlan_id=".$argdb{'VLAN'};
	    my $Qr_remove = "DELETE FROM port_vlantag WHERE port_id=".$ref33->{'port_id'}." and vlan_id=".$argdb{'VLAN'};
	    print STDERR " ACT = ".$argdb{'ACT'}.", port_id = ".$ref33->{'port_id'}."\n" if $debug;

	    if ( "x".$argdb{'ACT'} eq 'xadd') {
		$dbm->do($Qr_add);
		$dbm->do("INSERT INTO vlan_usage set sw_id=".$argdb{'SWID'}.", vlan_id=".$argdb{'VLAN'}." ON DUPLICATE KEY UPDATE vlan_id=".$argdb{'VLAN'});
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

        print "Check Vlan in trunk port => '".$argdb{'VLAN'}."', sw_id => '".$argdb{'SWID'}."' portpref => '".$argdb{'PORTPREF'}."', port => ".$argdb{'PORT'}." (debug)\n" if $debug;
	return 1 if $debug>1;
	my $Qr_in = "SELECT port_id FROM swports WHERE sw_id=".$argdb{'SWID'}." and port=".$argdb{'PORT'};
	if ( defined($argdb{'PORTPREF'}) and 'x'.$argdb{'PORTPREF'} ne 'x' ) {
	    $Qr_in .= " and portpref='".$argdb{'PORTPREF'}."'";
	} else {
	    $Qr_in .= " and portpref is NULL";
	}
	$stm33 = $dbm->prepare($Qr_in);
	$stm33->execute();
        while (my $ref33 = $stm33->fetchrow_hashref() and $stm33->rows == 1 ) {
	    my $Qr_check = "SELECT port_id FROM port_vlantag WHERE port_id=".$ref33->{'port_id'}." and vlan_id=".$argdb{'VLAN'};
	    #print STDERR " ACT = ".$argdb{'ACT'}.", port_id = ".$ref33->{'port_id'}."\n" if $debug;
	    $stm331 = $dbm->prepare($Qr_check);
	    $stm331->execute();
	    if ( $stm331->rows > 0 ) {
		$res =  1 if ("x".$argdb{'ACT'} eq 'xadd');    # VLAN найден в транке, не добавлять
		$res = -1 if ("x".$argdb{'ACT'} eq 'xremove'); # VLAN найден в транке, удалить
	    }
	    $stm331->finish();
	}
	$stm33->finish();
	return $res;
}

sub SAVE_config {
    # сохраняем конфиг на коммутаторе
    my %argscfg = (
	    @_,		# список пар аргументов
    );
    print "Save config in sw_id => '".$argscfg{'SWID'}."' IP => '".$argscfg{'IP'}."' (debug)\n" if $debug;
    return 0 if $debug>1;
    my $res=0;
    $LIB_action = $argscfg{'LIB'}.'_conf_save';
    $res = &$LIB_action(IP => $argscfg{'IP'}, LOGIN => $argscfg{'LOGIN'}, PASS => $argscfg{'PASS'}, ENA_PASS => $argscfg{'ENA_PASS'}) if ($argscfg{'LIB'} ne '');
    $dbm->do("UPDATE swports SET autoconf=0, complete_q=0 WHERE autoconf>0 and complete_q=1 and sw_id=".$argscfg{'SWID'}) if ($res>0 and $argscfg{'SWID'} > 0);
    print STDERR "Save config in host '".$argscfg{'IP'}."' failed!\n" if $res < 1;
    print STDERR "Save config in host '".$argscfg{'IP'}."' complete\n" if $res > 0;
    return $res;
}

sub VLAN_remove {
	#VLAN_remove(PORT_ID => $ref->{'port_id'}, VLAN => $ref->{'portvlan'}, LINK_TYPE => $ref->{'link_type'}, ZONE => $ref->{'vlan_zone'});
        my %arg = (
            @_,         # список пар аргументов
        );
	# PORT_ID VLAN LINK_TYPE ZONE 
	my $res = -1;

	return $res if $debug>1;

	my $Qr_in = "SELECT p.port_id FROM swports p, hosts h WHERE h.id=p.sw_id and p.port_id<>".$arg{'PORT_ID'}." and p.portvlan=".$arg{'VLAN'}." and h.vlan_zone=".$arg{'ZONE'};
	$stm34 = $dbm->prepare($Qr_in);
	$stm34->execute();
	if ( $stm34->rows > 0 ) {
	    $res =  -1;
	} else {
	    $dbm->do("DELETE from vlan_list WHERE vlan_id=".$arg{'VLAN'}." and ZONE=".$arg{'ZONE'});
	    $res =  1;
	}
	$stm34->finish();
	return $res;
}


sub VLAN_get {
	#VLAN_get(PORT_ID => $ref->{'port_id'}, LINK_TYPE => $ref->{'autoconf'}, ZONE => $ref->{'vlan_zone'}, VLAN_MIN => $head->{'VLAN_MIN'}, VLAN_MAX => $head->{'VLAN_MAX'});
        my %arg = (
            @_,         # список пар аргументов
        );
	# PORT_ID VLAN LINK_TYPE ZONE 

	my $res = -1;

#	return $res if $debug>1;
	my %vlanuse = ();
	my $Qr_range = "SELECT vlan_id FROM vlan_list WHERE vlan_id>=".$arg{'VLAN_MIN'}." and vlan_id<=".$arg{'VLAN_MAX'}." and zone_id=".$arg{'ZONE'};
        $stm35 = $dbm->prepare($Qr_range);
        $stm35->execute();
	while (my $ref35 = $stm35->fetchrow_hashref()) {
	    $vlanuse{$ref35->{'vlan_id'}} = 1;
	}
	$stm35->finish();
		
	my $vlan_id = $arg{'VLAN_MIN'};

	while ($res < 1 || $arg{'VLAN_MAX'} > $vlan_id ) {
	    $res = $vlan_id if not defined($vlanuse{$vlan_id});
	    $vlan_id += 1;
	}
	
	$dbm->do("INSERT into vlan_list SET info='AUTO INSERT VLAN record from vlan range', vlan_id=".$res.", zone_id=".$arg{'ZONE'}.", port_id=".$arg{'PORT_ID'}.", link_type=".$arg{'LINK_TYPE'}.
	" ON DUPLICATE KEY UPDATE info='AUTO UPDATE VLAN record', port_id=".$arg{'PORT_ID'}.", link_type=".$arg{'LINK_TYPE'}) if $res > 0;
	return $res;
}
