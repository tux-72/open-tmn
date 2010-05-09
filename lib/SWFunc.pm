#!/usr/bin/perl

package SWFunc;

use strict;
no strict qw(refs);

#use locale;
use POSIX qw(strftime);
use cyrillic qw(cset_factory);
use DBI();

use DESCtl;
use C73Ctl;
use CATIOSCtl;
use CAT2950Ctl;
use CAT3550Ctl;
use CATOSCtl;
use ESCtl;
use GSCtl;
use BPSCtl;
use TCOM4500Ctl;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();

$VERSION = 1.8;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw( SW_AP_get SW_AP_fix SW_AP_tune SW_AP_free SW_AP_linkstate SW_ctl dlog rspaced lspaced
	    DB_mysql_connect IOS_rsh
	    SAVE_config VLAN_link DB_trunk_vlan DB_trunk_update GET_Terminfo GET_GW_parms 
	    VLAN_VPN_get VLAN_get VLAN_remove 
);

my $start_conf	= \%SWConf::conf;
my $conflog	= \%SWConf::conflog;
my $dbi		= \%SWConf::dbconf;

#use Data::Dumper;

my $w2k = cset_factory 1251, 20866;
my $k2w = cset_factory 20866, 1251;

my $debug=1;

my $Querry_start = '';
my $Querry_end = '';
my $res; 
my $dbm; 

DB_mysql_connect(\$dbm);

my $LIB_ACT ='';

my @RES = ( 'PASS', 'DENY', 'UNKNOWN' );

my %link_type = ();
my @link_types = ();
my $stm01 = $dbm->prepare("SELECT ltype_id, ltype_name FROM link_types order by ltype_id");
$stm01->execute();
while (my $ref01 = $stm01->fetchrow_hashref()) {
    $link_type{$ref01->{'ltype_name'}}=$ref01->{'ltype_id'} if defined($ref01->{'ltype_name'});
    $link_types[$ref01->{'ltype_id'}]=$ref01->{'ltype_name'} if defined($ref01->{'ltype_name'});
}
$stm01->finish();

my %headinfo = ();
my $stm = $dbm->prepare( "SELECT t.linked_head, t.term_ip, t.zone_id, t.term_grey_ip2, h.ip, m.lib, m.mon_login, m.mon_pass FROM heads t, hosts h, models m ".
" WHERE t.ltype_id<>".$link_type{'l3net4'}." and h.model_id=m.model_id and t.l2sw_id=h.sw_id and t.term_ip is not NULL order by head_id desc" );
$stm->execute();
while (my $ref = $stm->fetchrow_hashref()) {
    $headinfo{'L2LIB_'.   $ref->{'term_ip'}} = $ref->{'lib'};
    $headinfo{'L2IP_'.    $ref->{'term_ip'}} = $ref->{'ip'};
    $headinfo{'MONLOGIN_'.$ref->{'term_ip'}} = $ref->{'mon_login'};
    $headinfo{'MONPASS_'. $ref->{'term_ip'}} = $ref->{'mon_pass'};
    $headinfo{'ZONE_'.    $ref->{'term_ip'}} = $ref->{'zone_id'};
    $headinfo{'LHEAD_'.   $ref->{'term_ip'}} = $ref->{'linked_head'} if $ref->{'linked_head'};
}
$stm->finish();

############ SUBS ##############

sub SW_ctl {
	my $arg = shift;
	my $swfunc = $arg->{'LIB'}.'_'.$arg->{'ACT'};
	if ( defined &$swfunc ) {
	    return &$swfunc( $arg );
	} else {
	    return 0;
	}
}

sub DB_mysql_connect {
	my $sqlconnect = shift;
	${$sqlconnect} = DBI->connect_cached("DBI:mysql:database=".$dbi->{'MYSQL_base'}.";host=".$dbi->{'MYSQL_host'},$dbi->{'MYSQL_user'},$dbi->{'MYSQL_pass'})
	or die "Unable to connect MYSQL DB host ".$dbi->{'MYSQL_host'}."$DBI::errstr";
	#or die dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MYSQL DB host ".$dbi->{'MYSQL_host'}."$DBI::errstr" );
	${$sqlconnect}->do("SET NAMES 'koi8r'") or die return -1;
	#dlog ( DBUG => 2, SUB => (caller(0))[3],  MESS => "Mysql connect ID = ".${$sqlconnect}->{'mysql_thread_id'} );
	return 1;
}

sub rspaced {
    my $str = shift;
    my $len = shift;
    return sprintf("%-${len}s",$str);
}

sub lspaced {
    my $str = shift;
    my $len = shift;
    return sprintf("%${len}s",$str);
}

sub dlog {
        my %arg = (
	    'LOGTYPE' => 'LOGDFLT',
            @_,
        );
        if ( $arg{'DBUG'} <= $SWConf::debug and defined($arg{'MESS'}) and $arg{'MESS'}."x" ne "x" ) {
	    my $stderrout=1; my $LOGFILE;
	    if ( defined($conflog->{$arg{'LOGTYPE'}}) ) {
		open( $LOGFILE,">>",$conflog->{$arg{'LOGTYPE'}} ) or die "Can't open '".$conflog->{$arg{'LOGTYPE'}}."' $!";
		$stderrout=0;
	    }

	    my $subchar = 30; my @lines = ();
	    $arg{'PROMPT'} .= ' ';
	    $arg{'PROMPT'} =~ tr/a-zA-Z0-9+-_:;,.?\(\)\/\|\'\"\t\>\</ /cs;

            my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];
            my $timelog = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $month + 1, $day, $hour, $min, $sec);
            if ( ref($arg{'MESS'}) ne 'ARRAY' ) {
                @lines = split /\n/,$arg{'MESS'};
            } else {
                @lines = @{$arg{'MESS'}};
            }
            foreach my $mess ( @lines ) {
		if ( defined($arg{'NORMA'}) and $arg{'NORMA'} ) { $mess =~ tr/a-zA-Z0-9+-_:;,.?\(\)\/\|\'\"\t/ /cs; }
                next if (not $mess =~ /\S+/);
		my $logline = $timelog." ".rspaced("'".$arg{'SUB'}."'",$subchar).": ".$arg{'PROMPT'}.$mess."\n";
		if ($stderrout) {
            	    print STDERR $logline;
		} else {
            	    print $LOGFILE $logline;
		}
            }
	    if (not $stderrout) { close $LOGFILE; }
	}
}

