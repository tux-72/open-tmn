#!/usr/bin/perl

my $debug=1;

package SWFunc;

use strict;
no strict qw(refs);

#use locale;
use POSIX qw(strftime);
use cyrillic qw(cset_factory);
use DBI();
use NSNMP::Simple;

use Authen::Radius;
Authen::Radius->load_dictionary();

use DESCtl;
use C73Ctl;
use CATIOSCtl;
use CATIOSLTCtl;
use CATOSCtl;
use ESCtl;
use GSCtl;
use BPSCtl;
use TCOM4500Ctl;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();


$VERSION = 1.9;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw( SW_AP_get SW_AP_fix SW_AP_tune SW_AP_free SW_AP_linkstate SW_ctl SW_VLAN_fix
	    dlog rspaced lspaced IOS_rsh GET_IP3 GET_pipeid PRI_calc GET_ppp_parm
	    DB_mysql_connect DB_trunk_vlan DB_trunk_update DB_MSsql_connect DHCP_post_auth
	    SAVE_config VLAN_link GET_Terminfo GET_GW_parms ACC_update PPP_post_auth
	    VLAN_VPN_get VLAN_get VLAN_remove SNMP_fix_macport
);

my $start_conf	= \%SWConf::conf;
my $conflog	= \%SWConf::conflog;
my $dbi		= \%SWConf::dbconf;
my $nas_conf	= \%SWConf::aaa_conf;

use Data::Dumper;

my $w2k = cset_factory 1251, 20866;
my $k2w = cset_factory 20866, 1251;

my $Querry_start = '';
my $Querry_end = '';
my $res;
my $dbm;
my $dbms;

DB_mysql_connect(\$dbm);

DB_MSsql_connect(\$dbms);


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

our %headinfo = ();
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

sub DB_MSsql_connect {
	my $mssqlconnect = shift;
	${$mssqlconnect} = DBI->connect_cached("DBI:Sybase:server=".$dbi->{'MSSQL_server'}.
	";language=russian;database=".$dbi->{'MSSQL_base'},$dbi->{'MSSQL_user'},$dbi->{'MSSQL_pass'})
	#${$mssqlconnect} = DBI->connect_cached("DBI:Sybase:server=".$dbi->{'MSSQL_server'}.";database=".$dbi->{'MSSQL_base'},$dbi->{'MSSQL_user'},$dbi->{'MSSQL_pass'})
	or die "Unable to connect MSSQL server ".$dbi->{'MSSQL_server'}."$DBI::errstr";
	#or die dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MSSQL DB host ".$dbi->{'MSSQL_host'}."$DBI::errstr" );
	${$mssqlconnect}->do("set dateformat dmy") or die return -1;
	#dlog ( DBUG => 2, SUB => (caller(0))[3],  MESS => "MSsql connect ID = ".${$mssqlconnect}->{'mssql_thread_id'} );
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

sub SW_VLAN_fix {
	my $AP = shift;
	####### Start FIX VLAN ID) ########### 
	my %sw_arg = (
	    LIB => $headinfo{'L2LIB_'.$AP->{'nas_ip'}}, ACT => 'fix_vlan', IP => $headinfo{'L2IP_'.$AP->{'nas_ip'}}, 
	    LOGIN => $headinfo{'MONLOGIN_'.$AP->{'nas_ip'}},	PASS => $headinfo{'MONPASS_'.$AP->{'nas_ip'}}, MAC => $AP->{'hw_mac'},
	);
	$AP->{'vlan_id'} = SW_ctl ( \%sw_arg );
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
        #       $fparm->{nas_port_id} = '0/0/1/0'
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
	    'id',	0,
	    'trust',	0,
	    'set',	0,
	    'callsub',	'PPPoE2Dispatcher',
	    'vlan_zone', 1,
	    'update_db', 0,
	    'DB_portinfo',	0,
	    'vlan_id',	0,
	    'hw_mac',	$fparm->{'mac'},
	    'pri',	$fparm->{'inet_priority'},
	    'trust_id',	$fparm->{'ap_id'},
	    'name',	'',
	    'swid',	0,
	    'bw_ctl',	0,
	);

	####### Start FIX VLAN ID) ########### 
	%sw_arg = (
	    LIB => $headinfo{'L2LIB_'.$fparm->{'nas_ip'}}, ACT => 'fix_vlan', IP => $headinfo{'L2IP_'.$fparm->{'nas_ip'}}, 
	    LOGIN => $headinfo{'MONLOGIN_'.$fparm->{'nas_ip'}},	PASS => $headinfo{'MONPASS_'.$fparm->{'nas_ip'}}, MAC => $fparm->{'mac'},
	);
	$AP{'vlan_id'} = SW_ctl ( \%sw_arg );

	if ( $AP{'vlan_id'} < 1) {
	    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "User '".$fparm->{'login'}."'".' Access point VLAN is not FIX!!! Trobles connect to ZONE SWITCH???' );
	    $Fres = 2;
	    $Fvalue = 'error:MAC VLAN not fixed... :-(;';
	} else {
		dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "User '".$fparm->{'login'}."'".' Access point VLAN = '.$AP{'vlan_id'} );
		########### Start FIX Access Point (AP) ########### 
		$AP{'trust_id'}	= $fparm->{'ap_id'};
		$AP{'nas_ip'}	= $fparm->{'nas_ip'};
		$AP{'login'}	= $fparm->{'login'};
		SW_AP_fix( \%AP );
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
			$Query .= ", hw_mac='".$fparm->{'mac'}."', vlan_id='".$AP{'vlan_id'}."', port_id='".$AP{'id'}."', ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."'";
			$Query .= ", ip_addr='".$fparm->{'ip_addr'}."'" if ( not $fparm->{'ip_addr'} =~ /^10\.13\.2[45][0-9]\.\d{1,3}$/ );
			$Query .= " ON DUPLICATE KEY UPDATE trust=".$AP{'trust'}.", ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."', last_date='".$date."', vlan_id='".$AP{'vlan_id'}."'";
			$Query .= ", ip_addr='".$fparm->{'ip_addr'}."'" if ( not $fparm->{'ip_addr'} =~ /^10\.13\.2[45][0-9]\.\d{1,3}$/ );
			$dbm->do("$Query");

			## HEAD_LINK inserting data
			if ( $AP{'trust'} and $fparm->{'link_type'} == $link_type{'pppoe'} ) {
			    if ( $fparm->{'ip_addr'} =~ /^10\./ ) { 
				$AP{'pri'} = $fparm->{'inet_priority'}||1;
			    } else {
				$AP{'pri'} = 3;
			    }
			    $Query = "INSERT INTO head_link SET port_id=".$AP{'id'}.", status=1, white_static_ip=0, dhcp_use=".$nas_conf->{'DHCP_USE'}.", ";
			    $Q_upd = " vlan_id=".$AP{'vlan_id'}.", login='".$fparm->{'login'}."', hw_mac='".$fparm->{'mac'}."', communal=".$AP{'communal'}.
			    ", inet_shape=".$fparm->{'inet_rate'}.", inet_priority=".$AP{'pri'}.", stamp=NULL, ip_subnet='".$fparm->{'ip_addr'}."'".
			    ", head_id=".$headinfo{'LHEAD_'.$fparm->{'nas_ip'}}.", pppoe_up=1";
			    $Query .= $Q_upd." ON DUPLICATE KEY UPDATE ".$Q_upd;
			    $dbm->do("$Query") or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => "$Query \n$DBI::errstr" );
			}
		######################## SET JOB PARAMETERS
			# Если необходимо делать изменения на порту - $AP{'set'} и коммутатор управляется
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
				#$Query .= ", ltype_id=".$fparm->{'link_type'};
				if ( "x".$fparm->{'vlan_id'} eq "x" ) {
				    # PORT_ID LINK_TYPE ZONE
				    ( $fparm->{'vlan_id'}, $AP{'head_id'} ) = VLAN_get ( PORT_ID => $AP{'id'}, 
				    LINK_TYPE => $fparm->{'link_type'}, ZONE => $AP{'vlan_zone'} );
				    if ( $fparm->{'vlan_id'} > 1 ) {
					$Fvalue .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
					$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
				    }
				} else {
				    $job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
				}
			    }
			    ######## Transport Net ############
			    if ( defined($fparm->{'ip_addr'}) and $fparm->{'link_type'} == $link_type{'l3net4'} ) {
				if ( "x".$fparm->{'vlan_id'} eq "x" ) {
				    $job_parms .= 'ip_subnet:'.(GET_IP3($fparm->{'ip_addr'}.'/30')).'/30;' ;
				    # PORT_ID LINK_TYPE ZONE
				    ( $fparm->{'vlan_id'}, $AP{'head_id'} ) = VLAN_get ( PORT_ID => $AP{'id'}, 
				    LINK_TYPE => $link_type{'l3net4'}, ZONE => $AP{'vlan_zone'} );
				    if ( $fparm->{'vlan_id'} > 1 ) {
					$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';';
				    }
				}
			    }

			    # Проверка изменений link_type
			    ## Если порт был свободен и задействуется под PPPoE
			    if ( $AP{'link_type'} == $link_type{'free'} and $fparm->{'link_type'} == $start_conf->{'CLI_VLAN_LINKTYPE'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
				$job_parms .= 'vlan_id:'.$AP{'vlan_id'}.';';
			    ## Иначе если порт был свободен и задействуется под другие типы подключений  
			    } elsif ( $AP{'link_type'} == $link_type{'free'} ) {
				$Query .= ", ltype_id=".$fparm->{'link_type'};
				$job_parms .= 'vlan_id:'.$fparm->{'vlan_id'}.';' if ( $fparm->{'vlan_id'} > 1 );
			    ## Иначе если порт занят под такой же тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $fparm->{'link_type'}+0 == $AP{'link_type'}+0 ) {
				$Query .= ", ltype_id=".$link_type{'setparms'};
				$job_parms .= 'vlan_id:'.$AP{'vlan_id'}.';';
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

		} elsif ( $AP{'vlan_id'} ) {
		    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "AP ID '".$fparm->{'login'}."' in VLAN ".$AP{'vlan_id'}." not fixed!!!" );
		    $Fres = 2;
		    $Fvalue = 'error:MAC found in VLAN '.$AP{'vlan_id'}.'. Access point not fixed... :-(;';
		}
	}
        dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => 
	"QUERY: Login  = '".$fparm->{'login'}."', MAC = '".$fparm->{'mac'}."', NAS_IP = ".$fparm->{'nas_ip'}."\n".
	"AP_CHECK: ".$RES[$Fres].'('.$Fres.')'.", Login = '".$fparm->{'login'}."', AP_ID = '".$AP{'id'}."', '".$AP{'name'}.", ZONE = ".$AP{'vlan_zone'}.", VLAN = ".$AP{'vlan_id'}."'\n".
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

