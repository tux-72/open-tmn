#!/usr/bin/perl


use FindBin '$Bin';

$exec_file	= "cycle_check.pl";
$LOGDIR		= "/var/log/swctl";

my @processes = ( 	"checkterm",
	    		"checkport",
#	    		"checklink",
		);
$date = `date +%F.%H:%M:%S`;
$date =~ s/\n//g;

if ( $ARGV[0] eq "real" ) {

    foreach $PROC ( @processes ) { 
	my $proc_found = system ('( /bin/ps ax | /usr/bin/grep '.$exec_file.' | /usr/bin/grep '.$PROC.' | /usr/bin/grep -v grep ) > /dev/null' );
	#print STDERR "FOUND = $proc_found\n";
	if ( $proc_found ) {
	    print STDERR "$date\trun new process $PROC\n";
	    $SH_CMD = "\( ".$Bin."/bin/".$exec_file." ".$PROC." \>\> ".$LOGDIR."/".$PROC.".log 2\>\&1 \) \&";
	    system ( $SH_CMD );
	#} else {
	#    print STDERR "$date\tprocess $PROC already running\n";
	}
    }

} else {
    print STDERR "Run CMD - $0\n"
}