{
    #my $pid_decr = (($$ & 127) << 1 );
    my $pid_decr = (($$ & 7) << 1 );
    my $end_port = 20000 - 1024 * $pid_decr;
    my $start_port = $end_port - 1024;
    #dlog ( DBUG => 3, SUB => (caller(0))[3], MESS => "PID decr = $pid_decr, start_port = $start_port, end_port = $end_port"  );
    my $src_port = $end_port ;

    sub IOS_rsh {
	#HOST CMD REMOTE_USER LOCAL_USER
        my %arg = (
            @_,
        );
	$arg{'LOCAL_USER'} = 'root'; $arg{'REMOTE_USER'} = 'admin';
	dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => ' LOCAL USER = '.$arg{'LOCAL_USER'}.' REMOTE USER = '.$arg{'REMOTE_USER'} );
	
	$src_port -= 1;

    	if ( $src_port < $start_port ) {
	    $src_port = $end_port;
	}
	
        my $try = 1;
        my $socket;
        while ($try) {
                last if ( $src_port < $start_port - 1 );
		dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => " PID=".$$.", HOST = ".$arg{'HOST'}." port = $src_port" );
                eval {
                        local $SIG{'__DIE__'};
                        $socket = IO::Socket::INET->new(PeerAddr	=> $arg{'HOST'},
                                                	PeerPort	=> '514',
                                                        LocalPort	=> $src_port,
                                                        Proto		=> 'tcp' );
                };
                ( $@ || ( not defined $socket )) ? ( $src_port -= 1 ) : ( $try = 0 );
        }
        if ($try) {
		dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "All ports in use!" );
                return ();
        }
        print $socket "0\0";
        print $socket $arg{'LOCAL_USER'}."\0";
        print $socket $arg{'REMOTE_USER'}."\0";
        print $socket $arg{'CMD'}."\0";
        my @c=<$socket>;
	#$socket->shutdown(HOW);
	$socket->shutdown();
        return @c;
    }
}


