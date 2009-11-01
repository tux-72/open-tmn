#!/usr/bin/perl

package SWDBCtl;

#use strict;
use locale;
use DBI();
use SWALLCtl;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);

$VERSION = 1.1;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
@EXPORT_TAGS = ();

@EXPORT = qw( DB_mysql_connect DB_mssql_connect DB_mysql_check_connect
	    );

############ SUBS ##############

sub DB_mysql_connect {
    my $sqlconnect = shift;
    my $conf = shift;
    ${$sqlconnect} = DBI->connect_cached("DBI:mysql:database=".$conf->{'MYSQL_base'}.";host=".$conf->{'MYSQL_host'},$conf->{'MYSQL_user'},$conf->{'MYSQL_pass'})
    or die dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MYSQL DB host ".$conf->{'MYSQL_host'}."$DBI::errstr" );
    ${$sqlconnect}->do("SET NAMES 'koi8r'") or die return -1;
    return 1;
}


sub DB_mysql_check_connect {
    my $sqlconnect = shift;
    my $conf = shift;
    my $db_ping = ${$sqlconnect}->ping;
    #dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DB PING = $db_ping" );
    if ( $db_ping != 1 ) {
        dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "DB PING = $db_ping, MYSQL connect lost! RECONNECT to DB host ".$conf->{'MYSQL_host'} );
        ${$sqlconnect}->disconnect;
        ${$sqlconnect} = DBI->connect_cached("DBI:mysql:database=".$conf->{'MYSQL_base'}.";host=".$conf->{'MYSQL_host'},$conf->{'MYSQL_user'},$conf->{'MYSQL_pass'})
        or dlog ( SUB => (caller(0))[3], DBUG => 1, MESS => "Unable to connect MYSQL DB host ".$conf->{'MYSQL_host'}."$DBI::errstr" );
        ${$sqlconnect}->do("SET NAMES 'koi8r'");
    }
}

sub DB_mssql_connect {
    my $sqlconnect = shift;
    my $conf = shift;
    ${$sqlconnect} = DBI->connect("dbi:Sybase:server=".$conf->{'MSSQL_host'}.";language=russian", $conf->{'MSSQL_user'},$conf->{'MSSQL_pass'}) 
    or die dlog ( SUB => (caller(0))[3], DBUG => 2, MESS => "Unable to connect MSSQL DB host ".$conf->{'MSSQL_host'}."$DBI::errstr" );

    ${$sqlconnect}->do("set dateformat ymd set language russian set ansi_null_dflt_on on") or die return -1;
    ${$sqlconnect}->func("ISO","_date_fmt") or die return -1;
    return 1;
}

1;
