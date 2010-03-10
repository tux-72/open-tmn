#!/usr/bin/perl

package SWDBCtl;

use strict;
no strict qw(refs);

use locale;
use DBI();
use SWALLCtl;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);

$VERSION = 1.1;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw( DB_mysql_connect DB_mssql_connect DB_mysql_check_connect
	    );

use FindBin '$Bin';
require $Bin . '/../conf/confdb.pl';
my $dbi = \%SWDBCtl::dbconf;

dlog ( SUB => (caller(0))[3]||'', DBUG => 2, LOGTYPE => 'LOGDISP', MESS => "Use BIN directory - $Bin" );

############ SUBS ##############

sub DB_mysql_connect {
    my $sqlconnect = shift;
    ${$sqlconnect} = DBI->connect_cached("DBI:mysql:database=".$dbi->{'MYSQL_base'}.";host=".$dbi->{'MYSQL_host'},$dbi->{'MYSQL_user'},$dbi->{'MYSQL_pass'})
    or die dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MYSQL DB host ".$dbi->{'MYSQL_host'}."$DBI::errstr" );
    ${$sqlconnect}->do("SET NAMES 'koi8r'") or die return -1;
    return 1;
}


sub DB_mysql_check_connect {
    my $sqlconnect = shift;
    my $db_ping = ${$sqlconnect}->ping;
    #dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DB PING = $db_ping" );
    if ( $db_ping != 1 ) {
        dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DB PING = $db_ping, MYSQL connect lost! RECONNECT to DB host ".$dbi->{'MYSQL_host'} );
        ${$sqlconnect}->disconnect;
        ${$sqlconnect} = DBI->connect_cached("DBI:mysql:database=".$dbi->{'MYSQL_base'}.";host=".$dbi->{'MYSQL_host'},$dbi->{'MYSQL_user'},$dbi->{'MYSQL_pass'})
        or dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MYSQL DB host ".$dbi->{'MYSQL_host'}."$DBI::errstr" );
        ${$sqlconnect}->do("SET NAMES 'koi8r'");
    }
}

sub DB_mssql_connect {
    my $sqlconnect = shift;
    ${$sqlconnect} = DBI->connect("dbi:Sybase:server=".$dbi->{'MSSQL_host'}.";language=russian", $dbi->{'MSSQL_user'},$dbi->{'MSSQL_pass'}) 
    or die dlog ( SUB => (caller(0))[3], DBUG => 2, MESS => "Unable to connect MSSQL DB host ".$dbi->{'MSSQL_host'}."$DBI::errstr" );

    ${$sqlconnect}->do("set dateformat ymd set language russian set ansi_null_dflt_on on") or die return -1;
    ${$sqlconnect}->func("ISO","_date_fmt") or die return -1;
    return 1;
}

1;
