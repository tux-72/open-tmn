#!/usr/bin/perl

package SWALLCtl;

#use strict;
#use Net::SNMP;
#use locale;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);
use IO::Socket;

$VERSION = 1.2;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
@EXPORT_TAGS = ();

@EXPORT = qw(	dlog  rspaced  lspaced	IOS_rsh
	    );

my $debug=1;


use FindBin '$Bin';
require $Bin . '/../conf/loging.pl';

############ SUBS ##############

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
        #dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => 'prompt', LOGFILE => '/var/log/dispatcher/ap_get.log', MESS => 'mess' )
        if ( not $arg{'DBUG'} > $debug ) {
	    my $stderrout=1;
	    if ( defined($conflog{$arg{'LOGTYPE'}}) ) {
		open( LOGFILE,">> ".$conflog{$arg{'LOGTYPE'}} );
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
		$logline = $timelog." ".rspaced("'".$arg{'SUB'}."'",$subchar).": ".$arg{'PROMPT'}.$mess."\n";
		if ($stderrout) {
            	    print STDERR $logline;
		} else {
            	    print LOGFILE $logline;
		}
            }
	    if (not $stderrout) { close LOGFILE; }
	}
}

{
    #my $pid_decr = (($$ & 127) << 1 );
    my $pid_decr = (($$ & 7) << 1 );
    my $end_port = 20000 - 1024 * $pid_decr;
    my $start_port = $end_port - 1024;

    dlog ( DBUG => 2, SUB => (caller(0))[3], MESS => "PID decr = $pid_decr, start_port = $start_port, end_port = $end_port"  );
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
	$socket->shutdown(HOW);
        return @c;
    }
}


1;