sub GET_IP3 {
    my $subip3 = shift;
    my @ln = `/usr/local/bin/ipcalc $subip3`;
    foreach (@ln) {
        if ( /HostMax\:\s+(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\s+/ ) {
            #dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Change '".$subip3."' to '$1.$2.$3.$4'" );
            $subip3 = "$1.$2.$3.$4";
        }
    }
    return $subip3;
}


sub GET_pipeid {
    my $speed = shift;
    my %pipeid = (
	'64'	=> 1006,
	'128'	=> 1010,
	'256'	=> 1020,
	'512'	=> 1050,
	'1000'	=> 1100,
	'2000'	=> 1200,
	'3000'	=> 1300,
	'4000'	=> 1400,
	'5000'	=> 1500,
	'6000'	=> 1600,
	'7000'	=> 1700,
	'8000'	=> 1800,
	'9000'	=> 1900,
	'10000'	=> 2000,
    );
    if ( defined($pipeid{$speed}) ) {
	return $pipeid{$speed};
    } else {
	return 1010;
    }
}

sub PRI_calc {
    my $rate = shift;
    my $pri  = shift;
    my $priority = 20;
    # Normalise megabits for rate > 999 Kbits
    $rate = int($rate/1000)*1000 if ($rate > 999 );

    if ($rate > 3100)      {
        $priority = $pri*20+int($rate/1000)*5;
    } elsif ($rate > 1100) {
        $priority = $pri*20+int($rate/500)*4;
    } elsif ($rate > 900)  {
        $priority = $pri*20+int($rate/200)*3;
    } elsif ($rate > 400)  {
        $priority = $pri*20+int($rate/100)*2;
    } elsif ($rate > 200)  {
        $priority = $pri*20+int($rate/100)*4;
    } else {
        $priority = $pri*20+int($rate/100)*3;
    }
    $priority   = 80 if ($priority > 80 );
    return ($rate, $priority)
}

sub SNMP_fix_macport {

    #### IP MAC VLAN ROCOM
    my $arg = shift;
    my $getname = shift;
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "SNMP FIX PORT in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}.", VLAN '".$arg->{'VLAN'}."'" );
    my $pref; my $max = 2; my $count = 0; my $timeout = 1; my $index;

    my $OID = '1.3.6.1.2.1.17.7.1.2.2.1.2.'.$arg->{'VLAN'}.".". (join".", map{hex} split/:/,$arg->{'MAC'});
    my $port = NSNMP::Simple->get( $arg->{'IP'}, $OID, version => 1, retries => $max, timeout => $timeout, community => $arg->{'ROCOM'} );
    #print STDERR " OID '".$OID."'\n" if $debug;
    if ( not defined($port) ) {
        SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], LOGTYPE => 'LOGAPFIX', MESS => "Error in SNMP get port index for MAC '".$arg->{'MAC'}."' ".$NSNMP::Simple::error );
        $port = -1;
    }
    #print STDERR "NSNMP fix portindex = ".$port."\n" if $debug;
    $index = $port;

    if ($getname and $index > 0 ) {
        $OID = '1.3.6.1.2.1.31.1.1.1.1.'.$index;
        my $portname = NSNMP::Simple->get( $arg->{'IP'}, $OID, version => 1, retries => $max, timeout => $timeout, community => $arg->{'ROCOM'} );
        if ( defined($portname) ) {
            if ( $portname =~ /^(\d+)$/ ) {
                $port = $1;
            } elsif ( $portname =~ /^\d+\/(\d+)$/ ) {
                $port = $1;
            } elsif ( $portname =~ /^(\D+\/)(\d+)$/ ) {
                $pref = $1;
                $port = $2;
            } elsif ( $portname =~ /^(\D+)(\d+)$/ ) {
                $pref = $1;
                $port = $2;
            } else {
                SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Unknown portname type '$portname'" );
                print STDERR "Unknown portname type '$portname'\n";
            }
            print STDERR "NSNMP fix portname = '".$portname."', pref = '".$pref."', port = '".$port."'\n" if $debug;
        } else {
            SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Error in SNMP get port name for index '$port'. MAC '".$arg->{'MAC'}."' ".$NSNMP::Simple::error );
            $port = -1;
        }
    }
    return ($pref, $port, $index);
}


sub SNMP_fix_macport_name {

    #### IP MAC VLAN ROCOM
    my $arg = shift;
    my $rocom = $arg->{'ROCOM'};
    if ( $arg->{'LIB'} =~ /^CATI?OS/ ) {
        $rocom .= '@'.$arg->{'VLAN'};
    }
    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "SNMP FIX PORT in switch '".$arg->{'IP'}."', MAC '".$arg->{'MAC'}.", VLAN '".$arg->{'VLAN'}."'" );
    my $pref; my $port = -1; my $max = 2; my $count = 0; my $timeout = 1; my $idx;

    my $OID = '.1.3.6.1.2.1.17.4.3.1.2.'. (join".", map{hex} split/:/,$arg->{'MAC'});
    my $idx1 = NSNMP::Simple->get( $arg->{'IP'}, $OID, version => 1, retries => $max, timeout => $timeout, community => $rocom );

    if ( not defined($idx1) ) {
        SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], LOGTYPE => 'LOGAPFIX', MESS => "Error in CISCO SNMP get idx1 for MAC '".$arg->{'MAC'}."' ".$NSNMP::Simple::error );
        $port = -1;
    } else {
        #print STDERR "NSNMP fix port index1 = ".$idx1."\n" if $debug;

        $OID = '.1.3.6.1.2.1.17.1.4.1.2.'.$idx1;
        $idx = NSNMP::Simple->get( $arg->{'IP'}, $OID, version => 1, retries => $max, timeout => $timeout, community => $rocom );
        #print STDERR "NSNMP fix port index = ".$idx."\n" if $debug;

        if ( defined($idx) ) {
            $OID = '1.3.6.1.2.1.31.1.1.1.1.'.$idx;
            my $portname = NSNMP::Simple->get( $arg->{'IP'}, $OID, version => 1, retries => $max, timeout => $timeout, community => $arg->{'ROCOM'} );
            if ( defined($portname) ) {
                if      ( $portname =~ /^(\S+\/)(\d+\-\d+)$/ ) {
                    $pref = $1;
                    $port = $2;
                } elsif ( $portname =~ /^(\d+\/)(\d+)$/ ) {
                    $pref = $1;
                    $port = $2;
                } elsif ( $portname =~ /^(\S+\/)(\d+)$/ ) {
                    $pref = $1;
                    $port = $2;
                } elsif ( $portname =~ /^(\D+)(\d+)$/ ) {
                    $pref = $1;
                    $port = $2;
                } else {
                    SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Unknown portname type '$portname'" );
                    print STDERR "Unknown portname type '$portname'\n" if $debug;
                }
                print STDERR "NSNMP fix portname = '".$portname."', pref = '".$pref."', port = '".$port."'\n" if $debug;
            } else {
                SWFunc::dlog ( DBUG => 0, SUB => (caller(0))[3], MESS => "Error in CISCO SNMP get idx for MAC '".$arg->{'MAC'}."' ".$NSNMP::Simple::error );
                $port = -1;
            }
        }
    }
    return ($pref, $port, $idx);
}


