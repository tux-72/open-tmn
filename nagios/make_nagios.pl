#!/usr/bin/perl

use strict;
use POSIX qw(strftime);
use DBI();

my $DB_host='192.168.29.20';
my $DB_base='switchnet';
my $DB_user='swgen';
my $DB_pass='SWgeneRatE';

#my $dbhost="localhost";

my $conf_dir = '/usr/local/cron/nagios';
my $conf_nag = '/usr/local/etc/nagios';
my $fconfig = "config-db/switchnet.cfg";
my $finfo = "config-db/switch-info.cfg";
my $portinfo = "config-db/port-info.cfg";
my $comunity = 'DfA3tKlvNmEk7';
my $pinfo='';


my $now_string = strftime "%F-%H-%M", localtime;
#system "mv $conf_nag/$fconfig $conf_nag/backups/$fconfig.$now_string" if (-e "$conf_nag/$fconfig");
#system "mv $conf_nag/$finfo $conf_nag/backups/$finfo.$now_string" if (-e "$conf_nag/$finfo");

open (CNFG, "> $conf_dir/$fconfig");
open (INFO, "> $conf_dir/$finfo");
open (PINFO, "> $conf_dir/$portinfo");

my $dbh = DBI->connect("DBI:mysql:database=".$DB_base.";host=".$DB_host,$DB_user,$DB_pass) or die("connect");
$dbh->do("SET NAMES 'koi8r'");

my $sth = $dbh->prepare("SELECT id, hostname FROM hosts ORDER BY id");
$sth->execute();
my %parents = ();
while (my $ref = $sth->fetchrow_hashref()) {
    $parents{$ref->{'id'}} = $ref->{'hostname'};
}
#$sth = $dbh->prepare("SELECT grp FROM hosts where grp <> '10v' GROUP by grp");
$sth = $dbh->prepare("SELECT grp FROM hosts GROUP by grp");
$sth->execute();
while (my $grp_ref = $sth->fetchrow_arrayref()) {
    my $grp = $grp_ref->[0];
    if ($grp ne "0-CORE") {
	print CNFG "define hostgroup{\n";
        print CNFG "\thostgroup_name\t" . $grp . "\n";
	print CNFG "\talias\tTransport Network in " . $grp . "\n";
	print CNFG "\}\n\n";
    }
    my $sth2 = $dbh->prepare("SELECT h.id, h.ip, h.hostname, h.parent, h.parent_ext, m.extra, m.comment, m.image FROM hosts h, models m where h.visible>0 and h.model>0 and h.model=m.id and h.grp='".$grp."'");
    $sth2->execute();
    while (my $ref = $sth2->fetchrow_hashref()) {
        print INFO "define hostextinfo\{
        icon_image switch40.png
        vrml_image switch40.png
";
        print INFO "\thost_name $ref->{'hostname'}\n";
        print INFO "\tnotes_url $ref->{'extra'}\n";
        print INFO "\ticon_image_alt $ref->{'comment'}\n";
        print INFO "\tstatusmap_image $ref->{'image'}\n" if ($ref->{'image'});
        print INFO "\}\n\n";

        print CNFG "define host{
        use\tgeneric-switch\n";
        if (defined($ref->{'parent_ext'})) {
            print CNFG "\tparents\t$ref->{'parent_ext'}\n";
        } else {
            print CNFG "\tparents\t$parents{$ref->{'parent'}}\n";
        }
#        if ($ref->{'parent'}) {
#            print CNFG "\tparents\t$parents{$ref->{'parent'}}\n";
#        } else {
#            print CNFG "\tparents\t$ref->{'parent_ext'}\n";
#        }
        print CNFG "\thost_name\t$ref->{'hostname'}\n";
        print CNFG "\talias\t$ref->{'comment'}\n";
        print CNFG "\taddress\t$ref->{'ip'}\n";
        print CNFG "\thostgroups\t" . $grp . "\n";
        print CNFG "\}\n\n";
        print CNFG "define service{
        use\tlocal-service\n";
        print CNFG "\thost_name\t$ref->{'hostname'}\n";
        print CNFG "\tservice_description\tUptime
        check_command\tcheck_snmp!-C ".$comunity." -o sysUpTime.0
\}\n\n";

    }
    
    $sth2->finish();

    my $sth3 = $dbh->prepare("SELECT h.id, h.hostname, p.portpref, p.port, p.info, p.portvlan, p.snmp_portindex, p.login FROM hosts h, swports p where h.visible>0 and h.model>0 and h.grp='".$grp."' and h.id=p.sw_id and p.link_type not in (0,20,19) and p.type>0 order by h.id, p.portpref, p.port");
    $sth3->execute();
    while (my $ref3 = $sth3->fetchrow_hashref()) {

#define service{
#        use                             SNMP-SERVICE
#        host_name                       Narod_8_10
#        service_description             01-kv326_10-26-17-129
#        check_command                   SNMP-1
#        }
	$pinfo='';
	$pinfo .= $ref3->{'portpref'} if (defined($ref3->{'portpref'}));
	if ($ref3->{'port'}<10) {
	    $pinfo .=  "0".$ref3->{'port'}."-port" if $ref3->{'port'};
	} else {
	    $pinfo .=  $ref3->{'port'}."-port" if $ref3->{'port'};
	}
	
	$pinfo .=  " ".koi2tr($ref3->{'info'});
	$pinfo .=  " vl-".$ref3->{'portvlan'} if $ref3->{'portvlan'};

	if (defined($ref3->{'login'}) and $ref3->{'login'} ne '' and not $ref3->{'info'}) {
	    $pinfo .=  " LOGIN ".koi2tr($ref3->{'login'});
	}
	
	$pinfo =~ tr/\'\"//;
	
 

        print PINFO "define service\{\n\tuse\t\t\tSNMP-SERVICE\n";
        print PINFO "\thost_name\t\t$ref3->{'hostname'}\n";
        print PINFO "\tservice_description\t$pinfo\n";

	if (defined($ref3->{'snmp_portindex'})) {
    	    print PINFO "\tcheck_command\t\tSNMP-".$ref3->{'snmp_portindex'}."\n";
	} else {
    	    print PINFO "\tcheck_command\t\tSNMP-".$ref3->{'port'}."\n";
	}

        print PINFO "\}\n\n";

    }
    
    $sth3->finish();


}

