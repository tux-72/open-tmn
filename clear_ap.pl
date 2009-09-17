#!/usr/bin/perl -w

use POSIX qw(strftime);
use DBI();

if (not defined($ARGV[0])) {
    print STDERR "\nUsage: clear_ap.pl ( switch <hostname> | point <idport> )\n\n";
    exit;
};

my $ver = "0.1";
my $debug=0;


my $PROG=$0;
if ( $PROG =~ /(\S+)\/(\S+)$/ ) {
    require $1.'/conf/config.pl';
    print STDERR "USE PROGRAMM DIRECTORY => $1\n\n";
} else {
    print STDERR "USE STANDART PROGRAMM DIRECTORY\n\n";
    require '/usr/local/swctl/conf/config.pl';
}

### MYSQL Connect
my $dbm = DBI->connect("DBI:mysql:database=".$conf{'MYSQL_base'}.";host=".$conf{'MYSQL_host'},$conf{'MYSQL_user'},$conf{'MYSQL_pass'}) or die("connect");
$dbm->do("SET NAMES 'koi8r'");

### MSSQL Connect
my $dbh = DBI->connect("dbi:Sybase:server=".$conf{'MSSQL_host'}.";language=russian", $conf{'MSSQL_user'},$conf{'MSSQL_pass'}) or die "Unable to connect. $DBI::errstr";
$dbh->do("set dateformat ymd set language russian set ansi_null_dflt_on on");
$dbh->func("ISO","_date_fmt");

my %link_type = ();
#my @link_types = '';
$stm0 = $dbm->prepare("SELECT id, name FROM link_types order by id");
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    $link_type{$ref0->{'name'}}=$ref0->{'id'} if defined($ref0->{'name'});
#    $link_types[$ref0->{'id'}]=$ref0->{'name'} if defined($ref0->{'name'});
}
$stm0->finish();

##############################

$hostname = $ARGV[0];
if ( $ARGV[0] eq 'switch' and defined($ARGV[1])) {

    my $stm1 = $dbm->prepare("SELECT p.port_id FROM hosts h, swports p WHERE h.hostname='".$ARGV[1]."' and h.id=p.sw_id and p.link_type>=".
    $link_type{'free'}." order by p.portpref, p.port");
    $stm1->execute();
    while (my $ref1 = $stm1->fetchrow_hashref()) {
	print STDERR "Host $hostname, ".$ref1->{'port_id'}."\n";
	$dbh->do("EXECUTE ClosePointAccess \@IdPoint=".$ref1->{'port_id'}) || die $dbh->errstr; # Отправляем текущую точку доступа в архив
    }
    $stm1->finish;
} elsif ( $ARGV[0] eq 'point' and defined($ARGV[1])) {
    $dbh->do("EXECUTE ClosePointAccess \@IdPoint=".$ARGV[1]) || die $dbh->errstr; # Отправляем текущую точку доступа в архив
}

$dbm->disconnect; # MYSQL
$dbh->disconnect; # MSSQL