######################################### FREERADIUS SUBS for rlm_perl #######################################

sub ACC_update {

	my $RAD_REQUEST = shift;
	DB_MSsql_connect(\$dbms);
	&radiusd::radlog(1, "---------------- PERL ACCOUNTING ---------------------");
	my $ip1; my $ip2; my $ip3; my $ip4;
	my $name = "";
	my $iface = 0;
	my $port = 0;
	my $date = "";
	my $time = 0;
	my $status = 2;

	if ( $RAD_REQUEST->{'NAS-IP-Address'} ne $nas_conf->{'pppoe_server'} ) {
               return -1;
	};

	if ($RAD_REQUEST->{'Framed-IP-Address'} && ($RAD_REQUEST->{'Framed-IP-Address'} =~ /^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/) ) {
		$ip1 = $1;
		$ip2 = $2;
		$ip3 = $3;
		$ip4 = $4;
	} else {
		$ip1 = $ip2 = $ip3 = $ip4 = 0;
	}


	$RAD_REQUEST->{'User-Name'} and $name = $RAD_REQUEST->{'User-Name'};
	$RAD_REQUEST->{'Acct-Session-Id'} and $iface = $RAD_REQUEST->{'Acct-Session-Id'};
	$RAD_REQUEST->{'NAS-Port'} and $port = $RAD_REQUEST->{'NAS-Port'};
	#$hdrs{'Timestamp'} and $date = $hdrs{'Timestamp'};
	$RAD_REQUEST->{'Acct-Session-Time'} and $time = $RAD_REQUEST->{'Acct-Session-Time'};
	$RAD_REQUEST->{'Acct-Delay-Time'} and ($time > $RAD_REQUEST->{'Acct-Delay-Time'}) and do {
	    $time -= $RAD_REQUEST->{'Acct-Delay-Time'};
	};
	$RAD_REQUEST->{'Acct-Status-Type'} and $status = $RAD_REQUEST->{'Acct-Status-Type'};

	$name =~ /^\s*"?(.*?)"?\s*$/ and $name = $1;
	$name =~ /^\s*(\S*?)\s*$/ and $name = $1;

	$iface =~ /^\s*"?(.*?)"?\s*$/ and $iface = $1;
	$iface =~ /^\s*(\S*?)\s*$/ and $iface = $1;
	$iface = hex $iface;

	$status = 2 if $status eq "Start";		# 1
	$status = 2 if $status eq "Interim-Update"; 	# 3
	$status = 3 if $status eq "Stop";		# 2

	my @d = ();
	#$date = strftime "%d.%m.%Y %H:%M:%S", localtime($date);
	$date = strftime "%d.%m.%Y %H:%M:%S", localtime(time);
	&radiusd::radlog(1, "---------- DATE = $date, TIME = $time -----------");

	if ($status != 3) {
		my $sth = $dbms->prepare("select status from preparetime where username='$name' and interfacenumber=$iface");
		$sth->execute;
		@d = $sth->fetchrow_array;
		$sth->finish;
		if (defined($d[0]) && ($d[0] == 4)) {
			#&radiusd::radlog(1, "---------------- send POD ---------------------");
			## reset session
			my %pod_parm = ('nas_ip'	=> $RAD_REQUEST->{'NAS-IP-Address'},
					'nas_port'		=> $nas_conf->{'pod_port'},
					'nas_secret'	=> $nas_conf->{'pod_secret'},
					'login'		=> $RAD_REQUEST->{'User-Name'},
			);
			send_pod (\%pod_parm );
		}

	}
	$dbms->do("exec WorkPrepareTime $ip1, $ip2, $ip3, $ip4, '$name', $iface, '$date', $time, $status");
	return 1;
}

sub send_pod  {

    my $param = shift;
    # nas_ip nas_port nas_secret login

    my ( $res, $a, $err, $strerr );
    my $res_attr = "attr:";

    my $r = new Authen::Radius(Host => $param->{'nas_ip'}.":".$param->{'nas_port'}, Secret => $param->{'nas_secret'}, Debug => 0);
    $r->add_attributes (
      { Name => 'User-Name', Value => $param->{'login'} }
    );

    $r->send_packet(DISCONNECT_REQUEST);
    $res = $r->recv_packet();

    $err = $r->get_error;
    $strerr = $r->strerror;

    &radiusd::radlog(1, "POD error = $err $strerr" );

    for $a ($r->get_attributes()) {
	$res_attr .= ",".$a->{'Name'}."='".$a->{'Value'}."'";
	if($a->{'Name'} eq 'Error-Cause' &&  $a->{'Value'} eq 'Session-Context-Not-Found') {
	    $res = 41;
	}
    }
    &radiusd::radlog(1, "strerr:".$strerr.";".$res_attr );
}



sub SW_AP_fix {

	DB_mysql_connect(\$dbm);
	my $Query10 = ''; my $Query0 = ''; my $Query1 = ''; my %sw_arg = (); my $cli_vlan=0;
	my $AP = shift;
	#my %arg = (
	#    @_,         # список пар аргументов
	#);
	# AP_INFO LOGIN LTYPE VLAN NAS_IP HW_MAC
	if ( not defined($headinfo{'ZONE_'.$AP->{'nas_ip'}}) ) {
	    dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGAPFIX', MESS => "NAS '".$AP->{'nas_ip'}."'ZONE not exist, AP not fixed..." );
	    return -1;
	}

	#my $AP = $arg{'AP_INFO'};
	$AP->{'vlan_zone'} = $headinfo{'ZONE_'.$AP->{'nas_ip'}};
	$AP->{'fix_vlan_type'} = " UNKNOWN ";
	$AP->{'fix_ap_type'} = "";

	############# GET Switch IP's
	my $stm0 = $dbm->prepare("SELECT h.automanage, h.bw_ctl, h.sw_id, h.ip, h.model_id, h.hostname, st.street_name, h.dom, h.podezd, h.unit, m.lib, m.rocom, m.snmp_ap_fix, ".
	"m.mon_login, m.mon_pass FROM hosts h, streets st, models m WHERE h.model_id=m.model_id and h.street_id=st.street_id and m.lib is not NULL and h.clients_vlan=".
	$AP->{'vlan_id'}." and h.zone_id=".$AP->{'vlan_zone'}." and h.visible>0" );
	$stm0->execute();
		if ($stm0->rows>1) { dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => "More by one switch in Clients VLAN '".$AP->{'vlan_id'}."'!!!" ); }

		while (my $ref = $stm0->fetchrow_hashref() and not $AP->{'id'}) {
			$cli_vlan=1;
			$AP->{'automanage'}=1 if ($ref->{'automanage'});
			$AP->{'bw_ctl'}=1 if ($ref->{'bw_ctl'});

			%sw_arg = (
			    LIB => $ref->{'lib'}, ACT => 'fix_macport', IP => $ref->{'ip'}, LOGIN => $ref->{'mon_login'}, PASS => $ref->{'mon_pass'},
			    MAC => $AP->{'hw_mac'}, VLAN => $AP->{'vlan_id'}, ROCOM => $ref->{'rocom'}, USE_SNMP => $ref->{'snmp_ap_fix'},
			);
			### Fix locate MAC in switch
			( $AP->{'portpref'}, $AP->{'port'}, $AP->{'portindex'} ) = SW_ctl ( \%sw_arg );
			    #print STDERR ($AP->{'portpref'}||"").", ".$AP->{'port'}.", ".$AP->{'portindex'}."\n" if $debug;

			if ($AP->{'port'}>0 or $stm0->rows == 1) {
				$AP->{'swid'} = $ref->{'sw_id'}; $AP->{'podezd'} = $ref->{'podezd'};
                                $AP->{'name'} = "ул. ".$ref->{'street_name'}.", д.".$ref->{'dom'};
				$AP->{'name'} .= ", п.".$ref->{'podezd'} if $ref->{'podezd'}>0;
				$AP->{'name'} .= ", unit N".$ref->{'unit'} if defined($ref->{'unit'});
			}
			if ($AP->{'port'}>0) {
				if ( defined($AP->{'portpref'}) and 'x'.$AP->{'portpref'} ne 'x' ) {
				    $Query10 = "SELECT port_id FROM swports WHERE portpref='".$AP->{'portpref'}."' and  port=".$AP->{'port'}." and sw_id=".$AP->{'swid'};
				    $Query0 = "SELECT port_id, communal, ds_speed, us_speed, ltype_id, vlan_id, autoneg, speed, duplex, maxhwaddr FROM swports WHERE portpref='".$AP->{'portpref'}."' and  port='".$AP->{'port'}."' and sw_id=".$AP->{'swid'};
				    $Query1 = "INSERT into swports  SET  status=1, ltype_id=".$link_type{'free'}.", type=1, ds_speed=64, us_speed=64, portpref='".$AP->{'portpref'}."', port='".$AP->{'port'}."', sw_id='".$AP->{'swid'}."', vlan_id=-1";
				} else {
				    $Query10 = "SELECT port_id FROM swports WHERE portpref is NULL and port=".$AP->{'port'}." and sw_id=".$AP->{'swid'};
				    $Query0 = "SELECT port_id, communal, ds_speed, us_speed, ltype_id, vlan_id, autoneg, speed, duplex, maxhwaddr FROM swports WHERE portpref is NULL and port='".$AP->{'port'}."' and sw_id=".$AP->{'swid'};
				    $Query1 = "INSERT into swports  SET status=1, ltype_id=".$link_type{'free'}.", type=1, ds_speed=64, us_speed=64, portpref=NULL, port='".$AP->{'port'}."', sw_id='".$AP->{'swid'}."', vlan_id=-1";
				}
				$Query1 .= ", snmp_idx=".$AP->{'portindex'} if ( defined($AP->{'portindex'}) and $AP->{'portindex'} != $AP->{'port'} );

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
                                        $AP->{'name'} .= ", порт ".( defined($AP->{'portpref'}) ? $AP->{'portpref'} : '' ).$AP->{'port'};
					$stm1->finish;
			}
			$AP->{'fix_vlan_type'} = " CLI_VLAN";
		}
		$stm0->finish;
		if ( ( not $AP->{'id'}) and ( not $cli_vlan ) ) {
			dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGAPFIX', MESS => "FIND PORT VLAN '".$AP->{'vlan_id'}."' User: '".$AP->{'login'}."', MAC:'".$AP->{'hw_mac'}."'" );
			$AP->{'DB_portinfo'}=1;
			$stm0 = $dbm->prepare( "SELECT h.automanage, h.bw_ctl, h.ip, h.model_id, h.hostname, st.street_name, h.dom, h.podezd, h.unit,".
			" p.sw_id, p.port_id, p.ltype_id, p.communal, p.portpref, p.port, p.ds_speed, p.us_speed, ".
			" p.vlan_id, p.autoneg, p.speed, p.duplex, p.maxhwaddr FROM hosts h, streets st, swports p ".
			" WHERE h.street_id=st.street_id and p.sw_id=h.sw_id and p.vlan_id=".$AP->{'vlan_id'}." and h.zone_id=".$AP->{'vlan_zone'} );
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
			    $AP->{'fix_vlan_type'} = "PORT_VLAN";
			}
			$stm0->finish;
		}
		if ( $AP->{'id'}) {
		    
		    $AP->{'fix_ap_type'} = ( $AP->{'id'} == $AP->{'trust_id'} ? "trust " : "Left!!!" ) if defined ($AP->{'trust_id'}) ;
		    $AP->{'fix_dlog'} = '('. $dbm->{'mysql_thread_id'}.') '.$AP->{'fix_vlan_type'}." '".$AP->{'vlan_id'}."' MAC '".$AP->{'hw_mac'}."' User: '".
		    rspaced($AP->{'login'}."'",18)." AP ".$AP->{'fix_ap_type'}." '".$AP->{'id'}."' - '".$AP->{'name'}."'";
		    if ( $AP->{'fix_ap_type'} eq "Left!!!" ) {
			$AP->{'fix_dlog'} .= " ( trust AP = '".$AP->{'trust_id'}."' )";
		    }
		    dlog ( SUB => $AP->{'callsub'}||(caller(0))[3]||'unknown', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => $AP->{'fix_dlog'} );
		}
}