sub SW_AP_fix {

	DB_mysql_connect(\$dbm);
	my $Query10 = ''; my $Query0 = ''; my $Query1 = ''; my %sw_arg = (); my $cli_vlan=0;
	my %arg = (
	    @_,         # список пар аргументов
	);
	# AP_INFO LOGIN LTYPE VLAN NAS_IP HW_MAC
	if ( not defined($headinfo{'ZONE_'.$arg{'NAS_IP'}}) ) {
	    dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGAPFIX', MESS => "NAS '".$arg{'NAS_IP'}."'ZONE not exist, AP not fixed..." );
	    return -1;
	}

	my $AP = $arg{'AP_INFO'};
	$AP->{'vlan_zone'} = $headinfo{'ZONE_'.$arg{'NAS_IP'}};
	############# GET Switch IP's
	my $stm0 = $dbm->prepare("SELECT h.automanage, h.bw_ctl, h.sw_id, h.ip, h.model_id, h.hostname, st.street_name, h.dom, h.podezd, h.unit, m.lib, ".
	"m.mon_login, m.mon_pass FROM hosts h, streets st, models m WHERE h.model_id=m.model_id and h.street_id=st.street_id and m.lib is not NULL and h.clients_vlan=".
	$arg{'VLAN'}." and h.zone_id=".$AP->{'vlan_zone'}." and h.visible>0" );
	$stm0->execute();
		if ($stm0->rows>1) { dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => "More by one switch in Clients VLAN '".$arg{'VLAN'}."'!!!" ); }

		while (my $ref = $stm0->fetchrow_hashref() and not $AP->{'id'}) {
			$cli_vlan=1;
			$AP->{'automanage'}=1 if ($ref->{'automanage'} == 1);
			$AP->{'bw_ctl'}=1 if ($ref->{'bw_ctl'} == 1);

			%sw_arg = (
			    LIB => $ref->{'lib'}, ACT => 'fix_macport', IP => $ref->{'ip'}, LOGIN => $ref->{'mon_login'}, PASS => $ref->{'mon_pass'},
			    MAC => $arg{'HW_MAC'}, VLAN => $arg{'VLAN'},
			);
			( $AP->{'portpref'}, $AP->{'port'} ) = SW_ctl ( \%sw_arg );
			if ($AP->{'port'}>0 or $stm0->rows == 1) {
    				$AP->{'swid'} = $ref->{'sw_id'}; $AP->{'podezd'} = $ref->{'podezd'};
                                $AP->{'name'} = "ул. ".$ref->{'street_name'}.", д.".$ref->{'dom'};
				$AP->{'name'} .= ", п.".$ref->{'podezd'} if $ref->{'podezd'}>0;
				$AP->{'name'} .= ", unit N".$ref->{'unit'} if defined($ref->{'unit'});
			}
			if ($AP->{'port'}>0) {
				if ( defined($AP->{'portpref'}) and 'x'.$AP->{'portpref'} ne 'x' ) {
			    	    $Query10 = "SELECT port_id FROM swports WHERE portpref='".$AP->{'portpref'}."' and  port='".$AP->{'port'}."' and sw_id=".$AP->{'swid'};
			    	    $Query0 = "SELECT port_id, communal, ds_speed, us_speed, ltype_id, vlan_id, autoneg, speed, duplex, maxhwaddr FROM swports WHERE portpref='".$AP->{'portpref'}."' and  port='".$AP->{'port'}."' and sw_id=".$AP->{'swid'};
			    	    $Query1 = "INSERT into swports  SET  status=1, ltype_id=".$link_type{'free'}.", type=1, ds_speed=64, us_speed=64, portpref='".$AP->{'portpref'}."', port='".$AP->{'port'}."', sw_id='".$AP->{'swid'}."', vlan_id=-1";
				} else {
			    	    $Query10 = "SELECT port_id FROM swports WHERE portpref is NULL and port='".$AP->{'port'}."' and sw_id=".$AP->{'swid'};
			    	    $Query0 = "SELECT port_id, communal, ds_speed, us_speed, ltype_id, vlan_id, autoneg, speed, duplex, maxhwaddr FROM swports WHERE portpref is NULL and port='".$AP->{'port'}."' and sw_id=".$AP->{'swid'};
			    	    $Query1 = "INSERT into swports  SET status=1, ltype_id=".$link_type{'free'}.", type=1, ds_speed=64, us_speed=64, portpref=NULL, port='".$AP->{'port'}."', sw_id='".$AP->{'swid'}."', vlan_id=-1";
				}
				my $stm10 = $dbm->prepare($Query10);
				$stm10->execute();
				if (not $stm10->rows) {
			    		$dbm->do($Query1);
					dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => "Insert New PORT record in swports" );
				}
				$stm10->finish;
				my $stm1 = $dbm->prepare($Query0);
				$stm1->execute();
			    	while (my $refp = $stm1->fetchrow_hashref()) {
					$AP->{'link_type'} = $link_type{'free'};
					$AP->{'link_type'} = $refp->{'ltype_id'} if defined($refp->{'ltype_id'});
					$AP->{'id'} = $refp->{'port_id'};
					$AP->{'communal'} = $refp->{'communal'};
					$AP->{'ds'} = $refp->{'ds_speed'} if defined($refp->{'ds_speed'});
					$AP->{'us'} = $refp->{'us_speed'} if defined($refp->{'us_speed'});
					#NEW Parameters    
					$AP->{'portvlan'} = $refp->{'vlan_id'} if defined($refp->{'vlan_id'});

			    	}
                                        $AP->{'name'} .= ", порт ".$AP->{'port'};
					$stm1->finish;
			}
			dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => '('. $dbm->{'mysql_thread_id'}.') '.
			"CLI_VLAN  '".$arg{'VLAN'}."' MAC '".$arg{'HW_MAC'}."' User: '".$arg{'LOGIN'}."' AP -> '".$AP->{'id'}."', '".$AP->{'name'}."'" );
		}
		$stm0->finish;
		if ( ( not $AP->{'id'}) and ( not $cli_vlan ) ) {
			dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGAPFIX', MESS => "FIND PORT VLAN '".$arg{'VLAN'}."' User: '".$arg{'LOGIN'}."', MAC:'".$arg{'HW_MAC'}."'" );
			$AP->{'DB_portinfo'}=1;
			$stm0 = $dbm->prepare( "SELECT h.automanage, h.bw_ctl, h.ip, h.model_id, h.hostname, st.street_name, h.dom, h.podezd, h.unit,".
			" p.sw_id, p.port_id, p.ltype_id, p.communal, p.portpref, p.port, p.ds_speed, p.us_speed, ".
			" p.vlan_id, p.autoneg, p.speed, p.duplex, p.maxhwaddr FROM hosts h, streets st, swports p ".
			" WHERE h.street_id=st.street_id and p.sw_id=h.sw_id and p.vlan_id=".$arg{'VLAN'}." and h.zone_id=".$AP->{'vlan_zone'} );
                    	$stm0->execute();
                    	while (my $ref = $stm0->fetchrow_hashref()) {
			    $AP->{'port'} = $ref->{'port'} if not defined($ref->{'portpref'});
			    $AP->{'port'} = $ref->{'portpref'}.$ref->{'port'} if defined($ref->{'portpref'});
                            $AP->{'swid'} = $ref->{'sw_id'}; $AP->{'podezd'} = $ref->{'podezd'};

                            $AP->{'name'} = "ул. ".$ref->{'street_name'}.", д.".$ref->{'dom'};
                            $AP->{'name'} .= ", п.".$ref->{'podezd'} if $ref->{'podezd'}>0;
                            $AP->{'name'} .= ", unit N".$ref->{'unit'} if defined($ref->{'unit'});
                            $AP->{'name'} .= ", порт ".$AP->{'port'};

			    $AP->{'link_type'} = $link_type{'free'};
			    $AP->{'link_type'} = $ref->{'ltype_id'} if defined($ref->{'ltype_id'});

			    $AP->{'automanage'}=1 if ($ref->{'automanage'} == 1);
			    $AP->{'bw_ctl'}=1 if ($ref->{'bw_ctl'} == 1);

			    $AP->{'ds'} = $ref->{'ds_speed'} if defined($ref->{'ds_speed'});
			    $AP->{'us'} = $ref->{'us_speed'} if defined($ref->{'us_speed'});
			    #NEW Parameters
			    $AP->{'portvlan'} = $ref->{'vlan_id'} if defined($ref->{'vlan_id'});

			    if ($AP->{'id'}) {
				dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGAPFIX', MESS => "MULTI TD's!!! = '".$AP->{'id'}."' and '".$ref->{'port_id'}."'" );
				$AP->{'id'} = 0; $AP->{'swid'} = 0; $AP->{'podezd'}=0; $AP->{'name'}=''; $AP->{'port'}=0;
				last;
			    }
			    $AP->{'id'} = $ref->{'port_id'};
			    $AP->{'communal'} = $ref->{'communal'};
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => '('. $dbm->{'mysql_thread_id'}.') '.
			    "PORT_VLAN '".$arg{'VLAN'}."' MAC '".$arg{'HW_MAC'}."' User: '".$arg{'LOGIN'}."' AP -> '".$AP->{'id'}."', '".$AP->{'name'}."'" );
			}
			$stm0->finish;
		}
}

