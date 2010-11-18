#!/usr/bin/perl -w

use POSIX qw(strftime);
use DBI();

$ENV{'NLS_LANG'}='RUSSIAN_AMERICA.AL32UTF8';

my $debug=1;
my $ver = "0.2";


use FindBin '$Bin';

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
#dlog ( SUB => $script_name, DBUG => 1, MESS => "Use BIN directory - $Bin" );

if (not defined($ARGV[0])) {
	usage();
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

	'STARTLINKCONF' => 20,
);

### MYSQL Connect
my $dbm = DBI->connect("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'}) or die("connect");
$dbm->do("SET NAMES 'koi8r'");
### ORACLE Connect
my $dbh=DBI->connect("dbi:Oracle:host=".$conf{'ORA_host'}.";sid=".$conf{'ORA_sid'}.";port=".$conf{'ORA_port'},$conf{'ORA_usn'},$conf{'ORA_psw'},{PrintError=>0,AutoCommit=>0,RaiseError=>1});

#sleep(600);

if ( $ARGV[0] eq 'switch' and defined($ARGV[1])) {
    $Q_host .= "SELECT p.port_id FROM hosts h, swports p WHERE h.sw_id=p.sw_id and p.ltype_id>=".$conf{'STARTLINKCONF'}." and p.ltype_id<22";
    if ($ARGV[1] =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ ) {
	$Q_host .= " and h.ip='".$ARGV[1]."'";
    } else {
	$Q_host .= " and h.hostname='".$ARGV[1]."'";
    }
    $Q_host .= " order by p.portpref, p.port";
    my $stm1 = $dbm->prepare($Q_host);
    $stm1->execute();
    while (my $ref1 = $stm1->fetchrow_hashref()) {
	#$dbh->do("delete from it_t_entry_point where state='ALLOW' and entry_point='".$ref1->{'port_id'}."'") || die $dbh->errstr; # Отправляем текущую точку доступа в архив
	$dbh->do("update it_t_entry_point set state='DENY' where state='ALLOW' and entry_point='".$ref1->{'port_id'}."'") || die $dbh->errstr; # Отправляем текущую точку доступа в архив
	dlog ( SUB => $script_name, DBUG => 1, MESS => "Reset AP_ID ".$ref1->{'port_id'}." host '".$ARGV[1]."'" );
    }
    $stm1->finish;
} elsif ( $ARGV[0] eq 'point' and defined($ARGV[1]) and $ARGV[1] =~ /(^\d+|ANY)$/ ) {
    #$dbh->do( "delete from it_t_entry_point where state='ALLOW' and entry_point='".$ARGV[1]."'" ) || die $dbh->errstr; # Отправляем текущую точку доступа в архив
    $dbh->do( "update it_t_entry_point set state='DENY' where state='ALLOW' and entry_point='".$ARGV[1]."'" ) || die $dbh->errstr; # Отправляем текущую точку доступа в архив
    dlog ( SUB => $script_name, DBUG => 1, MESS => "Reset AP_ID  ".$ARGV[1] );
} else {
    usage();
}

$dbm->disconnect; # MYSQL
$dbh->disconnect; # ORACLE

sub usage {
    print STDERR "!\nUsage: $script_name ( switch <hostname> | point <idport> )\n";
}

sub dlog {
	#dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => 'prompt', MESS => 'mess' )
	my %arg = (
	    @_,
	);
	if ( not $arg{'DBUG'} > $debug ) {
	    my $subchar = 20; my @lines = ();
	    $arg{'PROMPT'} .= ' ';
	    $arg{'PROMPT'} =~ tr/a-zA-Z0-9+-_:;,.?\(\)\/\|\'\"\t\#\>\</ /cs;

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
		print STDERR $timelog." ".rspaced("'".$arg{'SUB'}."'",$subchar).": ".$arg{'PROMPT'}.$mess."\n";
	    }
	}
}

sub rspaced {
    $str = shift;
    $len = shift;
    return sprintf("%-${len}s",$str);
}
