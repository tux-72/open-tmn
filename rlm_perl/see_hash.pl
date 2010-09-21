#!/usr/bin/perl
use DB_File;

my $db_file = '/usr/local/etc/test.db';

#tie %data_hash, 'DB_File', "$pool_db" or die "Cant open POLL db file: $!\n";

tie %data_hash, 'DB_File', "$db_file", O_RDONLY, 0600, $DB_HASH or die "Cant open POOL db file: $!\n";

foreach my $keys (sort keys %data_hash) {
        if ( $keys =~ /(\d+)\D+(\d)/ ) { 
        #print rightspace($key,16)," ==  ".$data_hash{$key}."\n";
        #user1234  Cleartext-Password := "JocNacoigHar"
	    print rightspace($1.".".$2,16),' Cleartext-Password :=  "'.$data_hash{$keys}."\"\n";
        }
}

untie %data_hash;

sub rightspace {
    $str = shift;
    $len = shift;
    return sprintf("%-${len}s",$str);
}