sub SW_AP_get {

	dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "--" );
	DB_mysql_connect(\$dbm);
	my $fparm = shift; my %sw_arg = ();
	my $Fres = 2; my $Fvalue = 'ap_id:-1;';	

        #       $fparm->{login} = pppoe
        #       $fparm->{link_type} = 21
        #       $fparm->{ap_vlan} = 239
        #       $fparm->{nas_ip} = 192.168.100.30
	#	$fparm->{nas_port_id} = '0/0/1/0'
        #       $fparm->{mac} = 0017.3156.7fd9

        #       $fparm->{ap_id} =
        #       $fparm->{port_rate_ds} = 10000
        #       $fparm->{port_rate_us} = 10000
        #       $fparm->{inet_rate} = 1000
        #       $fparm->{ip_addr} = 10.13.64.3

	############ Проверка обязательных параметров
	if ( not ( defined($fparm->{'link_type'}) && $fparm->{'link_type'} =~ /^\d+$/ ) ) {
	    return ( $Fres, "error:not defined or broken parameter 'link_type' => '".$fparm->{'link_type'}."';" );
	} else {
	    $fparm->{'link_type'} = $fparm->{'link_type'}+0;
	}
	if ( not ( defined($fparm->{'login'}) && "x".$fparm->{'login'} ne "x" ) ) {
	    return ( $Fres, "error:not defined or broken parameter 'login' => '".$fparm->{'login'}."';" );
	}
	if ( not ( defined($fparm->{'nas_ip'}) && $fparm->{'nas_ip'} =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) ) {
	    return ( $Fres, "error:not defined or broken parameter 'nas_ip' => '".$fparm->{'nas_ip'}."';" );
	}

	if ( not ( defined($fparm->{'mac'}) && "x".$fparm->{'mac'} ne "x" ) ) {
	    return ( $Fres, "error:not defined parameter 'MAC';" );
	}

	if	( $fparm->{'mac'} =~ /^(\w\w)(\w\w)\.(\w\w)(\w\w)\.(\w\w)(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif ( $fparm->{'mac'} =~ /^(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)\-(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif ( $fparm->{'mac'} =~ /^(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)(\w\w)$/ ) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} elsif ( $fparm->{'mac'} =~ /^(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)\:(\w\w)$/) {
	    $fparm->{'mac'} = "$1\:$2\:$3\:$4\:$5\:$6";
	} else {
           dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "MAC '".$fparm->{'mac'}."' unknown format, exiting ..." );
	    return ( $Fres, "error: broken format in parameter 'mac' => '".$fparm->{'mac'}."';" );
	}
	$fparm->{'mac_src'} = "$1$2$3$4$5$6";


	###################### normalize port speeds #################
	if ( defined($fparm->{'port_rate_ds'}) ) {
	    if ( "x".$fparm->{'port_rate_ds'} eq 'x0' ) {
		$fparm->{'port_rate_ds'} = -1;
	    } elsif ( "x".$fparm->{'port_rate_ds'} eq 'x' ) {
		delete($fparm->{'port_rate_ds'});
	    } elsif ( not $fparm->{'port_rate_ds'} =~ /^\d+$/ ) {
        	return ( $Fres, "error: broken format in parameter 'port_rate_ds' => '".$fparm->{'port_rate_ds'}."';" );
	    }
	}
	if ( defined($fparm->{'port_rate_us'}) ) {
	    if ( "x".$fparm->{'port_rate_us'} eq 'x0' ) {
		$fparm->{'port_rate_us'} = -1;
	    } elsif ( "x".$fparm->{'port_rate_us'} eq 'x' ) {
		delete($fparm->{'port_rate_us'});
	    } elsif ( not $fparm->{'port_rate_us'} =~ /^\d+$/ ) {
        	return ( $Fres, "error: broken format in parameter 'port_rate_us' => '".$fparm->{'port_rate_us'}."';" );
	    }
	}
	###### чистка пустых необязательных параметров
	if ( defined($fparm->{'ap_vlan'}) && "x".$fparm->{'ap_vlan'} eq "x") {
	    delete($fparm->{'ap_vlan'});
	}
	if ( defined($fparm->{'ip_addr'}) && "x".$fparm->{'ip_addr'} eq "x") {
	    delete($fparm->{'ip_addr'});
	}

	####################### GET ACCESS POINT ####################
	my $Query = ''; my $Q_upd = ''; my $PreQuery = '';
        my $date = strftime "%Y%m%d%H%M%S", localtime(time);
	my $job_parms = '';

	my %AP = (
	    'trust',	0,
	    'set',	0,
	    'VLAN',	0,
	    'vlan_zone',	-1,
	    'update_db',	0,
	    'DB_portinfo',	0,
	    'MAC',	$fparm->{'mac'},
	    'pri',	$fparm->{'inet_priority'},
	    'id',	0,
	    'name',	'',
	    'swid',	0,
	    'house',	0,
	    'podezd',	0,
	    'portpref',	'',
	    'port',	0,
	    'ds_db',	0,
	    'us_db',	0,
	    'autoconf',	0,
	    'bw_ctl',	0,
	    #'lastlogin','1',
	    'portvlan',	0,
	    'ip_subnet', '',
	    'autoneg', 1,
	    'speed', 100,
	    'duplex', 1,
	    'maxhwaddr', -1,
	);

	####### Start FIX VLAN ID) ########### 
	%sw_arg = (
	    LIB => $headinfo{'L2LIB_'.$fparm->{'nas_ip'}}, ACT => 'fix_vlan', IP => $headinfo{'L2IP_'.$fparm->{'nas_ip'}}, 
	    LOGIN => $headinfo{'MONLOGIN_'.$fparm->{'nas_ip'}},	PASS => $headinfo{'MONPASS_'.$fparm->{'nas_ip'}}, MAC => $fparm->{'mac'},
	);
	$AP{'VLAN'} = SW_ctl ( \%sw_arg );

	if ( $AP{'VLAN'} < 1) {
	    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "User '".$fparm->{'login'}."'".' Access point VLAN is not FIX!!! Trobles connect to ZONE SWITCH???' );
	    $Fres = 2;
	    $Fvalue = 'error:MAC VLAN not fixed... :-(;';
	} else {
		dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "User '".$fparm->{'login'}."'".' Access point VLAN = '.$AP{'VLAN'} );
		########### Start FIX Access Point (AP) ########### 
		#SW_AP_fix( AP_INFO => \%AP, LOGIN => $fparm->{'login'} , VLAN => $AP{'VLAN'}, NAS_IP => $fparm->{'nas_ip'}, NAS_PORT => $fparm->{'nas_port_id'}, HW_MAC => $fparm->{'mac'});
		SW_AP_fix( AP_INFO => \%AP, LOGIN => $fparm->{'login'} , VLAN => $AP{'VLAN'}, NAS_IP => $fparm->{'nas_ip'}, HW_MAC => $fparm->{'mac'});
		################### Если выяснили AP_ID ######################
		if ($AP{'id'}) {
			$Fres = 1;
			$Fvalue = 'ap_id:'.$AP{'id'}.';ap_name:'.&$k2w($AP{'name'}).';bw_ctl:'.$AP{'bw_ctl'}.';ap_swid:'.$AP{'swid'}.';ap_communal:'.$AP{'communal'}.';';
			if ( $fparm->{'ap_id'} and $fparm->{'ap_id'} == $AP{'id'} ) {
			    $Fres = 0; $AP{'trust'}=1;

    			    if ( ( $AP{'link_type'} != $fparm->{'link_type'}
				|| ( 'x'.$fparm->{'port_rate_us'} ne 'x' and $AP{'us'} != $fparm->{'port_rate_us'} )
				|| ( 'x'.$fparm->{'port_rate_ds'} ne 'x' and $AP{'ds'} != $fparm->{'port_rate_ds'} )
			    ) and ! $AP{'communal'} ) {
				$AP{'set'} = 1;
			    }

                            dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS =>
			    "AP_set = '".$AP{'set'}."', AP_DS = '".$fparm->{'port_rate_ds'}."', AP_US = '".$fparm->{'port_rate_us'}."'" );
			} else {
			    $AP{'trust'} = 0; $AP{'set'} = 0
			}
			$Query = "INSERT INTO ap_login_info SET trust=".$AP{'trust'}.", login='".$fparm->{'login'}."', start_date='".$date."', last_date='".$date."'";
			$Query .= ", hw_mac='".$fparm->{'mac'}."', vlan_id='".$AP{'VLAN'}."', port_id='".$AP{'id'}."', ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."'";
			$Query .= ", ip_addr='".$fparm->{'ip_addr'}."'" if ( not $fparm->{'ip_addr'} =~ /^10\.13\.2[45][0-9]\.\d{1,3}$/ );
			$Query .= " ON DUPLICATE KEY UPDATE trust=".$AP{'trust'}.", ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."', last_date='".$date."', vlan_id='".$AP{'VLAN'}."'";
			$Query .= ", ip_addr='".$fparm->{'ip_addr'}."'" if ( not $fparm->{'ip_addr'} =~ /^10\.13\.2[45][0-9]\.\d{1,3}$/ );
			$dbm->do("$Query");

			## HEAD_LINK
			# y inserting data
			if ( $AP{'trust'} and $fparm->{'link_type'} == $link_type{'pppoe'} ) {
			    if ( ! $fparm->{'ip_addr'} =~ /^10\.13\.\d{1,3}\.\d{1.3}$/ ) { $AP{'pri'} = 3; }
			    $Query = "INSERT INTO head_link SET port_id=".$AP{'id'}.", status=1, static_ip=0, ";
			    $Q_upd = " vlan_id=".$AP{'VLAN'}.", login='".$fparm->{'login'}."', hw_mac='".$fparm->{'mac'}."', communal=".$AP{'communal'}.
			    ", inet_shape=".$fparm->{'inet_rate'}.", inet_priority=".$AP{'pri'}.", stamp=NULL, ip_subnet='".$fparm->{'ip_addr'}."'".
			    ", head_id=".$headinfo{'LHEAD_'.$fparm->{'nas_ip'}};
			    $Q_upd .= ", pppoe_up=1" if $start_conf->{'CHECK_PPPOE_UP'};
			    $Query .= $Q_upd." ON DUPLICATE KEY UPDATE ".$Q_upd;
			    $dbm->do("$Query") or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => "$Query \n$DBI::errstr" );
			}
		######################## SET JOB PARAMETERS
			if ( $AP{'set'} and $AP{'automanage'} ) {
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "Access Point parm change" );
			    $AP{'update_db'}=1;
		    	    $Query = "INSERT INTO bundle_jobs SET port_id=".$AP{'id'};
			    $job_parms  = 'login:'.$fparm->{'login'}.';hw_mac:'.$fparm->{'mac_src'}.';';
			    $job_parms .= 'inet_rate:'.$fparm->{'inet_rate'}.';'   if defined($fparm->{'inet_rate'});
			    $job_parms .= 'ds_speed:'.$fparm->{'port_rate_ds'}.';' if defined($fparm->{'port_rate_ds'});
			    $job_parms .= 'us_speed:'.$fparm->{'port_rate_us'}.';' if defined($fparm->{'port_rate_us'});

			    ########  VPN  VLAN  ########
			    if ( $fparm->{'link_type'} == $link_type{'l2link'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
				if ( "x".$fparm->{'vlan_id'} eq "x" and $AP{'link_type'} != $link_type{'l2link'} ) {
				    ( $fparm->{'vlan_id'}, $AP{'link_head'} ) = VLAN_VPN_get ( PORT_ID => $AP{'id'}, 
				    LINK_TYPE => $link_type{'l2link'}, ZONE => $AP{'vlan_zone'} );
				    if ( $fparm->{'vlan_id'} > 1 ) {
					$Fvalue .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
		    			$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
		    			$job_parms .= 'link_head:'.$AP{'link_head'}.';'  if ( $AP{'link_head'} > 1 );
				    }
				} elsif ("x".$fparm->{'vlan_id'} ne "x"  and $AP{'link_type'} != $link_type{'l2link'}) {
		    		    $job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
				}
			    }
			    ######## Transport Net ############
		    	    if ( defined($fparm->{'ip_addr'}) and $fparm->{'link_type'} == $link_type{'l3net4'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
				$job_parms .= 'ip_subnet:'.$fparm->{'ip_addr'}.'/30;';
			    }

			    # Проверка изменений link_type
			    ## Если порт был свободен и задействуется под PPPoE
			    if ( $AP{'link_type'} == $link_type{'free'} and $fparm->{'link_type'} == $start_conf->{'CLI_VLAN_LINKTYPE'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
		    		$job_parms .= 'vlan_id:'.$AP{'VLAN'}.';';
			    ## Иначе если порт был свободен и задействуется под другие типы подключений  
			    } elsif ( $AP{'link_type'} == $link_type{'free'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
		    		$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';' if ( $fparm->{'vlan_id'} > 1 );
			    ## Иначе если порт занят под такой же тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $fparm->{'link_type'}+0 == $AP{'link_type'}+0 ) {
				$Query .= ", ltype_id=".$link_type{'setparms'};
		    		$job_parms .= 'vlan_id:'.$AP{'VLAN'}.';';
			    ## Иначе если порт ЗАНЯТ! и задействуется под другой тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $fparm->{'link_type'}+0 != $AP{'link_type'}+0  ) {
				$PreQuery .= "INSERT INTO bundle_jobs SET port_id=".$AP{'id'}.", ltype_id=".$link_type{'free'}.' ON DUPLICATE KEY UPDATE date_insert=NULL';

				$Query .= ", ltype_id=".$fparm->{'link_type'};
		    		$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';' if ( defined($fparm->{'vlan_id'}) and $fparm->{'vlan_id'} > 1 );
			    } else {
				$AP{'update_db'}=0;
			    }

			    if ( $AP{'update_db'} ) {
				if ("x".$PreQuery ne "x" ) { $dbm->do($PreQuery); }
				$Query .= ", parm='".$job_parms."', archiv=0 ON DUPLICATE KEY UPDATE date_insert=NULL, parm='".$job_parms."'";
                    		dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "Update port DB parameters info" );
				$dbm->do($Query) or dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', 
				MESS => "ERROR change table 'Bundle_jobs' Querry --".$Query."--" );
			    } else {
				dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', 
				MESS => "Error: Different link_types, possible PORT type is FREE?" );
			    }
			}

			if ( not $AP{'trust'} ) {
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "'".$fparm->{'login'}."' access point not agree !!!" );
	    		    $Fres = 1;
			    $Fvalue = 'ap_id:'.$AP{'id'}.';ap_name:'.&$k2w($AP{'name'}).';bw_ctl:'.$AP{'bw_ctl'}.';ap_swid:'.$AP{'swid'}.';ap_communal:'.$AP{'communal'}.';';
			}

		} elsif ( $AP{'VLAN'} ) {
		    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "AP ID '".$fparm->{'login'}."' in VLAN ".$AP{'VLAN'}." not fixed!!!" );
		    $Fres = 2;
	            $Fvalue = 'error:MAC found in VLAN '.$AP{'VLAN'}.'. Access point not fixed... :-(;';
		}
	}
        dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => 
	"QUERY: Login  = '".$fparm->{'login'}."', MAC = '".$fparm->{'mac'}."', NAS_IP = ".$fparm->{'nas_ip'}."\n".
	"AP_CHECK: ".$RES[$Fres].'('.$Fres.')'.", Login = '".$fparm->{'login'}."', AP_ID = '".$AP{'id'}."', '".$AP{'name'}.", ZONE = ".$AP{'vlan_zone'}.", VLAN = ".$AP{'VLAN'}."'\n".
	"REPLY: ".$Fres.", '".&$w2k($Fvalue)."'" );

	return ($Fres+0, $Fvalue);
}


