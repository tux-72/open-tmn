#!/usr/bin/perl
use DB_File;

my $db_file = $ARGV[0];

while(<STDIN>) {
    #6365076953693589        203300  Nejyineksam6    OwEfdepweek8    JirtagicAin2    proccas0Shnu
    if ( /^\d+\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$/ ) {
          print
          rightspace($1.".1",16),' Cleartext-Password :=  "'.$2."\"\n".
          rightspace($1.".2",16),' Cleartext-Password :=  "'.$3."\"\n".
          rightspace($1.".3",16),' Cleartext-Password :=  "'.$4."\"\n".
          rightspace($1.".4",16),' Cleartext-Password :=  "'.$5."\"\n";
    }
}

sub rightspace {
    $str = shift;
    $len = shift;
    return sprintf("%-${len}s",$str);
}
