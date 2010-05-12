#!/usr/bin/perl

#
# 2010 Comintel, Batura Anatoly
#

use strict;
use DBI;
$ENV{'NLS_LANG'}='RUSSIAN_AMERICA.AL32UTF8';

my $maildomain = 'tmcity.ru';
my $qmailcontrol = '/opt/oracle/scripts/mail/mailbox_data/1mailbox.list';

my $scpremoteuser = 'qmaill';
my $mailhost = '192.168.100.25';
my $mailhostconfdir = '/var/qmail/control/spp_filter/tmp';

#my $host = "fst10.tech.tmcity.ru";
my $orahost = "fst";
my $oraport = 1521;
my $orasid  = "fst10";
my $orausn = "fastcom";
my $orapsw  = "fastcom";

my $dbh=DBI->connect("dbi:Oracle:host=".$orahost.";sid=".$orasid.";port=".$oraport,$orausn,$orapsw,{PrintError=>0,AutoCommit=>0,RaiseError=>1});

open(vMailUsers,  ">$qmailcontrol") || die "Файл не найден!";

my ($username, $ip_address, $mailbox, $mailboxsize, $spamfilter, $groupmailbox, $antivirus, $blockinside, $blockoutside);

# Get user list
my $sth=$dbh->prepare('select username, ip_address, mailbox, mailboxsize, spamfilter, antivirus, blockinside, blockoutside, groupmailbox from it_v_mail_users$');
$sth->execute();
print vMailUsers '#############'."\n\# username        ip_address          mailbox          mailboxsize spamfilter antivirus blockinside blockoutside groupmailbox\n".'#############'."\n";
while (($username, $ip_address, $mailbox, $mailboxsize, $spamfilter, $antivirus, $blockinside, $blockoutside, $groupmailbox)=$sth->fetchrow_array) {
    print vMailUsers rspaced($username,16).' '.rspaced($ip_address,16).' '.rspaced($mailbox,30)." $mailboxsize\t$spamfilter\t$antivirus\t$blockinside\t$blockoutside\t$groupmailbox\n";
}

$sth->finish();
$dbh->disconnect();

close(vMailUsers);

system ( '/usr/bin/scp -q '.$qmailcontrol.' '.$scpremoteuser.'@'.$mailhost.':'.$mailhostconfdir );
system ( '/usr/bin/ssh '.$scpremoteuser.'@'.$mailhost.' /usr/local/bin/sudo /usr/local/cron/make_vpopmail_users.pl' );

sub rspaced {
    my $str = shift;
    my $len = shift;
    return sprintf("%-${len}s",$str);
}