sub SW_AP_free {

    DB_mysql_connect(\$dbm);
    my $Q_free; my $Fres = 0; my $Fvalue = '';

    my $fparm = shift;
    #	$fparm->{ap_id} = 1234
    if  ( not ( defined($fparm->{'ap_id'}) && $fparm->{'ap_id'} =~ /^\d+$/ ) ) {
        return ( $Fres, "error:not defined parameter 'ap_id';" );
    }
    ############################ Освобождeние AP

    $Q_free = "INSERT INTO bundle_jobs SET port_id=".$fparm->{'ap_id'}.", ltype_id=".$link_type{'free'}.' ON DUPLICATE KEY UPDATE date_insert=NULL';

    if ( $debug > 1 ) {
        dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "DEBUG mode, Query '".$Q_free."'" );
	$Fres = 2;
	$Fvalue = "error: AP_free info in debug mode not update;";;
    } else {
	dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => $Q_free );
	$dbm->do($Q_free) or $Fres = 1;
	if ($Fres) {
	    $Fvalue = "error:Error update AP_free info Query '".$Q_free."';";;
	    dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "ERROR update AP_free info Querry '".$Q_free."'" ) 
	} else {
	    dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "Closed AP, id N'".$fparm->{'ap_id'}."'" );
	}
    }
    return ($Fres+0, $Fvalue );
}


