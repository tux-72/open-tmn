#!/usr/bin/perl -w


my $debug=1;

$VERSION = 0.1;

#use strict;

use FindBin '$Bin';
require $Bin . '/../conf/libap.pl';

my $script_name=$0;
$script_name="$2" if ( $0 =~ /(\S+)\/(\S+)$/ );
print STDERR  "Use BIN directory - $Bin\n" if $debug;

sub startup {
    &dispatcher::log(1, "startup\n");
}

sub proc {
    &dispatcher::log(1, "proc\n");

    my %param;
    %param=split(/[:;]/,shift);

    #print params to log
    while(my ($k,$v)=each(%param)) {
	&dispatcher::log(1, "$k = $v\n");
    }

    ## GET AP_ID from SWCTL
    my ($ap_res, $ap_val) = SW_AP_get (\%param);
    return ($ap_res, $ap_val);

    #return (0, '*VALUE*');
}
