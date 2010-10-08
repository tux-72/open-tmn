#!/usr/bin/perl

use strict;
use warnings;
use DBI;
use autouse 'Data::Dumper' => 'Dumper';
use FindBin;
use lib "$FindBin::Bin/../lib";
use DESCtl qw(DES_switch_params);
use ESCtl qw(ES_switch_params);
use BPSCtl qw(BPS_switch_params);

#sub SWFunc::dlog{print Dumper @_}
sub SWFunc::dlog{}


my $dsn = "DBI:mysql:database=vlancontrol;host=192.168.29.20;port=3306";
#our $dbh = DBI->connect( $dsn, "swweb", "CrarsEtsh5", {RaiseError => 1} );
our $dbh = DBI->connect( $dsn, "asb", "Vew1ontez", {RaiseError => 1} );
$dbh->do("set names koi8r");

END { $DB::dbh && $DB::dbh->disconnect(); }


my $sth = $dbh->prepare( "SELECT clients_vlan, hostname, lastuserport, ip, def_trunk, lib, admin_login, admin_pass, sw_id, uplink_port, bw_free, bw_ctl FROM hosts h, models m WHERE h.model_id=m.model_id and manage = 1 and h.visible > 0");
$sth->execute();
while( my $sw = $sth->fetchrow_hashref() )
{
    next unless $sw->{lib} eq 'ES' || $sw->{lib} eq 'GS' || $sw->{lib} eq 'DES' || $sw->{lib} eq 'BPS';
    $sw->{lib} = 'ES' if $sw->{lib} eq 'GS';
    next if $ARGV[0] && $sw->{hostname} ne $ARGV[0];
    print "!!!!!!!!!!!!!!Looking on switch $sw->{hostname}!!!!!!!!!!!!!!!!!!\n";

    my $sw_ports = $dbh->selectall_hashref( "SELECT * FROM swports WHERE sw_id = '$sw->{sw_id}' and type = 1", "port" );
    my $sw_real;
    {
        no strict 'refs';
        my $func = "$sw->{lib}_switch_params";
        $sw_real = &$func( IP=>$sw->{ip}, LOGIN=>$sw->{admin_login},PASS=>$sw->{admin_pass}, DEF_TRUNK=>$sw->{def_trunk} );
    }

    print("Cant read info from switch\n"),next if $sw_real == -1;
    for my $port ( sort{$a<=>$b} keys %{$sw_real->{ports}} )
    {
        print "port $port does not exists in db!!!\n" if !$sw_ports->{$port} && $sw_real->{ports}{$port}{up};
        print "port $port is used but in base it is free!!!\n"
            if $sw_real->{ports}{$port}{up} && ( !$sw_ports->{$port} || $sw_ports->{$port}{ltype_id} == 20 );

        if( !$sw_ports->{$port} || !$sw_ports->{$port}{ltype_id} || $sw_ports->{$port}{ltype_id} == 20 )
        {
            if( $sw->{bw_ctl} )
            {
                for( qw|ds_speed us_speed| )
                {
                    $sw_real->{ports}{$port}{flow_ctl} && $sw_real->{ports}{$port}{flow_ctl}{$_} != $sw->{bw_free} &&
                        print "port $port is free and $_ on switch = $sw_real->{ports}{$port}{flow_ctl}{$_}; in db bw_free = $sw->{bw_free}\n"
                }
            }

            if( $sw_real->{ports}{$port}{vlans} )
            {
                my $sw_cl_vid = $sw->{clients_vlan} ? $sw->{clients_vlan} : 4094;
                my @keys = keys %{$sw_real->{ports}{$port}{vlans}};
                my $port_vlan = ( (@keys == 1) ? $keys[0] : (grep{ $sw_real->{ports}{$port}{vlans}{$_} == 0 }@keys)[0] ) || 0;
                my $port_vlan_str = $port_vlan || join ',', @keys;

                print "port $port is free and has vlan $port_vlan_str that's not match witch sw_cl_vlan($sw_cl_vid)\n"
                    if $port_vlan != $sw_cl_vid;
            }
        }

        next unless $sw_ports->{$port};

        print "port $port status on switch = $sw_real->{ports}{$port}{adm_state}; indb db $sw_ports->{$port}{status}\n"
            if defined $sw_real->{ports}{$port}{adm_state} && $sw_real->{ports}{$port}{adm_state} != $sw_ports->{$port}{status};

        next if $sw_ports->{$port}{ltype_id} == 20 || $sw_ports->{$port}{ltype_id} == 19;

        print "port $port autoneg on switch = $sw_real->{ports}{$port}{autoneg}; indb db $sw_ports->{$port}{autoneg}\n"
            if defined $sw_real->{ports}{$port}{autoneg} && $sw_real->{ports}{$port}{autoneg} != $sw_ports->{$port}{autoneg};

        if( !$sw_real->{ports}{$port}{autoneg} )
        {
            $sw_real->{ports}{$port}{$_} && $sw_real->{ports}{$port}{$_} != $sw_ports->{$port}{$_} &&
                print "port $port $_ on switch = $sw_real->{ports}{$port}{$_}; indb db $sw_ports->{$port}{$_}\n"
                    for qw|duplex speed|;
        }

#print Dumper $sw_ports->{$port}, $sw_real->{ports}{$port};
        if( $sw->{bw_ctl} )
        {
            for( qw|ds_speed us_speed| )
            {
                $sw_ports->{$port}{$_} = -1 if $sw_ports->{$port}{$_} == 100000 and $port <= $sw->{lastuserport};
                $sw_real->{ports}{$port}{flow_ctl}{$_} = -1 if $sw_real->{ports}{$port}{flow_ctl}{$_} == 100000 and $port <= $sw->{lastuserport};

                $sw_real->{ports}{$port}{flow_ctl} && $sw_real->{ports}{$port}{flow_ctl}{$_} != $sw_ports->{$port}{$_} &&
                    print "port $port $_ on switch = $sw_real->{ports}{$port}{flow_ctl}{$_}; indb db $sw_ports->{$port}{$_}\n"
            }
        }

        print "port $port maxhwaddr on switch = $sw_real->{ports}{$port}{maxhwaddr}; indb db $sw_ports->{$port}{maxhwaddr}\n"
            if defined $sw_real->{ports}{$port}{maxhwaddr} && $sw_real->{ports}{$port}{maxhwaddr} != $sw_ports->{$port}{maxhwaddr};

        my $ports_vlans = $dbh->selectall_hashref( "SELECT * FROM port_vlantag WHERE port_id = '$sw_ports->{$port}{port_id}'", "vlan_id" );
        $sw_ports->{$port}{vlans} = { map{ $_, $ports_vlans->{$_}{tag} } keys %$ports_vlans };
        $sw_ports->{$port}{vlans}{ $sw_ports->{$port}{vlan_id} } = $sw_ports->{$port}{tag};

        $sw_ports->{$port}{vlans}{$sw->{clients_vlan}}=1 if $sw->{clients_vlan} && $sw->{uplink_port} == $port;

        my %vlans = map{ $_ => 1 } keys %{$sw_ports->{$port}{vlans}}, keys %{$sw_real->{ports}{$port}{vlans}};

        for my $vlan ( sort {$a<=>$b} keys %vlans )
        {
            print("port $port, vlan $vlan does not exists on switch\n"), next
                unless defined $sw_real->{ports}{$port}{vlans}{$vlan};
            print("port $port, vlan $vlan does not exists in db\n"), next
                unless defined $sw_ports->{$port}{vlans}{$vlan};

            print "port $port, vlan $vlan mismatch, ",
                    "in db {", (defined $sw_ports->{$port}{vlans}{$vlan} ? do{ $sw_ports->{$port}{vlans}{$vlan}?"tagged":"untagged" } : "does not exists"), "}",
                    "on sw {", (defined $sw_real->{ports}{$port}{vlans}{$vlan} ? do{ $sw_real->{ports}{$port}{vlans}{$vlan}?"tagged":"untagged" } : "does not exists"), "}",
                    "\n"
                if $sw_real->{ports}{$port}{vlans}{$vlan} != $sw_ports->{$port}{vlans}{$vlan}
        }
    }
        #print Dumper $sw_real, $sw_ports;
}