sub SW_AP_tune {

    DB_mysql_connect(\$dbm);
    my $Q_tune; my $Q_parm = ''; my $Fres = 0; my $Fvalue = ''; my $parmset = 0;

    my $fparm = shift;
    #	$fparm->{ap_id} = 
    #	$fparm->{port_rate_ds} = 10000
    #	$fparm->{port_rate_us} = 10000
    if  ( not ( defined($fparm->{'ap_id'}) && $fparm->{'ap_id'} =~ /^\d+$/ ) ) {
        return ( $Fres, "error:not defined or broken parameter 'ap_id';" );
    }
    if ( defined($fparm->{'port_rate_ds'}) ) {
	if ( "x".$fparm->{'port_rate_ds'} eq 'x0' ) {
	    $fparm->{'port_rate_ds'} = -1;
	} elsif ( "x".$fparm->{'port_rate_ds'} eq 'x' ) {
	    delete($fparm->{'port_rate_ds'});
	} elsif ( not $fparm->{'port_rate_ds'} =~ /^\d+$/ ) {
	    return ( $Fres, "error: broken format in parameter 'port_rate_ds' => '".$fparm->{'port_rate_ds'}."';" );
	}
    }
    if ( defined($fparm->{'port_rate_us'}) ) {
	if ( "x".$fparm->{'port_rate_us'} eq 'x0' ) {
	    $fparm->{'port_rate_us'} = -1;
	} elsif ( "x".$fparm->{'port_rate_us'} eq 'x' ) {
	    delete($fparm->{'port_rate_us'});
	} elsif ( not $fparm->{'port_rate_us'} =~ /^\d+$/ ) {
    	    return ( $Fres, "error: broken format in parameter 'port_rate_us' => '".$fparm->{'port_rate_us'}."';" );
	}
    }


    if ( defined($fparm->{'port_rate_ds'}) ) { $Q_parm .= 'ds_speed:'.$fparm->{'port_rate_ds'}.';'; $parmset += 1; }
    if ( defined($fparm->{'port_rate_us'}) ) { $Q_parm .= 'us_speed:'.$fparm->{'port_rate_us'}.';'; $parmset += 1; }

    $Q_tune = "INSERT INTO bundle_jobs SET port_id=".$fparm->{'ap_id'}.", ltype_id=".$link_type{'setparms'}.", parm='".
    $Q_parm."' ON DUPLICATE KEY UPDATE date_insert=NULL, parm=CONCAT(parm,'".$Q_parm."')";

    if ( $debug > 1 ) {
        dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "DEBUG mode, Query '".$Q_tune."'" );
    } elsif (not $parmset) {
	$Fres = 2;
	$Fvalue = "error: not found change parameters;";
    } else {
        $dbm->do($Q_tune) or $Fres = 1;
        if ($Fres) {
    	    $Fvalue = "error:Error update AP info Query '".$Q_tune."';";
    	    dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', MESS => "ERROR update AP info Querry '".$Q_tune."'" ) 
        } else {
    	    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "UPDATED AP tune info, id N'".$fparm->{'ap_id'}."'" );
	}
    }
    return ($Fres+0, $Fvalue );
}

