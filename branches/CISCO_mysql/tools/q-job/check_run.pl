#!/usr/bin/perl

use FindBin '$Bin';

$exec_file	= "cycle_check.pl";
$LOGDIR		= "/var/log/swctl";
$run_user	= "datasync";

my @processes = ( 	"checkterm",
			"checkjobs",
		);
$date = `date +%F.%H:%M:%S`;
$date =~ s/\n//g;

if ( $ARGV[0] eq "kill" ) {

    foreach $PROC ( @processes ) {
	    my $PIDFILE = "/var/run/swctl/cycle_check.pl_".$PROC;
	    if ( -f $PIDFILE ) {
		my $PID = `/bin/cat $PIDFILE`;
		print STDERR $PID."\n";
		if ( $PID+0 > 0 ) { system ( "kill $PID" ); }
	    }
    }

} elsif ( $ARGV[0] eq "real" ) {

    foreach $PROC ( @processes ) { 
	    my $SH_CMD = '/usr/bin/su '.$run_user.' -c "( '.$Bin.'/'.$exec_file.' '.$PROC.' >> '.$LOGDIR.'/'.$PROC.'-stderr.log 2>&1 ) &"';
	    system ( $SH_CMD );
    }

} else {
    print STDERR " USAGE - $0 real\n"
}
