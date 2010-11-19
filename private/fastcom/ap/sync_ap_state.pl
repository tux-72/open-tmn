#!/usr/bin/perl -w


use strict;
use POSIX qw(strftime);
use DBI();
use Data::Dumper;
my $ver = "0.4";

my $debug=0;
$debug=1;

$ENV{'NLS_LANG'}='RUSSIAN_AMERICA.AL32UTF8';
my $ipcalc ='/usr/bin/ipcalc';
my $max_inet_speed = 10000;

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );

if (not defined($ARGV[0]) or $ARGV[0] ne 'sync' ) {
	print STDERR "Usage: $script_name sync\n";
	exit;
};


my %conf = (
	'MYSQL_host'	=> '192.168.29.20',
	'MYSQL_base'	=> 'vlancontrol',
	'MYSQL_user'	=> 'datasync',
	'MYSQL_pass'	=> 'password',

	'ORA_host'	=> 'fst',
	'ORA_port'	=> '1521',
	'ORA_sid'	=> 'fst10',
	'ORA_usn'	=> 'usn_user',
	'ORA_psw'	=> 'password',
);

### MYSQL Connect
my $dbm = DBI->connect("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'}) or die("connect");
$dbm->do("SET NAMES 'koi8r'");
### ORACLE Connect
my $dbh=DBI->connect("dbi:Oracle:host=".$conf{'ORA_host'}.";sid=".$conf{'ORA_sid'}.";port=".$conf{'ORA_port'},$conf{'ORA_usn'},$conf{'ORA_psw'},{PrintError=>0,AutoCommit=>0,RaiseError=>1});

my %AP = ();
my %ORA = ();
my %AP_id = ();

my %TR = ();
my %TRANSP = ();
my %ORA_TR = ();

# SERVICE - work
# ATTACH - must be work
# BLOCK - blocked access
# CANCEL - deactivate point
my %ora_srv = (
    'SERVICE'	=>	1,
    'ATTACH'	=>	1,
    'BLOCK'	=>	2,
    'CANCEL'	=>	3,
);

my %ora_srv_rev = (
    '1'	=>	'SERVICE',
    '2'	=>	'BLOCK',
    '3'	=>	'CANCEL',
);

my $stm = $dbm->prepare("SELECT l.ip_subnet, l.port_id, l.login, l.status, l.hw_mac, l.inet_shape, l.dhcp_use, p.ltype_id, \
p.communal, p.us_speed, p.ds_speed FROM head_link l, swports p WHERE l.port_id=p.port_id");

$stm->execute();
while (my $refm = $stm->fetchrow_hashref()) {
    $AP{$refm->{'port_id'}} =
    {	login      => $refm->{'login'},
	status     => $refm->{'status'},
	hw_mac     => $refm->{'hw_mac'},
	ltype_id   => $refm->{'ltype_id'},
	communal   => $refm->{'communal'},
	us_speed   => $refm->{'us_speed'},
	ds_speed   => $refm->{'ds_speed'},
	inet_shape => $refm->{'inet_shape'},
	dhcp_use   => $refm->{'dhcp_use'},
    };

    if (defined($refm->{'ip_subnet'}) and $refm->{'ip_subnet'} =~ /^77\.239\.21[01]\.\d{1,3}\/30$/) {
	$refm->{'ip_subnet'} = GET_IP3SUB($refm->{'ip_subnet'});
	$TRANSP{$refm->{'ip_subnet'}} = $refm->{'status'};
	$TR{$refm->{'ip_subnet'}} = 
	{	inet_shape => $refm->{'inet_shape'},
	    login => $refm->{'login'},
	    status => $refm->{'status'},
	};
    }
}
$stm->finish;

#        'PPPOE_JL'   'DENY'   'SERVICE' '3918'  'rosa'    '21'      '10000'      '100000'   '100000'   '... communal:0'
my ($ip, $ltype_name, $state,  $service,  $ap_id, $login, $dhcp_use, $ltype_id, $inet_shape, $us_speed, $ds_speed, $props);

my $sth = $dbh->prepare("select ob.objecttype_code, ep.state, ob.process, ep.entry_point, ob.identifer, decode(cto.tarifplane_code, \
'EXACT', 'N', 'Y') dhcp_use, decode(ob.objecttype_code, 'PPPOE', 21, 'PPPOE_JL', 21, 'VLAN', 22, 'IP_UNNUM', 23, 'LLINE', 24, null) \
link_type, ct_p_srvpar_control.get_parvalue4date4outer(ob.id, 'DL_ABON', 'RATE') rate,ct_p_srvpar_control.get_parvalue4date4outer(ob.id, \
'DL_ABON', 'RATE_PORT_US') rate_port_us, ct_p_srvpar_control.get_parvalue4date4outer(ob.id, 'DL_ABON', 'RATE_PORT_DS') rate_port_ds, \
ep.props from it_t_entry_point ep, ct_t_object ob, ct_t_tarcontobj cto where ep.controbj_id=ob.id and ob.id=cto.controbj_id and \
cto.hist_to>sysdate order by  ep.state, ob.process, ob.objecttype_code, ep.entry_point, ob.identifer") || die $dbh->errstr;

$sth->execute();
while (($ltype_name, $state, $service,  $ap_id, $login, $dhcp_use, $ltype_id, $inet_shape, $us_speed, $ds_speed, $props )=$sth->fetchrow_array) {
    if ( ( defined($props) and $props =~ /communal\:1/ ) or ( defined($login) and $login =~ /^comtest\d+$/) ) {
	next;
    }
    if ( defined($ORA{$ap_id}) and $state eq 'ALLOW' ) { 
	print " AP ".$ap_id." (".$login.") in current state '".$state."', service '".$service."' =>  Already exist (".
	$ORA{$ap_id}{'login'}.") for state '".$ORA{$ap_id}{'state'}."', service '".$ora_srv_rev{$ORA{$ap_id}{'service'}}."'\n";
    }
    if ( ( not defined($ORA{$ap_id})) or ($ORA{$ap_id}{'state'} eq 'DENY') ) {
	$ORA{$ap_id} =
	{	login		=> $login,
		state		=> $state,
		service		=> $ora_srv{$service},
		ltype_id	=> $ltype_id,
		inet_shape	=> $inet_shape,
		us_speed	=> $us_speed,
		ds_speed	=> $ds_speed,
		dhcp_use	=> $dhcp_use,
	};
	$AP_id{$login} = $ap_id;
    }
    if (  $ltype_id == 24 and $debug > 1 ) { 
	print STDERR " AP ".$ap_id.", login '".$login."', state '".$state."', service '".$service."', type '".$ltype_id."', shape '".$inet_shape."'\n";
    }

    if ( defined($AP{$ap_id}{'login'}) ) {
	my $Q_up = '';
	if ( ($ORA{$ap_id}{'state'} eq 'DENY' or $ORA{$ap_id}{'service'} == 3 ) and $ltype_id != 24 ) {
	    $Q_up = "DELETE from head_link WHERE port_id=".$ap_id." and login='".$AP{$ap_id}{'login'}."'";
	} elsif ($ORA{$ap_id}{'state'} eq 'ALLOW' ) {
	    if ($ORA{$ap_id}{'service'} != $AP{$ap_id}{'status'} ) {
		if ($ORA{$ap_id}{'ltype_id'} == 24 ) {
		    $Q_up .= " set_status=".$ORA{$ap_id}{'service'}.","; 
		} else {
		    $Q_up .= " status=".$ORA{$ap_id}{'service'}.","; 
		}
	    }
	    if ($ORA{$ap_id}{'inet_shape'} != $AP{$ap_id}{'inet_shape'} ) {
		    $Q_up .= " inet_shape=".$ORA{$ap_id}{'inet_shape'}.",";
	    }
	    if ($ORA{$ap_id}{'login'} ne $AP{$ap_id}{'login'} ) {
		    $Q_up .= " login='".$ORA{$ap_id}{'login'}."',";
	    }
	    if ($ORA{$ap_id}{'dhcp_use'} eq "N" and $AP{$ap_id}{'dhcp_use'} ) {
		    #print STDERR $ORA{$ap_id}{'login'}." blocked dhcp\n";
		    $Q_up .= " dhcp_use=0,";
	    }
	    #if ($ORA{$ap_id}{'us_speed'} != $AP{$ap_id}{'us_speed'} ) {
	    #    $Q_up .= " us_speed=".$ORA{$ap_id}{'us_speed'}.","; 
	    #}
	    #if ($ORA{$ap_id}{'ds_speed'} != $AP{$ap_id}{'ds_speed'} ) {
	    #    $Q_up .= " ds_speed=".$ORA{$ap_id}{'ds_speed'}.","; 
	    #}
	    if ( $Q_up ) {
		$Q_up =~ s|, *$||;
		$Q_up = 'UPDATE head_link set '.$Q_up.' WHERE port_id='.$ap_id;
	    }
	}
	if ( $Q_up ) {
	    print STDERR $Q_up."\n" if $debug > 1;
	    $dbm->do($Q_up) if not $debug;
	}
    }
}
$sth->finish;

###############################################################
##################### TRANSPORT NETWORKS #######################
###############################################################
# 'alferov' '10.13.69.210' '512' 'RATE'

my $Q_speed = "select ct.username, ct.ip_addr_to, op.value*decode(op.unitskind_code, 'МБИТ/СЕК', 1000, 'КБИТ/СЕК', 1, 'МБ', \
1000, null), op.paramkind_code from ct_t_ident_param_hist ct inner join ct_t_objsrv_par_hist op on ct.controbj_id=op.controbj_id \
WHERE sysdate between ct.hist_from and ct.hist_to and op.status = 'ACTIVE' and ct.first_ip_address is not NULL";

my $sth1 = $dbh->prepare($Q_speed) || die $dbh->errstr;
$sth1->execute();

#while ( my $s = $sth1->fetchrow_hashref ) {
#    print Dumper \$s;
#}

while ( ( $login, $ip, $inet_shape, $props ) = $sth1->fetchrow_array ) {

	if ( $ip =~ /^77\.239\.21[01]\.\d{1,3}$/ and defined ($props) and $props eq 'RATE' ) {
	#'vika08' '77.239.210.215' '10000' 'RATE'
	#'vika08' '77.239.210.215' '10000' 'RATE_PORT_DS'
	#'vika08' '77.239.210.215' '10000' 'RATE_PORT_US'

	    $ip = GET_IP3SUB($ip);
	    $ORA_TR{$ip} = $login;
	    if ( $inet_shape > $max_inet_speed ) { $inet_shape = $max_inet_speed; }
	    #print STDERR  "IP = '".$ip."', login = '".$login."', shape = '".$inet_shape."', cur_shape ='".$TR{$ip}{'inet_shape'}."'\n" if $debug;
	} else {
	    next;
	}

	my $Q_up = '';
	my $Q_upd = '';
	if (( defined($inet_shape) and (not defined($TR{$ip}{'inet_shape'})) || ( $TR{$ip}{'inet_shape'}+0 != $inet_shape+0 ))) {
	    $Q_up .= " inet_shape=".$inet_shape.",";
	}
	if ((! defined($TR{$ip}{'login'})) || ( $TR{$ip}{'login'} ne $login )) {
	    #print STDERR  "IP = ".$ip." ".($TR{$ip}{'login'}||"''").' != '.$login."\n" if $debug;
	    $Q_up .= " login='".$login."',";
	}
	if ( $Q_up and defined($AP_id{$login}) and $ORA{$AP_id{$login}}{'state'} eq 'ALLOW' ) {
	    $Q_up =~ s|, *$||;
	    if ( $TR{$ip}{'status'} ) {
		$Q_upd = "UPDATE head_link SET ".$Q_up." WHERE ip_subnet='".$ip."'";
	    } elsif ( defined($AP_id{$login}) and $ORA{$AP_id{$login}}{'service'} < 3 ) {
		if ( defined($AP{$AP_id{$login}}) ) {
		    $Q_upd = "UPDATE head_link SET ".$Q_up." WHERE port_id=".$AP_id{$login};
		#" ON DUPLICATE KEY UPDATE ".$Q_up;
		} else {
		    $Q_upd = "INSERT INTO head_link SET status=2, inet_priority=2, head_id=4, port_id=".$AP_id{$login}.", ".$Q_up;
		}
	    }
	}
	
	if ( $Q_upd ) {
	    print $Q_upd."\n" if $debug;
	    if ( ! $debug ) { $dbm->do($Q_upd); }
	}
}

$sth1->finish;

foreach my $subnet ( sort keys %TRANSP ) {
    my $Q_up = '';
    if ( not defined($ORA_TR{$subnet}) ) {
	$Q_up = "UPDATE head_link SET set_status=2 WHERE ip_subnet='".$subnet."'" if ($TRANSP{$subnet} == 1);
    }
    if ( $Q_up ) {
	print $Q_up."\n" if $debug;
	$dbm->do($Q_up) if not $debug;
    }
}

$dbm->disconnect; # MYSQL
$dbh->disconnect; # ORACLE


sub GET_IP3SUB {
    my $subip3 = shift;
    if ( $subip3 =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) { 
        $subip3 .= "/30"; 
    }
    my @ln = `$ipcalc $subip3`;
    foreach (@ln) {
        if ( /HostMax\:\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+/ ) {
            $subip3 = $1;
        }
    }
    return $subip3."/30";
}
