#!/usr/bin/perl

package SWALLCtl;

#use strict;
#use Net::SNMP;
#use locale;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();
use POSIX qw(strftime);

$VERSION = 1.1;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
@EXPORT_TAGS = ();

@EXPORT = qw(	dlog  rspaced  lspaced
	    );

my $debug=1;

#my $LIB='SWALL';

############ SUBS ##############

sub rspaced {
    $str = shift;
    $len = shift;
    $r = sprintf("%-${len}s",$str);
}

sub lspaced {
    $str = shift;
    $len = shift;
    $r = sprintf("%${len}s",$str);
}

sub dlog {
        my %arg = (
            @_,
        );
        #dlog ( DBUG => 1, SUB => (caller(0))[3], PROMPT => 'prompt', MESS => 'mess' )
	my $subchar = 30; my @lines = ();
	$arg{'PROMPT'} .= ' ';

        if ( not $arg{'DBUG'} > $debug ) {
            my ($sec, $min, $hour, $day, $month, $year) = (localtime)[0,1,2,3,4,5];
            my $timelog = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year+1900, $month + 1, $day, $hour, $min, $sec);
            if ( ref($arg{'MESS'}) ne 'ARRAY' ) {
                @lines = split /\n/,$arg{'MESS'};
            } else {
                @lines = @{$arg{'MESS'}};
            }
            foreach my $mess ( @lines ) {
                $mess =~ tr/a-zA-Z0-9+-_:;,.?\(\)\/\|\'\"\t/ /cs;
                next if (not $mess =~ /\S+/);
                print STDERR $timelog." ".rspaced("'".$arg{'SUB'}."'",$subchar).": ".$arg{'PROMPT'}.$mess."\n";
            }
        }
}

1;