close CNFG;
close INFO;
close PINFO;

$sth->finish();
$dbh->disconnect();

#print STDERR "SWITCH MAP BUILD complete\n";
print "SWITCH MAP BUILD complete\n";

sub koi2tr  { ($_)=@_;

#
# Fonetic correct translit
#

#s/ /_/g;
# s/\.//g;

s/��/S\'h/; s/��/s\'h/; s/��/S\'H/;
s/�/Sh/g; s/�/sh/g;

s/���/Sc\'h/; s/���/sc\'h/; s/���/SC\'H/;
s/�/Sch/g; s/�/sch/g;

s/��/C\'h/; s/��/c\'h/; s/��/C\'H/;
s/�/Ch/g; s/�/ch/g;

s/��/J\'a/; s/��/j\'a/; s/��/J\'A/;
s/�/Ja/g; s/�/ja/g;

s/��/J\'o/; s/��/j\'o/; s/��/J\'O/;
s/�/Jo/g; s/�/jo/g;

s/��/J\'u/; s/��/j\'u/; s/��/J\'U/;
s/�/Ju/g; s/�/ju/g;

s/�/E\'/g; s/�/e\'/g;
s/�/E/g; s/�/e/g;

s/��/Z\'h/g; s/��/z\'h/g; s/��/Z\'H/g;
s/�/Zh/g; s/�/zh/g;

tr/
������������������������������������������������/
abvgdzijklmnoprstufhc\,y\,ABVGDZIJKLMNOPRSTUFHC\,Y\,/;

s/\,//g; 

return $_;

}