sub GET_ppp_parm {

	#######  UserAuth ########### 
	my $RAD_REQUEST = shift;
	my $RAD_REPLY = shift;
	my $Q_upd_db = shift;

	DB_MSsql_connect(\$dbms);
	DB_mysql_connect(\$dbm);

	my %AP = (
		'callsub'	=> 'PPPoE2RADIUS',
		'login_service'	=> 0,
		'vlan_id'	=> 0,
		'trust'		=> 0,
		'id'		=> 0,
		'new_lease'	=> 0,
		'set'		=> 0,
		'vlan_zone'	=> 1,
		'update_db'	=> 0,
		'DB_portinfo'	=> 0,
		'vlan_id'	=> 0,
		'name'		=> '',
		'swid'		=> 0,
		'bw_ctl'	=> 0,
		'nas_ip'	=> $RAD_REQUEST->{'NAS-IP-Address'},
		'login'		=> $RAD_REQUEST->{'User-Name'},
	);
	$Q_upd_db->{'User-Name'} = $RAD_REQUEST->{'User-Name'};


	if ( not exists($RAD_REQUEST->{'Framed-Protocol'}) and defined($RAD_REQUEST->{'NAS-Identifier'}) 
	and $RAD_REQUEST->{'NAS-Identifier'} eq $nas_conf->{'mail_server'} ) {
	    print Dumper $RAD_REQUEST;
	    $AP{'login_service'} = 1;
	    $AP{'trust'} = 1;
	} else {
	    $AP{'cisco_num'} = 1;
	}

	if ( $AP{'login_service'} == 0 ) {
	    if ( defined($RAD_REQUEST->{'Cisco-AVPair'}) and $RAD_REQUEST->{'Cisco-AVPair'} =~ /client\-mac\-address\=(\w\w)(\w\w)\.(\w\w)(\w\w)\.(\w\w)(\w\w)/ ) {
		$AP{'hw_mac'}  = lc("$1:$2:$3:$4:$5:$6");
		$AP{'mac_src'} = lc("$1$2$3$4$5$6");
		&radiusd::radlog(1,  "HW_MAC = ". $AP{'hw_mac'} );
		if (($AP{'hw_mac'} eq "0") || ($AP{'hw_mac'} eq "00:00:00:00:00:00")) {
		    &radiusd::radlog(1, "User '".$RAD_REQUEST->{'User-Name'}."' MAC '".$AP{'hw_mac'}."' is Wrong!!!\n\n") if $debug;
		}
	    } else {
		&radiusd::radlog(1,  "HW_MAC not Fix in RADIUS Pair" );
		return -1;
	    }
	    ####### Fixing VLAN ID ###########
	    SW_VLAN_fix( \%AP );
	    &radiusd::radlog(1, "User VLAN = ".$AP{'vlan_id'} );

	    #print Dumper %AP;
	    ####### Fixing AP ID ###########
	    SW_AP_fix( \%AP );
	    &radiusd::radlog(1, "User AP_id = ".$AP{'id'} );

	    ###### Get parms from Billing

	    ####### UserCheckMAC ########### 
	    my $Q_Check_MAC = "exec UserCheckMAC '".$RAD_REQUEST->{'User-Name'}."', '".$AP{'hw_mac'}."', ".$AP{'id'}.", '".
	    &$k2w($AP{'name'})."', ".(! $AP{'communal'}).", ".$AP{'cisco_num'}.", ".$AP{'swid'};
#	    &$k2w($AP{'name'})."', ".$AP{'bw_ctl'}.", ".$AP{'cisco_num'}.", ".$AP{'swid'};

	    my $sth = $dbms->prepare($Q_Check_MAC);
	    $sth->execute;
	    my $ref_ms = $sth->fetchrow_hashref();
	    $sth->finish;
	    $AP{'trust'} = $ref_ms->{'FlagAccess'};
	    if ( $AP{'trust'} < 0 ) {
		$RAD_REPLY->{'Reply-Message'} = $ref_ms->{'TextError'} if defined($ref_ms->{'TextError'});
		return $AP{'trust'};
	    }
	#    foreach my $key ( sort keys %{$ref_ms} ) {
	#	print STDERR $key." = ".$ref_ms->{$key}."\n";
	#    }
	#     FlagAccess = 1 | TextError = | DSSpeed = -1 | USSpeed = -1
	}

	####### UserAuth ########### 
	if ( $AP{'login_service'} > 0 or $AP{'trust'} ) {
	    my $Q_UserAuth = "exec UserAuth '".$RAD_REQUEST->{'User-Name'}."', ".$AP{'login_service'};

	    my $sth1 = $dbms->prepare($Q_UserAuth);
	    $sth1->execute;
	    my $ref_ms1 = $sth1->fetchrow_hashref();
	    $sth1->finish;
	#    foreach my $key ( sort keys %{$ref_ms1} ) {
	#	print STDERR $key." = ".$ref_ms1->{$key}."\n";
	#    }
	    # CardNumber = 1 | DSSpeed = -1 | IP1 = 10 | IP2 = 13 | IP3 = 100 | IP4 = 1 | IdTariff = 6 | InetSpeed = 10000 
	    #  NumberPassword = 1 | Quote = 86400 | Status = 1 | TextError = | USSpeed = -1 | TypeConnect | Category

	    if ( $AP{'login_service'} > 0 ) {
		$RAD_REQUEST->{'User-Name'} = $ref_ms1->{'CardNumber'}.".".$ref_ms1->{'NumberPassword'};
		$AP{'trust'} = 1;
	    } elsif ( $AP{'login_service'} == 0 ) {
		$ref_ms1->{'TypeConnect'} = 21 if not defined($ref_ms1->{'TypeConnect'});
		$ref_ms1->{'Category'} = 2 if not defined($ref_ms1->{'Category'});
		$RAD_REPLY->{'Service-Type'} = "Framed-User";
		$RAD_REPLY->{'Framed-Protocol'} = "PPP";

	      if ( not defined($ref_ms1->{'Quote'}) ) {
		    $RAD_REPLY->{'Reply-Message'} = $ref_ms1->{'TextError'} if defined($ref_ms1->{'TextError'});
		    return -1;
	      } elsif ( $ref_ms1->{'Quote'} < 0 ) {
		$RAD_REPLY->{'Session-Timeout'} = $nas_conf->{'FAKE_QUOTE'};
		$RAD_REPLY->{'Cisco-AVPair'} = "ip:dns-servers=".$nas_conf->{'FAKE_DNS'}." ".$nas_conf->{'FAKE_DNS'};
	      } else {
		$RAD_REQUEST->{'User-Name'} = $ref_ms1->{'CardNumber'}.".".$ref_ms1->{'NumberPassword'};
		$RAD_REPLY->{'Framed-IP-Address'} = $ref_ms1->{'IP1'}.".".$ref_ms1->{'IP2'}.".".$ref_ms1->{'IP3'}.".".$ref_ms1->{'IP4'};
		$RAD_REPLY->{'Session-Timeout'} = $ref_ms1->{'Quote'};

		if ( $RAD_REPLY->{'Framed-IP-Address'} =~ /^10\.13\.2[45]\d\.\d+/ ) {
		    $RAD_REPLY->{'Cisco-AVPair'} = "ip:dns-servers=".$nas_conf->{'FAKE_DNS'}." ".$nas_conf->{'FAKE_DNS'};
		} else {
		    $RAD_REPLY->{'Cisco-AVPair'} = "ip:dns-servers=".$nas_conf->{'DNS_IP1'}." ".$nas_conf->{'DNS_IP2'};
		}
		####################### GET ACCESS POINT ####################
		my $Query = ''; my $Q_upd = ''; my $PreQuery = '';
		my $date = strftime "%Y%m%d%H%M%S", localtime(time);
		my $job_parms = ''; $AP{'set'} = 0;

		################### Если выяснили AP_ID ######################
		if ( $AP{'trust'} > 0 and ( not $RAD_REPLY->{'Framed-IP-Address'} =~ /^10\.13\.2[45]\d\.\d{1,3}$/ ) and ( not $ref_ms1->{'Quote'} < 0 )) {
		# CardNumber = 1 | DSSpeed = -1 | IP1 = 10 | IP2 = 13 | IP3 = 100 | IP4 = 1 | IdTariff = 6 | InetSpeed = 10000 
		#  NumberPassword = 1 | Quote = 86400 | Status = 1 | TextError = | USSpeed = -1 | TypeConnect | Category
			#print Dumper %AP if $debug;
			if ( ( $AP{'link_type'} != $ref_ms1->{'TypeConnect'}
			|| ( 'x'.$ref_ms1->{'USSpeed'} ne 'x' and $AP{'us'} != $ref_ms1->{'USSpeed'} )
			|| ( 'x'.$ref_ms1->{'DSSpeed'} ne 'x' and $AP{'ds'} != $ref_ms1->{'DSSpeed'} )
			) and ! $AP{'communal'} ) {
			    $AP{'set'} = 1;
			}
			dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS =>
			"AP_set = '".$AP{'set'}."', AP_DS = '".$ref_ms1->{'DSSpeed'}."', AP_US = '".$ref_ms1->{'USSpeed'}."'" );

			$Query = "INSERT INTO ap_login_info SET login='".$AP{'login'}."', start_date='".$date."', hw_mac='".$AP{'hw_mac'}."',  port_id='".$AP{'id'}."'";
			$Q_upd = " ap_name='".$AP{'name'}."', sw_id='".$AP{'swid'}."', last_date='".$date."', vlan_id='".$AP{'vlan_id'}."'".
			", ip_addr='".$RAD_REPLY->{'Framed-IP-Address'}."'";

			$dbm->do( $Query.",".$Q_upd.", trust=0  ON DUPLICATE KEY UPDATE ".$Q_upd );
			$Q_upd_db->{'Q_ap_login_info'} = $Query.",".$Q_upd.", trust=1 ON DUPLICATE KEY UPDATE ".$Q_upd.", trust=1" ;

			## HEAD_LINK inserting data
			if ( $AP{'trust'} and $ref_ms1->{'TypeConnect'} == $link_type{'pppoe'} ) {
			    if ( $RAD_REPLY->{'Framed-IP-Address'} =~ /^10\./ ) { 
				$AP{'pri'} = $ref_ms1->{'Category'}||3;
			    } else {
				$AP{'pri'} = 3;
			    }
			    $Query = "INSERT INTO head_link SET port_id=".$AP{'id'}.", status=1, white_static_ip=0, dhcp_use=".$nas_conf->{'DHCP_USE'}.", ";
			    $Q_upd = " vlan_id=".$AP{'vlan_id'}.", login='".$AP{'login'}."', hw_mac='".$AP{'hw_mac'}."', communal=".$AP{'communal'}.
			    ", inet_shape=".$ref_ms1->{'InetSpeed'}.", inet_priority=".$AP{'pri'}.", stamp=NULL, ip_subnet='".$RAD_REPLY->{'Framed-IP-Address'}."'".
			    ", head_id=".$headinfo{'LHEAD_'.$AP{'nas_ip'}}.", pppoe_up=1";
			    $Query .= $Q_upd." ON DUPLICATE KEY UPDATE ".$Q_upd;
			    $Q_upd_db->{'Q_head_link'} = $Query ;
			}
			######################## SET JOB PARAMETERS #######################
			if ( $AP{'set'} and $AP{'automanage'} ) {
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "Access Point parm change" );
			    $AP{'update_db'}=1;
			    $Query = "INSERT INTO bundle_jobs SET port_id=".$AP{'id'};
			    $job_parms  = 'login:'.$AP{'login'}.';hw_mac:'.$AP{'mac_src'}.';';
			    $job_parms .= 'inet_rate:'.$ref_ms1->{'InetSpeed'}.';'   if defined($ref_ms1->{'InetSpeed'});
			    $job_parms .= 'ds_speed:'.$ref_ms1->{'DSSpeed'}.';'      if defined($ref_ms1->{'DSSpeed'});
			    $job_parms .= 'us_speed:'.$ref_ms1->{'USSpeed'}.';'      if defined($ref_ms1->{'USSpeed'});

			    ########  VPN  VLAN  ########
			    if ( $ref_ms1->{'TypeConnect'} == $link_type{'l2link'} ) {
				#$Query .= ", ltype_id=".$ref_ms1->{'TypeConnect'};
				if ( "x".$ref_ms1->{'vlan_id'} eq "x" ) {
				    # PORT_ID LINK_TYPE ZONE
				    ( $ref_ms1->{'vlan_id'}, $AP{'head_id'} ) = VLAN_get ( PORT_ID => $AP{'id'}, 
				    LINK_TYPE => $ref_ms1->{'TypeConnect'}, ZONE => $AP{'vlan_zone'} );
				    if ( $ref_ms1->{'vlan_id'} > 1 ) {
					$job_parms .= 'vlan_id:'.$ref_ms1->{'vlan_id'}.';';
				    }
				} else {
				    $job_parms .= 'vlan_id:'.$ref_ms1->{'vlan_id'}.';';
				}
			    }
			    ######## Transport Net ############
			    if ( defined($RAD_REPLY->{'Framed-IP-Address'}) and $ref_ms1->{'TypeConnect'} == $link_type{'l3net4'} ) {
				if ( "x".$ref_ms1->{'vlan_id'} eq "x" ) {
				    $job_parms .= 'ip_subnet:'.(GET_IP3($RAD_REPLY->{'Framed-IP-Address'}.'/30')).'/30;' ;
				    # PORT_ID LINK_TYPE ZONE
				    ( $ref_ms1->{'vlan_id'}, $AP{'head_id'} ) = VLAN_get ( PORT_ID => $AP{'id'}, 
				    LINK_TYPE => $link_type{'l3net4'}, ZONE => $AP{'vlan_zone'} );
				    if ( $ref_ms1->{'vlan_id'} > 1 ) {
					$job_parms .= 'vlan_id:'.$ref_ms1->{'vlan_id'}.';';
				    }
				}
			    }

			    # Проверка изменений link_type
			    ## Если порт был свободен и задействуется под PPPoE
			    if ( $AP{'link_type'} == $link_type{'free'} and $ref_ms1->{'TypeConnect'} == $start_conf->{'CLI_VLAN_LINKTYPE'} ) {
				$Query .= ", ltype_id=".$ref_ms1->{'TypeConnect'};
				$job_parms .= 'vlan_id:'.$AP{'vlan_id'}.';';
			    ## Иначе если порт был свободен и задействуется под другие типы подключений  
			    } elsif ( $AP{'link_type'} == $link_type{'free'} ) {
				$Query .= ", ltype_id=".$ref_ms1->{'TypeConnect'};
				$job_parms .= 'vlan_id:'.$ref_ms1->{'vlan_id'}.';' if ( $ref_ms1->{'vlan_id'} > 1 );
			    ## Иначе если порт занят под такой же тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $ref_ms1->{'TypeConnect'}+0 == $AP{'link_type'}+0 ) {
				$Query .= ", ltype_id=".$link_type{'setparms'};
				$job_parms .= 'vlan_id:'.$AP{'vlan_id'}.';';
			    ## Иначе если порт ЗАНЯТ! и задействуется под другой тип подключения
			    } elsif ( $AP{'link_type'} > $start_conf->{'STARTLINKCONF'} and $ref_ms1->{'TypeConnect'}+0 != $AP{'link_type'}+0  ) {
				$PreQuery .= "INSERT INTO bundle_jobs SET port_id=".$AP{'id'}.", ltype_id=".$link_type{'free'}.' ON DUPLICATE KEY UPDATE date_insert=NULL';

				$Query .= ", ltype_id=".$ref_ms1->{'TypeConnect'};
				$job_parms .= 'vlan_id:'.$ref_ms1->{'vlan_id'}.';' if ( defined($ref_ms1->{'vlan_id'}) and $ref_ms1->{'vlan_id'} > 1 );
			    } else {
				$AP{'update_db'}=0;
			    }

			    if ( $AP{'update_db'} ) {
				if ("x".$PreQuery ne "x" ) {
				    $Q_upd_db->{'Q_pre_bundle_jobs'} = $PreQuery;
				}
				$Query .= ", parm='".$job_parms."', archiv=0 ON DUPLICATE KEY UPDATE date_insert=NULL, parm='".$job_parms."'";
				dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS => "Update port DB parameters info" );
				$Q_upd_db->{'Q_bundle_jobs'} = $Query;
			    } else {
				dlog ( SUB => (caller(0))[3]||'', DBUG => 0, LOGTYPE => 'LOGDISP', 
				MESS => "Error: Different link_types, possible PORT type is FREE?" );
			    }
			}

			if ( not $AP{'trust'} ) {
			    dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "'".$AP{'login'}."' access point not agree !!!" );
			}
			dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGDISP', MESS =>
			"QUERY: Login  = '".$AP{'login'}."', MAC = '".$AP{'hw_mac'}."', NAS_IP = ".$AP{'nas_ip'}."\n".
			" Login = '".$AP{'login'}."', AP_ID = '".$AP{'id'}."', '".$AP{'name'}.", ZONE = ".$AP{'vlan_zone'}.", VLAN = ".$AP{'vlan_id'}."'\n");
		}
	      }
	    }
	}
	return $AP{'trust'};

}

