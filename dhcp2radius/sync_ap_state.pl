#!/usr/bin/perl -w

use POSIX qw(strftime);
use DBI();

my $debug=1;
my $ver = "0.1";

#use FindBin '$Bin';

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
#dlog ( SUB => $script_name, DBUG => 1, MESS => "Use BIN directory - $Bin" );

if (not defined($ARGV[0]) or $ARGV[0] ne 'sync' ) {
	print STDERR "Usage: $script_name sync\n";
	exit;
};

my %conf = (
	'MYSQL_host'	=> '192.168.29.20',
	'MYSQL_base'	=> 'vlancontrol',
	'MYSQL_user'	=> 'datasync',
	'MYSQL_pass'	=> 'Dyrikwas1',

	'ORA_host'	=> 'fst',
	'ORA_port'	=> '1521',
	'ORA_sid'	=> 'fst10',
	'ORA_usn'	=> 'fastcom',
	'ORA_psw'	=> 'fastcom',
);

### MYSQL Connect
my $dbm = DBI->connect("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'}) or die("connect");
$dbm->do("SET NAMES 'koi8r'");
### ORACLE Connect
my $dbh=DBI->connect("dbi:Oracle:host=".$conf{'ORA_host'}.";sid=".$conf{'ORA_sid'}.";port=".$conf{'ORA_port'},$conf{'ORA_usn'},$conf{'ORA_psw'},{PrintError=>0,AutoCommit=>0,RaiseError=>1});

my %AP = ();
my %ORA = ();

# SERVICE - Working login
# ATTACH -  New working login
# BLOCK -   Blocked login
# CANCEL -  release login

my %ora_srv = (
    'SERVICE'	=>	1,
    'ATTACH'	=>	1,
    'BLOCK'	=>	2,
    'CANCEL'	=>	3,
);

my $stm = $dbm->prepare("SELECT l.port_id, l.login, l.status, l.hw_mac, l.inet_shape, p.ltype_id, p.communal, p.us_speed, p.ds_speed FROM head_link l, swports p WHERE l.port_id=p.port_id");
$stm->execute();
while (my $refm = $stm->fetchrow_hashref()) {
    $AP{$refm->{'port_id'}} =
    {	login => $refm->{'login'},
	status => $refm->{'status'},
	hw_mac => $refm->{'hw_mac'},
	inet_shape => $refm->{'inet_shape'},
	ltype_id => $refm->{'ltype_id'},
	communal => $refm->{'communal'},
	us_speed => $refm->{'us_speed'},
	ds_speed => $refm->{'ds_speed'},
    };
#    print STDERR $refm->{'port_id'}." --> ".$AP{$refm->{'port_id'}}{'login'}."\n";
}
$stm->finish;

#__END__

#    'PPPOE_JL'   'DENY' 'SERVICE' '3918'  'rosa'    '21'      '10000'      '100000'   '100000'    '... communal:0'
my ($ltype_name, $state,  $service,  $ap_id, $login, $ltype_id, $inet_shape, $us_speed, $ds_speed, $props);

my $sth = $dbh->prepare("select ob.objecttype_code, ep.state, ob.process, ep.entry_point, ob.identifer, decode(ob.objecttype_code, \
'PPPOE', 21, 'PPPOE_JL', 21, 'VLAN', 22, 'IP_UNNUM', 23, 'LLINE', 24, null) link_type, ct_p_srvpar_control.get_parvalue4date4outer(ob.id, \
'DL_ABON', 'RATE') rate,ct_p_srvpar_control.get_parvalue4date4outer(ob.id, 'DL_ABON', 'RATE_PORT_US') rate_port_us, \
ct_p_srvpar_control.get_parvalue4date4outer(ob.id, 'DL_ABON', 'RATE_PORT_DS') rate_port_ds, ep.props from it_t_entry_point ep, \
ct_t_object ob where ep.controbj_id=ob.id order by  ep.state, ob.process, ob.objecttype_code, ep.entry_point, ob.identifer") || die $dbh->errstr;
$sth->execute();
while (($ltype_name, $state, $service,  $ap_id, $login, $ltype_id, $inet_shape, $us_speed, $ds_speed, $props )=$sth->fetchrow_array) {

    if ( ( defined ($props) and $props =~ /communal\:1/ )
    or ( defined ($login) and $login =~ /^comtest\d+$/) ) {
	#print $props."\n";
	next;
    }
    if ( defined($ORA{$ap_id}) and $state eq 'ALLOW' ) { print " AP ".$ap_id." (".$login.") in current state '".$state."', service '".$service."'".
    " =>  Already exist (".$ORA{$ap_id}{'login'}.") for state '".$ORA{$ap_id}{'state'}."', service '".$ORA{$ap_id}{'service'}."'\n"; }

    if ( not defined($ORA{$ap_id}) or $ORA{$ap_id}{'state'} eq 'DENY' ) {
	$ORA{$ap_id} =
	{	login		=> $login,
		state		=> $state,
		service		=> $service,
		ltype_id	=> $ltype_id,
		inet_shape	=> $inet_shape,
		us_speed	=> $us_speed,
		ds_speed	=> $ds_speed,
	};
    }
	#print STDERR $login."\n";
    if ( defined($AP{$ap_id}{'login'}) ) {
	#print STDERR $ap_id." -->  "."login = ".$AP{$ap_id}{'login'}.
	#", MAC = ".$AP{$ap_id}{'hw_mac'}."\n";

	my $Q_up = '';
	if ($ORA{$ap_id}{'state'} eq 'DENY' or $ORA{$ap_id}{'service'} eq 'CANCEL' ) {
	    $Q_up = "DELETE from head_link WHERE port_id=".$ap_id;
	} elsif ($ORA{$ap_id}{'state'} eq 'ALLOW' ) {
	    if ($ora_srv{$ORA{$ap_id}{'service'}} != $AP{$ap_id}{'status'} ) {
		if ($ORA{$ap_id}{'ltype_id'} == 24 ) {
		    $Q_up .= " set_status=".$ora_srv{$ORA{$ap_id}{'service'}}.","; 
		} else {
		    $Q_up .= " status=".$ora_srv{$ORA{$ap_id}{'service'}}.","; 
		}
	    }
	    if ($ORA{$ap_id}{'inet_shape'} != $AP{$ap_id}{'inet_shape'} ) {
		    $Q_up .= " inet_shape=".$ORA{$ap_id}{'inet_shape'}.",";
	    }
	    if ($ORA{$ap_id}{'login'} ne $AP{$ap_id}{'login'} ) {
		    $Q_up .= " login='".$ORA{$ap_id}{'login'}."',";
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
	    print STDERR $Q_up."\n";
	}

    }
}
$sth->finish;

$dbm->disconnect; # MYSQL
$dbh->disconnect; # ORACLE
