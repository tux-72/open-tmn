#!/usr/bin/perl


use FindBin '$Bin';

$exec_file	= "cycle_check.pl";
$LOGDIR		= "/var/log/swctl";
$run_user	= "billsync";

my @processes = ( 	"checkterm",
	    		"checkjobs",
		);
$date = `date +%F.%H:%M:%S`;
$date =~ s/\n//g;

if ( $ARGV[0] eq "real" ) {

    foreach $PROC ( @processes ) { 
	    $SH_CMD = '/usr/bin/su '.$run_user.' -c "( '.$Bin.'/bin/'.$exec_file.' '.$PROC.' >> '.$LOGDIR.'/'.$PROC.'-stderr.log 2>&1 ) &"';
	    system ( $SH_CMD );
    }

} else {
    print STDERR " USAGE - $0 real\n"
}