sub PPP_post_auth {
	my $UPD = shift;
	my $RAD_REQUEST = shift;

	DB_mysql_connect(\$dbm);
	if ( defined($UPD->{'Q_ap_login_info'}) )    { $dbm->do($UPD->{'Q_ap_login_info'})
	or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => $UPD->{'Q_ap_login_info'}." \n$DBI::errstr" ); }
	if ( defined($UPD->{'Q_head_link'}) )        { $dbm->do($UPD->{'Q_head_link'})
	or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => $UPD->{'Q_head_link'}." \n$DBI::errstr" ); }
	if ( defined($UPD->{'Q_pre_bundle_jobs'}) )  { $dbm->do($UPD->{'Q_pre_bundle_jobs'})
	or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => $UPD->{'Q_pre_bundle_jobs'}." \n$DBI::errstr" ); }
	if ( defined($UPD->{'Q_bundle_jobs'}) )      { $dbm->do($UPD->{'Q_bundle_jobs'})
	or dlog ( SUB => (caller(0))[3]||'', DBUG => 1, LOGTYPE => 'LOGAPFIX', MESS => $UPD->{'Q_bundle_jobs'}." \n$DBI::errstr" ); }

	#print Dumper $RAD_REQUEST;
	if ( defined($RAD_REQUEST->{'NAS-Identifier'}) and $RAD_REQUEST->{'NAS-Identifier'} eq $nas_conf->{'mail_server'} and
	defined($RAD_REQUEST->{'Cleartext-Password'}) and defined ($RAD_REQUEST->{'User-Password'}) and not defined($RAD_REQUEST->{'Framed-Protocol'}) ) {
	    if ( $RAD_REQUEST->{'Cleartext-Password'} ne $RAD_REQUEST->{'User-Password'} ) {
		return -1;
	    }
	} elsif ( defined($RAD_REQUEST->{'Cleartext-Password'}) and defined ($RAD_REQUEST->{'User-Password'}) and defined($RAD_REQUEST->{'Framed-Protocol'}) ) {
		return -1;
	}
	return 1;
}