sub SW_AP_linkstate {
    DB_mysql_connect(\$dbm);
    my $Fres = 2; my $Fvalue = 'error:unknown error...;';
    my %state = (   'lock' 	=> 2,
		    'unlock'	=> 1,
		);

    my $fparm = shift;
    #	$fparm->{ap_id} = 1234
    #	$fparm->{state}=lock
    #	$fparm->{state}=unlock
    if		( not ( defined($fparm->{'ap_id'}) && $fparm->{'ap_id'} =~ /^\d+$/ ) ) {
	return ( $Fres, "error:not defined parameter 'ap_id';" );
    } elsif	( not ( defined($fparm->{'state'}) && $fparm->{'state'} =~ /^(unl|l)ock$/ ) ) {
	return ( $Fres, "error:not defined or broken parameter 'state';" );
    }
    my $stm_state = $dbm->prepare( "SELECT status FROM head_link where port_id=".$fparm->{'ap_id'} );
    $stm_state->execute or $Fres = 1;
    if ( $Fres == 1 || not $stm_state->rows == 1 ) {
	$Fres = 2;
	$Fvalue = 'error:AP head link not found;';
    } else {
	$dbm->do( "UPDATE head_link SET set_status=".$state{$fparm->{'state'}}." WHERE port_id=".$fparm->{'ap_id'}." and status<>".$state{$fparm->{'state'}} ) or $Fres = 1;
	if ( $Fres == 1 ) {
	    $Fvalue = 'error:Error update AP state info;';
	} else {
	    $Fres = 0;
	    $Fvalue = 'result:state sync success;';
	}
    }
    return ( $Fres+0, $Fvalue );
}


sub SAVE_config {
    DB_mysql_connect(\$dbm);
    # сохраняем конфиг на коммутаторе
    my %argscfg = (
	    @_,		# список пар аргументов
    );
    dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Save config in sw_id => '".$argscfg{'SWID'}."' IP => '".$argscfg{'IP'}."' (debug)" );
    return 0 if $debug>1;
    my $res=0;
    my %sw_arg = (
        LIB => $argscfg{'LIB'}, ACT => 'conf_save', IP => $argscfg{'IP'}, LOGIN => $argscfg{'LOGIN'}, PASS => $argscfg{'PASS'}, ENA_PASS => $argscfg{'ENA_PASS'},
    );
    $res = SW_ctl ( \%sw_arg ) if ( $argscfg{'LIB'} ne '');

    $dbm->do("UPDATE swports p, bundle_jobs j SET j.archiv=j.job_id WHERE j.port_id=p.port_id and j.archiv=1 and p.sw_id=".$argscfg{'SWID'}) if ($res>0 and $argscfg{'SWID'} > 0);
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
    if ( $arg{'TYPE'} >= $start_conf->{'STARTLINKCONF'} ) {
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

    DB_mysql_connect(\$dbm);
    dlog ( SUB => (caller(0))[3], DBUG => 2, MESS => 'GET Terminator info (debug)' );

    my %arg = (
        @_,         # список пар аргументов
    );
    # TYPE ZONE TERM_ID
    my $res = 0;
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
	$Querry_end = " and zone_id = 1";
	$stm31 = $dbm->prepare($Querry_start.$Querry_end);
	$stm31->execute();
    }
    if ($stm31->rows == 1) {
	my $ref31 = $stm31->fetchrow_hashref();
	my %head = %{$ref31};
	$stm31->finish();
	return \%head;
    } elsif ($stm31->rows > 1)  {
	dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "MULTI TERMINATOR! 8-), count = ".$stm31->rows );
    } else {
	dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => 'TERMINATOR NOT FOUND :-(' );
    }
    $stm31->finish();
    return -1;
}


