#!/usr/bin/perl -w


my $debug=1;

use Getopt::Long;
use strict;
use POSIX qw(strftime);
use locale;

use FindBin '$Bin';
use lib $Bin.'/../../lib';
use SWConf;
use SWFunc;

my $nas_conf = \%SWConf::aaa_conf;

my $dbm; my $res = DB_mysql_connect(\$dbm);
if ($res < 1) {
    dlog ( SUB => (caller(0))[3], DBUG => 0, MESS => "Connect to MYSQL DB FAILED, RESULT = $res" );
    DB_mysql_connect(\$dbm);
}

my $Querry = "SELECT login, ip_subnet FROM head_link WHERE login is not NULL ORDER by status desc, ip_subnet";
my $stm0 = $dbm->prepare($Querry);
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    if ( defined($ref0->{'ip_subnet'}) and $ref0->{'ip_subnet'} =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*/ ) {
        print $1."\t".$ref0->{'login'}."\n";
    }
}
$stm0->finish();

$Querry = "SELECT a.ip, a.login FROM dhcp_addr a, head_link l, dhcp_pools p WHERE l.login=a.login and a.pool_id=p.pool_id ".
" and p.pool_type>0 and (UNIX_TIMESTAMP(a.end_lease)+".$nas_conf->{'DHCP_WINDOW'}.")>UNIX_TIMESTAMP(now()) ORDER by a.end_lease";
$stm0 = $dbm->prepare($Querry);
$stm0->execute();
while (my $ref0 = $stm0->fetchrow_hashref()) {
    if (defined($ref0->{'ip'}) ) {
        #print $ref0->{'ip'}."\t".$ref0->{'login'}."  ".$ref0->{'end_lease'}."\n";
        print $ref0->{'ip'}."\t".$ref0->{'login'}."\n";
    }
}
$stm0->finish();