sub DHCP_post_auth {
	my $RAD_REQUEST = shift;
	my $RAD_REPLY = shift;
	use constant	RLM_MODULE_OK=>        2;#  /* the module is OK, continue */
	use constant	RLM_MODULE_NOTFOUND=>  6;#  /* user not found */

	my $res = RLM_MODULE_NOTFOUND; my $rows_up = -1; my $cli_addr = ''; my $ap_id = ''; my %acc_attr = (); my $new_session = 0;

	DB_mysql_connect(\$dbm);

	#DHCP-Relay-Agent-Information = 0x0106000405dc0303020b010931302e33322e302e31
	my $vlan=oct('0x'.substr($RAD_REQUEST->{'DHCP-Relay-Agent-Information'},10,4)) if defined($RAD_REQUEST->{'DHCP-Relay-Agent-Information'});
	&radiusd::radlog(1, "New ".$RAD_REQUEST->{'DHCP-Message-Type'}." VLAN = $vlan, MAC = ".$RAD_REQUEST->{'DHCP-Client-Hardware-Address'} );

	my %AP = (
		'callsub'	=> 'DHCP2RADIUS',
		'vlan_id'	=> $vlan,
		'hw_mac'	=> $RAD_REQUEST->{'DHCP-Client-Hardware-Address'},
		'id'		=> 0,
		'new_lease'	=> 0,
	);


	if ( $RAD_REQUEST->{'DHCP-Message-Type'} eq 'DHCP-Release' ) {
		my $Q_Request = "SELECT a.session, a.port_id, UNIX_TIMESTAMP(a.start_lease) as start_lease, l.login  FROM dhcp_addr a, head_link l WHERE l.login=a.login and l.hw_mac=a.hw_mac".
		" and a.ip='".$RAD_REQUEST->{'DHCP-Client-IP-Address'}."' and a.agent_info='".$RAD_REQUEST->{'DHCP-Relay-Agent-Information'}."'".
		" and a.hw_mac='".$RAD_REQUEST->{'DHCP-Client-Hardware-Address'}."'";
		#&radiusd::radlog(1, $Q_Request) if $debug;

		my $stm_rel = $dbm->prepare($Q_Request);
		$stm_rel->execute();
		#&radiusd::radlog(1, "stm_req exec SET Reply data rows - ".$stm_req->rows);
		if  ( $stm_rel->rows == 1 ) {
		    my $ref_rel = $stm_rel->fetchrow_hashref;
		    #################################################
		    $dbm->do("UPDATE dhcp_addr SET end_lease=now() WHERE ip='".$RAD_REQUEST->{'DHCP-Client-IP-Address'}.
		    "' and hw_mac='".$RAD_REQUEST->{'DHCP-Client-Hardware-Address'}."' and agent_info='".$RAD_REQUEST->{'DHCP-Relay-Agent-Information'}."'".
		    " and login=".$ref_rel->{'login'} );
		    $res = RLM_MODULE_OK;
		    if ($nas_conf->{'DHCP_ACCOUNT'}) {
			################## ACCOUNTING ###################
			%acc_attr = (
			    'Acct-Status-Type'              => 'Stop',
			    'Acct-Delay-Time'               => 0,
			    'NAS-IP-Address'                => $nas_conf->{'DHCP_NAS_IP'},
			    'Acct-Authentic'                => 'RADIUS',
			    'NAS-Port-Type'                 => 'Virtual',
			    'Service-Type'                  => 'Framed-User',
			    'User-Name'                     => $nas_conf->{'DHCP_ACC_USERPREF'}.$ref_rel->{'login'},
			    'NAS-Port'                      => $vlan,
			    'NAS-Port-Id'                   => $ref_rel->{'port_id'},
			    'Acct-Session-Id'               => $ref_rel->{'session'},
			    'Framed-IP-Address'             => $RAD_REQUEST->{'DHCP-Client-IP-Address'},
			    'Acct-Terminate-Cause'          => 'User-Request',
			    'Acct-Session-Time'             => ( time - $ref_rel->{'start_lease'}),
			    'Request-Number'                => $RAD_REQUEST->{'DHCP-Transaction-Id'},
			    #'DHCP-Hardware-Type'            => $RAD_REQUEST->{'DHCP-Hardware-Type'},
			    #'DHCP-Client-Hardware-Address'  => $RAD_REQUEST->{'DHCP-Client-Hardware-Address'},
			    #'DHCP-Relay-Agent-Information'  => $RAD_REQUEST->{'DHCP-Relay-Agent-Information'},
			);
			send_accounting (\%acc_attr);
		    }
		}
		$stm_rel->finish;

	} elsif  ( $RAD_REQUEST->{'DHCP-Message-Type'} eq 'DHCP-Discover' ) {
	    ## Выясняем предварительное разрешение использования IP-Unnumbered подключения по данным DHCP-Relay-Agent-Information и типу абонента
	    my $Q_check_macport = "SELECT l.port_id, l.head_id, l.white_static_ip, l.status, l.login, l.dhcp_use, h.term_ip, l.pppoe_up ".
	    " FROM head_link l, heads h WHERE l.head_id=h.head_id and l.inet_priority<=".$nas_conf->{'DHCP_PRI'}." and l.communal=0 ".
	    " and ( h.dhcp_relay_ip='".$RAD_REQUEST->{'DHCP-Gateway-IP-Address'}."' or h.dhcp_relay_ip2='".$RAD_REQUEST->{'DHCP-Gateway-IP-Address'}."' )".
	    " and l.status=1 and l.hw_mac='".$RAD_REQUEST->{'DHCP-Client-Hardware-Address'}."' and l.vlan_id=".$vlan;
	    my $stm_port = $dbm->prepare($Q_check_macport);
	    $stm_port->execute();
	    if  ( $stm_port->rows == 1 ) {
		while (my $ref_port = $stm_port->fetchrow_hashref()) {
		  ######  Выясняем точку доступа ######
		  $AP{'trust_id'}	= $ref_port->{'port_id'};
		  $AP{'nas_ip'}		= $ref_port->{'term_ip'};
		  $AP{'login'}		= $ref_port->{'login'};
		  #SW_AP_fix( AP_INFO => \%AP, NAS_IP => $ref_port->{'term_ip'}, LOGIN => $ref_port->{'login'}, VLAN => $AP{'vlan'}, HW_MAC => $AP{'hw_mac'} );
		  SW_AP_fix( \%AP );
		  if ( $AP{'id'} == $ref_port->{'port_id'} ) {
		    &radiusd::radlog(1, "Verify trusted AP_id ".$AP{'id'}." PASS!\n") if $debug;
		    if ((not $ref_port->{'dhcp_use'}) || ($ref_port->{'pppoe_up'} and $nas_conf->{'CHECK_PPPOE_UP'} )) {
			$RAD_REPLY->{'DHCP-Message-Type'} = 0;
 			return RLM_MODULE_NOTFOUND;
		    }
		    # Выделить IP
		    my $Q_Discover_start  = "SELECT a.login, a.ip, UNIX_TIMESTAMP(a.start_lease) as start_lease, a.end_lease, p.mask, p.gw, p.dhcp_lease, p.name_server FROM dhcp_addr a, dhcp_pools p ".
		    " WHERE p.head_id=".$ref_port->{'head_id'}." and p.pool_id=a.pool_id";

		    my $Q_Discover_reuse = ""; my $Q_Discover_new ='' ; my $Q_Discover_grey ='' ;
		    my $Q_window = " (UNIX_TIMESTAMP(a.end_lease)+".$nas_conf->{'DHCP_WINDOW'}.")<UNIX_TIMESTAMP(now())";
		    ### Поиск назначенного статического белого IP
		    if ( $ref_port->{'white_static_ip'} == 1 and $ref_port->{'status'} == 1 ) {
			$Q_Discover_reuse = " and p.pool_type=1 and a.login='".$ref_port->{'login'}."'";
			$Q_Discover_new   = " and p.pool_type=0 and ".$Q_window;
		    ### Поиск ранее выдаваемого динамического белого IP
		    } elsif ( $ref_port->{'white_static_ip'} < 1 and $ref_port->{'status'} == 1 ) {
			$Q_Discover_reuse = " and p.pool_type=".$nas_conf->{'DHCP_POOLTYPE'}." and a.login='".$ref_port->{'login'}."'";
			$Q_Discover_new   = " and p.pool_type=".$nas_conf->{'DHCP_POOLTYPE'}." and ".$Q_window;
			$Q_Discover_grey  = " and p.pool_type=3 and ( a.login='".$ref_port->{'login'}."' or ".$Q_window." )";
		    ### Поиск ранее выдаваемого серого IP ( линк заблокирован в билинге )
		    } elsif ( $ref_port->{'status'} == 2 ) {
			$Q_Discover_reuse = " and p.pool_type=0 and a.login='".$ref_port->{'login'}."'";
			$Q_Discover_new   = " and p.pool_type=0 and ".$Q_window;
		    } else {
			$RAD_REPLY->{'DHCP-Message-Type'} = 0;
			return RLM_MODULE_NOTFOUND;
		    }
		    $Q_Discover_reuse	.= " order by a.end_lease desc limit 1";
		    $Q_Discover_new	.= " order by a.end_lease limit 1";
		    $Q_Discover_grey	.= " order by a.end_lease limit 1";
		    #&radiusd::radlog(1, "Discover_start = ".$Q_Discover_start.$Q_Discover_reuse."\n") if $debug;

		    my $stm_disc = $dbm->prepare($Q_Discover_start.$Q_Discover_reuse);
		    $stm_disc->execute();
		    if  ( not $stm_disc->rows ) {
			$AP{'new_lease'}=1;
			#&radiusd::radlog(1, "Discover_new   = ".$Q_Discover_start.$Q_Discover_new."\n") if $debug;
			$stm_disc->finish;
			$stm_disc = $dbm->prepare($Q_Discover_start.$Q_Discover_new);
			$stm_disc->execute();
			if  ( not $stm_disc->rows and $ref_port->{'white_static_ip'} < 1 and $ref_port->{'status'} == 1 ) {
			    $stm_disc->finish;
			    $stm_disc = $dbm->prepare($Q_Discover_start.$Q_Discover_grey);
			    $stm_disc->execute();
			}
			if  (not $stm_disc->rows ) {
			    &radiusd::radlog(1, 'All IP used in available DHCP pools... :-(, Need increase pools?');
			    $RAD_REPLY->{'DHCP-Message-Type'} = 0;
			    return RLM_MODULE_NOTFOUND;
			}
		    }

		    while (my $ref_disc = $stm_disc->fetchrow_hashref()) {
			if  ( $AP{'new_lease'} and $ref_port->{'status'} == 1 and $ref_disc->{'login'} ) {
			    $Q_Discover_new = "INSERT INTO dhcp_addr_arch ( ip, login, hw_mac, start_use, end_use, port_id, agent_info )".
			    " SELECT ip, login, hw_mac, start_use, end_lease, port_id, agent_info FROM dhcp_addr WHERE ip='".$ref_disc->{'ip'}."'";
			    &radiusd::radlog(1, " Archive prev login = ".$Q_Discover_new) if $debug;
			    $dbm->do($Q_Discover_new);
			}
			$RAD_REPLY->{'DHCP-IP-Address-Lease-Time'} = $ref_disc->{'dhcp_lease'};
			$RAD_REPLY->{'DHCP-Your-IP-Address'}	 = $ref_disc->{'ip'};
			$RAD_REPLY->{'DHCP-Subnet-Mask'}		 = $ref_disc->{'mask'};
			$RAD_REPLY->{'DHCP-Domain-Name-Server'}    = $ref_disc->{'name_server'};
			if ( defined($ref_disc->{'gw'}) ) {
			    $RAD_REPLY->{'DHCP-Router-Address'}    = $ref_disc->{'gw'};
			}
			my $Q_Disc_up = "UPDATE dhcp_addr SET agent_info='".$RAD_REQUEST->{'DHCP-Relay-Agent-Information'}."', login='".$ref_port->{'login'}."'".
			", port_id=".$ref_port->{'port_id'}.", vlan_id=".$vlan.", hw_mac='".$RAD_REQUEST->{'DHCP-Client-Hardware-Address'}."', start_lease=now() ".
			( $AP{'new_lease'} ? ", start_use=now()" : "" ).", end_lease=ADDDATE(now(), INTERVAL ".$ref_disc->{'dhcp_lease'}." SECOND)".
			", dhcp_vendor='".$RAD_REQUEST->{'DHCP-Vendor-Class-Identifier'}."' WHERE ip='".$ref_disc->{'ip'}."'";
			$rows_up = $dbm->do($Q_Disc_up);
			$res = RLM_MODULE_OK if $rows_up == 1;
		    }
		    if  (not $stm_disc->rows ) { &radiusd::radlog(1, 'All IP used in available DHCP scopes... :-('); }
		    $stm_disc->finish;
		  } else {
		    &radiusd::radlog(1, "AP for MAC = ".$AP{'hw_mac'}." and VLAN = ".$AP{'vlan'}." not fixed :-( ...\n") if $debug;
		    $RAD_REPLY->{'DHCP-Message-Type'} = 0;
		    $res = RLM_MODULE_NOTFOUND;
		  }
		}
	    } else {
		    $RAD_REPLY->{'DHCP-Message-Type'} = 0;
		    $res = RLM_MODULE_NOTFOUND;
	    }
	    $stm_port->finish;

	} elsif ( $RAD_REQUEST->{'DHCP-Message-Type'} eq 'DHCP-Request' ) {
		if ($RAD_REQUEST->{'DHCP-Client-IP-Address'} eq '0.0.0.0' ) {
		    $cli_addr = $RAD_REQUEST->{'DHCP-Requested-IP-Address'};
		    $new_session = 1;
		} else {
		    $cli_addr = $RAD_REQUEST->{'DHCP-Client-IP-Address'};
		}
		&radiusd::radlog(1, "CLI_IP = '".$cli_addr."'") if $debug;
		&radiusd::radlog(1, "ID_session ='".$RAD_REQUEST->{'DHCP-Transaction-Id'}."'") if $debug;

		my $Q_Request = "SELECT a.session, a.ip, a.port_id, UNIX_TIMESTAMP(a.start_lease) as start_lease, p.mask, p.gw, p.dhcp_lease, p.name_server, p.pool_type, l.white_static_ip".
		", l.login, h.term_ip FROM dhcp_addr a, dhcp_pools p, head_link l, heads h WHERE l.head_id=h.head_id and l.login=a.login and l.hw_mac=a.hw_mac".
		" and a.port_id=l.port_id and a.pool_id=p.pool_id  and l.status=1 and l.inet_priority<=".$nas_conf->{'DHCP_PRI'}.
		" and l.communal=0"." and ( h.dhcp_relay_ip='".$RAD_REQUEST->{'DHCP-Gateway-IP-Address'}."'".
		" or h.dhcp_relay_ip2='".$RAD_REQUEST->{'DHCP-Gateway-IP-Address'}."' )".
		" and l.dhcp_use=1 and a.ip='".$cli_addr."' and a.agent_info='".$RAD_REQUEST->{'DHCP-Relay-Agent-Information'}."'".
		" and a.hw_mac='".$RAD_REQUEST->{'DHCP-Client-Hardware-Address'}."'";
		#&radiusd::radlog(1, $Q_Request) if $debug;

		my $stm_req = $dbm->prepare($Q_Request);
		$stm_req->execute();
		#&radiusd::radlog(1, "stm_req exec SET Reply data rows - ".$stm_req->rows);
		if  ( $stm_req->rows == 1 ) {
		    while (my $ref_req = $stm_req->fetchrow_hashref()) {
			if ( ( $ref_req->{'white_static_ip'} and $ref_req->{'pool_type'} != 1 ) ||
			   ( (not $ref_req->{'white_static_ip'}) and $ref_req->{'pool_type'} == 1 ) ) {
			    $RAD_REPLY->{'DHCP-Message-Type'} = 'DHCP-NAK';
			    return RLM_MODULE_NOTFOUND;
			}
			if ( ( not defined ($ref_req->{'session'}) ) || ($ref_req->{'session'} ne $RAD_REQUEST->{'DHCP-Transaction-Id'}) ) {
			    $AP{'trust_id'}	= $ref_req->{'port_id'};
			    $AP{'nas_ip'}	= $ref_req->{'term_ip'};
			    $AP{'login'}	= $ref_req->{'login'};
			    SW_AP_fix( \%AP );
			    if ( $AP{'id'} != $ref_req->{'port_id'} ) {
				$RAD_REPLY->{'DHCP-Message-Type'} = 'DHCP-NAK';
				return RLM_MODULE_NOTFOUND;
			    } else {
				&radiusd::radlog(1, "Verify trusted AP_id ".$AP{'id'}." PASS!\n") if $debug;
			    }
			}
			#&radiusd::radlog(1, "SET Reply data");
			$RAD_REPLY->{'DHCP-IP-Address-Lease-Time'} = $ref_req->{'dhcp_lease'};
			$RAD_REPLY->{'DHCP-Your-IP-Address'}	 = $ref_req->{'ip'};
			$RAD_REPLY->{'DHCP-Subnet-Mask'}		 = $ref_req->{'mask'};
			$RAD_REPLY->{'DHCP-Domain-Name-Server'}    = $ref_req->{'name_server'};
			if ( defined($ref_req->{'gw'}) ) {
			    $RAD_REPLY->{'DHCP-Router-Address'}    = $ref_req->{'gw'};
			}

			my $Q_Request_up =  "UPDATE dhcp_addr SET end_lease=ADDDATE(now(), INTERVAL ".$ref_req->{'dhcp_lease'}.
			" SECOND ), session='".$RAD_REQUEST->{'DHCP-Transaction-Id'}."', dhcp_vendor='".$RAD_REQUEST->{'DHCP-Vendor-Class-Identifier'}."'".
			" WHERE agent_info='".$RAD_REQUEST->{'DHCP-Relay-Agent-Information'}.
			"' and hw_mac='".$RAD_REQUEST->{'DHCP-Client-Hardware-Address'}."'".
			" and ip='".$cli_addr."'";
			$rows_up = $dbm->do($Q_Request_up);

			if ($rows_up > 0) {
			    $res = RLM_MODULE_OK;
			    $RAD_REPLY->{'DHCP-Message-Type'} = 'DHCP-Ack';
			    &radiusd::radlog(1, "UPDATE ".$rows_up." rows in Request");
			    ################## ACCOUNTING ###################
			     if ($nas_conf->{'DHCP_ACCOUNT'}) {
				%acc_attr = (
				    'NAS-IP-Address'                => $nas_conf->{'DHCP_NAS_IP'},
				    'User-Name'                     => $nas_conf->{'DHCP_ACC_USERPREF'}.$ref_req->{'login'},
				    'Framed-IP-Address'             => $cli_addr,
				    'NAS-Port'                      => $vlan,
				    'NAS-Port-Id'                   => $ref_req->{'port_id'},
				    'Acct-Delay-Time'               => 0,
				    'Acct-Authentic'                => 'RADIUS',
				    'NAS-Port-Type'                 => 'Virtual',
				    'Service-Type'                  => 'Framed-User',
				    'Acct-Session-Id'               => $ref_req->{'session'},
				    #'DHCP-Client-Hardware-Address'  => $RAD_REQUEST->{'DHCP-Client-Hardware-Address'},
				    #'DHCP-Hardware-Type'            => $RAD_REQUEST->{'DHCP-Hardware-Type'},
				    #'DHCP-Relay-Agent-Information'  => $RAD_REQUEST->{'DHCP-Relay-Agent-Information'},
				);
				if ($new_session) { 
				    $acc_attr{'Acct-Status-Type'} = 'Start';
				} else {
				    $acc_attr{'Acct-Status-Type'} = 'Interim-Update';
				    $acc_attr{'Acct-Session-Time'} = ( time - $ref_req->{'start_lease'});
				    $acc_attr{'Request-Number'} = $RAD_REQUEST->{'DHCP-Transaction-Id'};
				}	
				#print Dumper %acc_attr;
				send_accounting (\%acc_attr);
			    }
			    #################################################
			} else {
			    $RAD_REPLY->{'DHCP-Message-Type'} = 'DHCP-NAK';
			    $res = RLM_MODULE_NOTFOUND;
			}
		    }
		} else {
		    $RAD_REPLY->{'DHCP-Message-Type'} = 'DHCP-NAK';
		    $res = RLM_MODULE_NOTFOUND;
		}
		
		$stm_req->finish;
	} else {
	    $res = RLM_MODULE_OK;
	}
	return $res;
}

sub send_accounting  {
    my $attr = shift;
    my ( $res, $err, $strerr );
    my $r = new Authen::Radius(Host => $nas_conf->{'DHCP_ACC_HOST'}.":".$nas_conf->{'DHCP_ACC_PORT'}, Secret => $nas_conf->{'DHCP_ACC_SECRET'}, Debug => 0);
    #print Dumper $attr;
    $r->add_attributes ( map {  { Name => $_,  Value =>  $attr->{$_} } } keys %$attr );
    $r->send_packet(ACCOUNTING_REQUEST);
}


1;