sub VLAN_link {
	DB_mysql_connect(\$dbm);
	my %sw_arg = ();
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
	while ( defined($PAR{'sw_id'}) and $count < $start_conf->{'MAXPARENTS'} ) {
	    $PAR{'low_portpref'}  ||= "";
	    $PAR{'change'} = 0; 
	    $count +=1;
	    my $stm21 = $dbm->prepare("SELECT h.hostname, h.model_id, h.sw_id, h.ip, h.uplink_port, h.uplink_portpref, h.parent, h.parent_port, h.parent_portpref, ".
	    "m.lib, m.admin_login, m.admin_pass, m.ena_pass FROM hosts h, models m WHERE h.model_id=m.model_id and h.sw_id=".$PAR{'sw_id'}." order by h.sw_id");
	    $stm21->execute();
	    while (my $ref21 = $stm21->fetchrow_hashref()) {
		#$ref21->{'parent_portpref'} ||= "";
		if ( 'x'.$ref21->{'lib'} eq 'x' ) {
		    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "LIB not defined for switch ".$ref21->{'hostname'}.", Vlan link break :-( !!!" );
		    $stm21->finish;
		    return -1;
		}
	      if ( $PAR{'low_port'} > 0 and DB_trunk_vlan(ACT => $arglnk{'ACT'}, SWID => $ref21->{'sw_id'}, VLAN => $arglnk{'VLAN'}, 
		PORTPREF => $PAR{'low_portpref'}, PORT => $PAR{'low_port'}) < 1) {
		## пробрасываем/убираем тэгированный VLAN на присоединённом порту вышестоящего коммутатора
		dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DOWNLINK vlan ".$arglnk{'ACT'}."\n LIB => .$ref21->{'lib'},  IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, VLAN => $arglnk{'VLAN'}, ".
		"PORT => $PAR{'low_port'}, PORTPREF => $PAR{'low_portpref'}" );
                %sw_arg = (
                    LIB => $ref21->{'lib'}, ACT => 'vlan_trunk_'.$arglnk{'ACT'}, IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, 
		    PASS => $ref21->{'admin_pass'},ENA_PASS => $ref21->{'ena_pass'},VLAN => $arglnk{'VLAN'}, PORT => $PAR{'low_port'}, 
		    PORTPREF => $PAR{'low_portpref'}, UPLINKPORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORT => $ref21->{'uplink_port'},
                );
                $res = SW_ctl ( \%sw_arg );
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
            		%sw_arg = (
			    LIB => $ref21->{'lib'}, ACT => 'vlan_trunk_'.$arglnk{'ACT'}, IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'},
			    PASS => $ref21->{'admin_pass'}, ENA_PASS => $ref21->{'ena_pass'}, VLAN => $arglnk{'VLAN'}, PORT => $arglnk{'L2HEAD_PORT'}, 
			    PORTPREF => $arglnk{'L2HEAD_PORTPREF'}, UPLINKPORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORT => $ref21->{'uplink_port'},
			);
			$res = SW_ctl ( \%sw_arg );

			if ($res < 1) {
			    $stm21->finish();
			    return $res;
			}
			$PAR{'change'} += 1;
			DB_trunk_update(ACT => $arglnk{'ACT'}, SWID => $ref21->{'sw_id'}, PORTPREF => $arglnk{'L2HEAD_PORTPREF'}, PORT => $arglnk{'L2HEAD_PORT'}, VLAN => $arglnk{'VLAN'});
		    }
		    $count = $start_conf->{'MAXPARENTS'}; # завершаем  если добрались до головного коммутатора цепочки!
		} elsif ( defined($ref21->{'uplink_port'}) and DB_trunk_vlan(ACT => $arglnk{'ACT'}, SWID => $ref21->{'sw_id'}, VLAN => $arglnk{'VLAN'}, PORT => $ref21->{'uplink_port'}, PORTPREF => $ref21->{'uplink_portpref'}) < 1 ) {
		    ## пробрасываем/убираем тэгированный VLAN на UPLINK порту текущего коммутатора цепочки 
		    dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "UPLINK vlan ".$arglnk{'ACT'}."\n LIB => $ref21->{'lib'}, IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, VLAN => $arglnk{'VLAN'}, ".
		    "PORT => $ref21->{'uplink_port'}, PORTPREF => $ref21->{'uplink_portpref'}\n" );
		    %sw_arg = (
			LIB => $ref21->{'lib'}, ACT => 'vlan_trunk_'.$arglnk{'ACT'}, IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'},
			PASS => $ref21->{'admin_pass'}, ENA_PASS => $ref21->{'ena_pass'}, VLAN => $arglnk{'VLAN'}, PORT => $ref21->{'uplink_port'}, 
			PORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORTPREF => $ref21->{'uplink_portpref'}, UPLINKPORT => $ref21->{'uplink_port'},
		    );
		    $res = SW_ctl ( \%sw_arg );
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
			%sw_arg = (
			    LIB => $ref21->{'lib'}, ACT => 'vlan_remove', IP => $ref21->{'ip'}, LOGIN => $ref21->{'admin_login'}, PASS => $ref21->{'admin_pass'},
			    ENA_PASS => $ref21->{'ena_pass'}, VLAN => $arglnk{'VLAN'},
			);
			$res = SW_ctl ( \%sw_arg );
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
	DB_mysql_connect(\$dbm);
        my %argdb = (
            @_,         # список пар аргументов
        );
        $argdb{'PORTPREF'} ||= "";
	# ACT SWID VLAN PORTPREF PORT
        dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Save to DB change trunk VLAN => '".$argdb{'VLAN'}."', sw_id => '".$argdb{'SWID'}."' port => ".$argdb{'PORTPREF'}.$argdb{'PORT'}." (debug)" );
	return 1 if $debug>1;
	my $Qr_in = "SELECT port_id FROM swports WHERE sw_id=".$argdb{'SWID'}." and port=".$argdb{'PORT'};
	if ( 'x'.$argdb{'PORTPREF'} ne 'x' ) {
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
	DB_mysql_connect(\$dbm);
        my %argdb = (
            @_,         # список пар аргументов
        );
        $argdb{'PORTPREF'} ||= "";
	# ACT SWID VLAN PORTPREF PORT
	my $res = 0;
	# Умолчания для результата процедуры поиска
	$res = -1 if ("x".$argdb{'ACT'} eq 'xadd');    #Прокидывание VLAN'а: нет в транке - добавить
	$res =  1 if ("x".$argdb{'ACT'} eq 'xremove'); #Убирание     VLAN'а: нет в транке - не удалять
        dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Check Vlan in trunk port => '".$argdb{'VLAN'}."', sw_id => '".$argdb{'SWID'}."' portpref => '".$argdb{'PORTPREF'}."', port => ".$argdb{'PORT'}." (debug)" );

	return 1 if $debug>1;
	my $Qr_in = "SELECT port_id FROM swports WHERE sw_id=".$argdb{'SWID'}." and port=".$argdb{'PORT'};
	if ( 'x'.$argdb{'PORTPREF'} ne 'x' ) {
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

	DB_mysql_connect(\$dbm);
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

	DB_mysql_connect(\$dbm);
        my %arg = (
            @_,         # список пар аргументов
        );
	# PORT_ID LINK_TYPE ZONE
	my $head = GET_Terminfo ( TYPE => $arg{'LINK_TYPE'}, ZONE => $arg{'ZONE'} );
	my $increment = 1; my $res = -1;

	my %vlanuse = ();
	my $Qr_range = "SELECT vlan_id FROM vlan_list WHERE vlan_id>=".$head->{'vlan_min'}." and vlan_id<=".$head->{'vlan_max'}." and zone_id=".$head->{'zone_id'};
        my $stm35 = $dbm->prepare($Qr_range);
        $stm35->execute();
	while (my $ref35 = $stm35->fetchrow_hashref()) {
	    $vlanuse{$ref35->{'vlan_id'}} = 1;
	}
	$stm35->finish();
		
	my $vlan_id=0; 
	if ($increment) {
	    $vlan_id = $head->{'vlan_min'};
	    while ( $res < 1 and $vlan_id <= $head->{'vlan_max'} ) {
		dlog ( SUB => (caller(0))[3]||'', DBUG => 2, MESS =>  "PROBE VLAN N".$vlan_id." VLANDB -> '".( defined($vlanuse{$vlan_id}) ? 'found' : 'none' )."'" );
		$res = $vlan_id if not defined($vlanuse{$vlan_id});
		$vlan_id += 1;
	    }
	} else {
	    $vlan_id = $head->{'vlan_max'};
	    while ( $res < 1 and $vlan_id >= $head->{'vlan_min'} ) {
		dlog ( SUB => (caller(0))[3]||'', DBUG => 2, MESS => "PROBE VLAN N".$vlan_id." VLANDB -> '".( defined($vlanuse{$vlan_id}) ? 'found' : 'none' )."'" );
		$res = $vlan_id if not defined($vlanuse{$vlan_id});
		$vlan_id -= 1;
	    }
	}

	if ($res > 0 and $debug < 2) {
	    $dbm->do("INSERT into vlan_list SET info='AUTO INSERT VLAN record from vlan range', vlan_id=".$res.", zone_id=".$head->{'zone_id'}.
	    ", port_id=".$arg{'PORT_ID'}.", link_type=".$arg{'LINK_TYPE'}." ON DUPLICATE KEY UPDATE info='AUTO UPDATE VLAN record', port_id=".
	    $arg{'PORT_ID'}.", link_type=".$arg{'LINK_TYPE'}); 
	}
	return ( $res, $head->{'head_id'} ) ;
}

1;
