#!/usr/bin/perl

#TODO
# add field "port_isolation" in hosts
use warnings;
use strict;
use CGI qw/:standard/;
use CGI::Carp 'fatalsToBrowser';
use Template;
use Data::Dumper;
use FindBin;
use Net::Netmask;


$| = 1;
open(STDERR, ">>&=STDOUT");

#img
if( my $f = param("img") )
{
    $f =~ s/\/|\.\.//g;
    exit if !$f || !-f ( $f = "$FindBin::Bin/img/$f" );
    local $/;
    open(my $fh, "<", $f) || die $!;
    print "Content-type: image/jpeg\n\n", <$fh>;
    exit;
}
#css
if( my $f = param("css") )
{
    $f =~ s/\/|\.\.//g;
    exit if !$f || !-f ( $f = "$FindBin::Bin/tt/$f" );
    local $/;
    open(my $fh, "<", $f) || die $!;
    print "Content-type: text/css\n\n", <$fh>;
    exit;
}
my( $sth, $c );
my $host = 'http://netstat.tech.tmcity.ru';

print "Content-type: text/html\n\n" unless param("do");
die unless $ENV{REMOTE_USER};
$c->{admin} = $ENV{REMOTE_USER} =~ /^admin|asb$/;

my $log_locked = 0;
sub log
{
    open( my $LOG, ">>", "$FindBin::Bin/errors.log" ) || die "can't open log file";
    $log_locked++, flock( $LOG, 2 ) unless $log_locked;
    seek( $LOG, 0, 2 );
    chomp( my $s = "@_" );
    print $LOG join"|", scalar(localtime time),$s,$ENV{REMOTE_USER},$ENV{REMOTE_ADDR},$ENV{REQUEST_URI},$/;
    $log_locked = 0, flock( $LOG, 8 ) if $log_locked;
    close $LOG;
}

$SIG{__DIE__} = $SIG{__WARN__} = sub
{
    #skip known warnings
    return if grep m|Encode/ConfigLocal.pm|, @_;
    &log(@_);
    return 0;
};

sub chk_acess
{
    if( $c->{admin} < $_[0] )
    {
        print "Content-type: text/html\n\n" if param("do");
        print "Access denied.\n";
        &log("Access denied.\n");
        exit;
    }
}

sub mysql_error
{
    print "Content-type: text/html\n\n" if param("do");
    print "DB error<br>";
    print $DBI::errstr if $c->{admin};
    &log($DBI::errstr);
    exit;
}

########################################################################
package DB;

use DBI;
#my $dsn = "DBI:mysql:database=switchnet;host=192.168.29.20;port=3306";
my $dsn = "DBI:mysql:database=vlancontrol;host=192.168.29.20;port=3306";
our $dbh = DBI->connect( $dsn, "swweb", "CrarsEtsh5", {HandleError => \&main::mysql_error} );
$dbh->do("set names koi8r");

END { $DB::dbh && $DB::dbh->disconnect(); }
########################################################################
package main;

sub set_sel
{
    $_[0]->{selected}++ if $_[1] &&
        ( ( $_[4] && $_[1]->{$_[2]} eq $_->{$_[3]} ) ||
        ( !$_[4] && $_[1]->{$_[2]} == $_->{$_[3]} ) );
}

my $q = new CGI;
my $template = Template->new({ INCLUDE_PATH => '/usr/local/www/swctl/tt' });

sub host_utilisation
{
    my $sw_id = shift;
    my $sth = $DB::dbh->prepare( "SELECT lastuserport, def_trunk FROM models m, hosts h WHERE m.model_id=h.model_id and sw_id = ?");
    $sth->execute( $sw_id );
    my $h = $sth->fetchrow_hashref();
    my $lastuserport = $h->{def_trunk} > $h->{lastuserport} ? $h->{def_trunk}."t" : $h->{lastuserport}."u";
    (my $int_lastuserport = $lastuserport) =~ s|\D||;

    $sth = $DB::dbh->prepare( "SELECT count(*) AS used_ports FROM swports WHERE ltype_id not in (0,19,20) and type > 0 and sw_id = ?");
    $sth->execute( $sw_id );
    my $used_ports = $sth->fetchrow_hashref()->{used_ports};
    return { value => "$used_ports/$lastuserport", color => $int_lastuserport - $used_ports > 3 ? ($used_ports < 3 ? "green" : "") : "red" };
}

unless( grep{!/^do$/ && param($_)} param() )
{
    $sth = $DB::dbh->prepare( "SELECT model_id, model_name FROM models order by model_name");
    $sth->execute();
    while( $_ = $sth->fetchrow_hashref() ){ push @{$c->{models}}, $_ }

    $sth = $DB::dbh->prepare( "SELECT street_id, street_name FROM streets order by street_name");
    $sth->execute();
    while( $_ = $sth->fetchrow_hashref() ){ push @{$c->{streets}}, $_ }

    print "Content-type: text/html\n\n" if param("do");
    $c->{title} = "SWctl";
    $template->process("index.tt", $c) || die $template->error();
}elsif( grep{param($_)}qw|search_ip search_port_desc search_tr_net search_sw_wo_reg_vlan search_sw_wo_up search_login search_ap search_hostname search_vlan search_street search_model search_hidden search_mac| ){
    my @p;
    my $sql =
        qq{ SELECT *, (SELECT hostname FROM hosts WHERE sw_id=h.parent) as parent_name
        FROM `hosts` h, `models` m, `streets` s
        WHERE
        m.model_id=h.model_id and h.street_id = s.street_id };
    $sql .= " and h.hostname like ? ", push @p, param("search_hostname")."%" if param("search_hostname");
    #$sql .= " and clients_vlan = ? ", push @p, param("search_vlan") if param("search_vlan");

    $sql .= " and ( clients_vlan = ? OR h.sw_id in (SELECT sw_id FROM swports WHERE vlan_id = ?) VLAN_TRUNK_QUERY  ) ",
            push @p, (param("search_vlan"))x2 if param("search_vlan");
    my $vlan_trunk_query = '';
    $vlan_trunk_query = " or sw_id in ( SELECT sw_id FROM swports swp WHERE swp.port_id in (SELECT port_id FROM port_vlantag WHERE vlan_id= ?) ) ",
            push @p, param("search_vlan") if param("search_vlan_in_trunk");
    $sql =~ s/VLAN_TRUNK_QUERY/$vlan_trunk_query/s;

    $sql .= " and h.model_id = ? ", push @p, param("search_model") if param("search_model");
    $sql .= " and h.ip = ? ", push @p, param("search_ip") if param("search_ip");
    $sql .= " and h.sw_id in (SELECT sw_id FROM swports WHERE port_id = ?) ", push @p, param("search_ap") if param("search_ap");
    $sql .= " and h.sw_id in (SELECT sw_id FROM swports WHERE info like ?) ", push @p, "%".param("search_port_desc")."%" if param("search_port_desc");

    #This version of MySQL doesn't yet support 'LIMIT & IN/ALL/ANY/SOME subquery
    my $ap_switches = '
        SELECT sw_id FROM ap_login_info WHERE login like ?
        UNION
        SELECT sw_id FROM swports s, head_link h WHERE s.port_id=h.port_id AND login like ?
        ';
    if( param("search_ap_only_last") )
    {
        $sth = $DB::dbh->prepare( "
            (SELECT sw_id, last_date as sort FROM ap_login_info WHERE login like ?)
            UNION
            (SELECT sw_id, `stamp` as sort FROM swports s,head_link h WHERE s.port_id=h.port_id and login like ?)
            order by sort desc limit 1
            " );
        $sth->execute( (param("search_login"))x2 );
        $ap_switches = $sth->fetchrow_hashref();
        $ap_switches = $ap_switches ? $ap_switches->{sw_id} : 0;
    }
    $sql .= " and h.sw_id in ($ap_switches) ", push @p, param("search_ap_only_last") ? () : (param("search_login"))x2 if param("search_login");

    my $search_tr_net = param("search_tr_net");
    if( $search_tr_net && $search_tr_net =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ )
    {
        my $subnet_by_port_sql = $DB::dbh->selectall_hashref( "SELECT port_id, ip_subnet FROM head_link", "port_id" );
        my $tr_net_ports = (join',', grep
            {
                my $block = new Net::Netmask( $subnet_by_port_sql->{$_}{ip_subnet} );
                $block->match($search_tr_net) || $subnet_by_port_sql->{$_}{ip_subnet} =~ /^\Q$search_tr_net\/\E/
            } grep{$subnet_by_port_sql->{$_}{ip_subnet}} keys %$subnet_by_port_sql)||0;
        $sql .= " and sw_id in ( SELECT sw_id FROM swports WHERE port_id in ( $tr_net_ports )) ";
    }

    $sql .= " and h.street_id = ? ", push @p, param("search_street") if param("search_street");
    $sql .= " and h.visible = ? ", push @p, param("search_hidden") !~ /^on$/i if param("search_hidden");
    ( my $search_mac = param("search_mac") || '' ) =~ s/[^\da-f]//gi;
    $search_mac = join ':', $search_mac =~/(..)/g;
    ( my $search_mac1 = $search_mac ) =~ s|([a-f\d])(:)([a-f\d])|$1-$3|gi;
    $sql .= " and (h.hw_mac like ? OR h.hw_mac like ?
              OR h.sw_id in (SELECT sw_id FROM ap_login_info WHERE hw_mac like ?)
              ) ", push @p, ($search_mac."%", $search_mac1."%"), $search_mac."%"  if $search_mac;
    $sql .= " order by h.hostname ";
    #$sql .= " order by h.model_id, h.hostname ";

    if( param("search_sw_wo_up") )
    {
        $sql = "
            SELECT *, (SELECT hostname FROM hosts WHERE sw_id=h.parent) as parent_name
                 FROM `hosts` h, `models` m, `streets` s
                 WHERE
                 m.model_id=h.model_id and h.street_id = s.street_id and ( sw_id in
                    ( select sw_id from swports s where ( select count(sw_id) from swports s1 where s1.sw_id = h.sw_id and s1.ltype_id=10 ) = 0 )
                    or (select count(sw_id) from swports s where s.sw_id=h.sw_id) = 0 )";
        @p = ();
    }
    if( param("search_sw_wo_reg_vlan") )
    {
        $sql = "
            SELECT *, (SELECT hostname FROM hosts WHERE sw_id=h.parent) as parent_name
                 FROM `hosts` h, `models` m, `streets` s
                 WHERE
                 m.model_id=h.model_id and h.street_id = s.street_id and sw_id in
                    ( select s.sw_id from swports s where s.sw_id=h.sw_id and s.vlan_id>1 and s.ltype_id!=20 and s.vlan_id not in (select vl1.vlan_id from vlan_list vl1) )";
        @p = ();
    }
    $sth = $DB::dbh->prepare( $sql );
    $sth->execute( @p );
    $c->{total} = 0;
    while( $_ = $sth->fetchrow_hashref() )
    {
        next if !$c->{admin} && !$_->{visible};
        $c->{total}++;
        $_->{utilisation} = &host_utilisation($_->{sw_id});
        #next unless $_->{utilisation}{color} =~ /green/;
        push @{$c->{sw}}, $_
    }

    if( ref $c->{sw} eq 'ARRAY' && @{$c->{sw}} == 1 )
    {
        print header( { -location => "$host/swctl/?mode=host&action=view&sw_id=".$c->{sw}[0]{sw_id} } );
        exit;
    }

    print "Content-type: text/html\n\n";
    $c->{title} = "Search results";
    $template->process("switches.tt", $c) || die $template->error();
}elsif( param("mode") eq 'host' ){
    if( param("action") eq 'view' )
    {
        my $sql =
            qq{
            SELECT
                *,
                (SELECT hostname FROM hosts h1 WHERE h1.sw_id=h.parent) as parent_desc
            FROM `hosts` h, `models` m, `streets` s
            WHERE
                m.model_id=h.model_id and s.street_id = h.street_id and h.sw_id=? };
        $sth = $DB::dbh->prepare( $sql );
        $sth->execute( param('sw_id') );
        $c->{sw} = $sth->fetchrow_hashref();
        &chk_acess(1) if !$c->{sw}{visible};
        $c->{title} = $c->{sw}->{hostname}. " [". $c->{sw}->{model_name} . "]";
        $c->{sw}{extra} =~ s|http://netstat.tech.tmcity.ru/nagios/notes/|/swctl/?img=|;

        $sth = $DB::dbh->prepare( "SELECT sw_id, hostname, uplink_portpref, uplink_port, visible FROM hosts WHERE parent=? order by hostname" );
        $sth->execute( param('sw_id') );
        while( $_ = $sth->fetchrow_hashref() ){next if !$c->{admin} && !$_->{visible}; push @{$c->{sw_downlinks}}, $_ }

        use oui;

        $sth = $DB::dbh->prepare( "
            SELECT
                *, status, pt.phy_name as phy_type, ltype_name
            FROM
                swports s, link_types l, phy_types pt
            WHERE sw_id=? and s.phy_id=pt.phy_id and l.ltype_id=s.ltype_id order by portpref, port, type " );
        $sth->execute( param('sw_id') );

        while( $_ = $sth->fetchrow_hashref() )
        {
            (my$hlport = param("hlport")||'') =~ s/(\d+)-(\d+)/join",",$1..$2/eg;
            my@hlports = split/,/, $hlport;
            for my $port ( $hlport, @hlports )
            {
                last unless $port;
                $_->{highlight}++ if $port eq ($_->{portpref}||'').$_->{port};
            }
            $_->{free}++ if $_->{ltype_name} =~ /^free$/i || $_->{status} =~ /^disable$/i;
            $_->{broken}++ if $_->{ltype_name} =~ /^defect$/i;

            # vlan descr
            sub vlan_desc
            {
                return "" unless $c->{admin};
                my $vlan_id = shift;
                if( $vlan_id > 1 )
                {
                    my $vlan_desc = $DB::dbh->selectall_hashref( "SELECT vlan_id, info, `desc` FROM vlan_list WHERE vlan_id= '$vlan_id'", "vlan_id" );
                    $vlan_desc = $vlan_desc->{ (keys %$vlan_desc)[0] } if keys %$vlan_desc;
                    $_ && s/"/''/g for values %$vlan_desc;
                    $vlan_desc;
                }
            }
            $_->{vlan_desc} = &vlan_desc( $_->{vlan_id} );

            #port vlans
            my $sth1 = $DB::dbh->prepare(
            qq{
                SELECT
                    *,
                    ( SELECT `desc` FROM link_types lt WHERE lt.ltype_id = vl.ltype_id ) as link_type_desc
                FROM port_vlantag vt, vlan_list vl, vlan_zones vz
                WHERE vl.vlan_id = vt.vlan_id and vl.zone_id = vz.zone_id and vt.port_id = ? order by vl.zone_id, vl.vlan_id
            } );
            $sth1->execute( $_->{'port_id'} );
            while( my $vlan = $sth1->fetchrow_hashref() ){$vlan->{vlan_desc} = &vlan_desc( $vlan->{vlan_id} ); push @{$_->{vlans}}, $vlan}

            #port nets
            if( $c->{admin} )
            {
                $sth1 = $DB::dbh->prepare(
                qq{
                    SELECT (select `desc` from heads hds where hds.head_id=hl.head_id) as head_desc, hl.* FROM head_link hl WHERE port_id = ?
                } );
                $sth1->execute( $_->{'port_id'} );
                while( my $net = $sth1->fetchrow_hashref() )
                {
                    $net->{vlan_desc} = &vlan_desc( $net->{vlan_id} );
                    $net->{ip_subnet_enum} = join"; \n", new Net::Netmask( $net->{ip_subnet} )->enumerate if $net->{ip_subnet} && $net->{ip_subnet}=~/\//;
                    push @{$_->{nets}}, $net;
                }
            }

            #td
            $sth1 = $DB::dbh->prepare(
            qq{
                SELECT
                    login,hw_mac,start_date,last_date,vlan_id,trust,ip_addr
                FROM ap_login_info
                WHERE port_id=? ORDER by last_date desc
            } );
            $sth1->execute( $_->{'port_id'} );
            while( my $td = $sth1->fetchrow_hashref() ){ $td->{login}=~s/</&lt;/g; $td->{vlan_desc} = &vlan_desc( $td->{vlan_id} ); $td->{oui} = &oui::oui($td->{hw_mac}); push @{$_->{tds}}, $td }

            $_->{free_but_used}++ if $_->{ltype_id} == 21 && ( !$_->{tds} || !grep{ $_->{trust} } @{$_->{tds}} );

            #connections
            if( $_->{type} || ($_->{portpref}&&$_->{portpref} =~ /^Po/) )
            {
                $sth1 = $DB::dbh->prepare(
                qq|
                    SELECT
                        visible,
                        sw_id as to_id,
                        hostname as to_hostname,
                        uplink_port as to_port,
                        uplink_portpref as to_portpref,
                        1 as downlink
                    FROM hosts h
                    WHERE
                        h.parent = ? and
                        h.parent_port = ? and
                        IFNULL(h.parent_portpref,'') = IFNULL(?,'')
                | );
                $sth1->execute( $c->{sw}{sw_id}, $_->{port}, $_->{portpref} );
                while( my $downlink = $sth1->fetchrow_hashref() ){next if !$c->{admin} && !$downlink->{visible}; push @{$_->{links}}, $downlink }
            }

            $_->{type} = { 1 => "Real", 0 => "Virt" }->{$_->{type}};

            $_->{ltype_name} eq 'uplink' && push @{$_->{links}},
                {
                    visible     => 1,
                    to_id       => $c->{sw}{parent},
                    to_hostname => $DB::dbh->selectrow_array( "SELECT hostname FROM hosts WHERE sw_id = $c->{sw}{parent}" ),
                    to_port     => $c->{sw}{parent_port},
                    to_portpref => $c->{sw}{parent_portpref}
                };

            push @{$c->{ports}}, $_;
        }
        $c->{err} = "no uplink in ports" unless grep{!$_->{downlink}} map{@{$_->{links}}} grep{$_->{links}} @{$c->{ports}};
        $template->process("host.tt", $c) || die $template->error();
    }elsif( param("action") =~ /^edit|add$/ ){
        &chk_acess(1);
        if( param("do") )
        {
            my $params = $q->Vars;

            $params->{$_} ||= 0 for qw|visible bw_ctl automanage|;
            $params->{$_} =~ s/^\s*on\s*$/1/i for keys %$params;
            defined$params->{$_} && ($params->{$_} =~ /^(null|0|\s*)$/i) && ($params->{$_} = undef) for qw|clients_vlan hw_mac unit uplink_portpref parent_portpref parent_ext|;

            my $rows = "hw_mac, hostname, visible, model_id, ip, bw_ctl, automanage, uplink_port, uplink_portpref, parent, parent_port, parent_portpref, street_id, dom, podezd, unit, grp, clients_vlan, parent_ext, zone_id, control_vlan, stamp";
            my @vals = split/\s*,\s*/, $rows;
            my $phs = join ',', ("?") x @vals;

            if( param("action") eq 'add' )
            {
                @vals = grep !/^stamp$/, @vals;
                $phs =~ s/,\?//;
                $DB::dbh->do( "INSERT INTO hosts ($rows /*, stamp*/) VALUES ($phs ,NOW())", undef, @$params{@vals} ) or die $DB::dbh->errstr;
                my $new_sw_id = $DB::dbh->{'mysql_insertid'};

                #all ports
                if( 0 && $new_sw_id && ( my $model = $sth->fetchrow_hashref() ) )
                {
                    for my $port ( grep{$_!=$params->{uplink_port}} 1..$model->{def_trunk} )
                    {
                        my $sql = "INSERT INTO `swports`
                            SET `snmp_idx` = NULL,
                            `port_id` = NULL,
                            `ltype_id` = 20,
                            `communal` = 0,
                            `type` = 1,
                            `sw_id` = '$new_sw_id',
                            `portpref` = NULL,
                            `port` = '$port',
                            `status` = '1',
                            `ds_speed` = '$model->{bw_free}',
                            `us_speed` = '$model->{bw_free}',
                            `info` = NULL,
                            `start_date` = NULL,
                            `vlan_id` = '-1',
                            `tag` = '0',
                            `maxhwaddr` = '-1',
                            `head_id` = NULL,
                            `phy_id` = '1',
                            `autoneg` = '1',
                            `speed` = NULL,
                            `duplex` = NULL
                            ";
                        $DB::dbh->do( $sql ) or die $DB::dbh->errstr;
                    }
                }

                #uplink
                my $sql = "INSERT INTO `swports` SET
                    `snmp_idx` = NULL,
                    `port_id` = NULL,
                    `ltype_id` = 10,
                    `communal` = 0,
                    `type` = 1,
                    `sw_id` = '$new_sw_id',
                    `portpref` = NULLIF( '$params->{uplink_portpref}', '' ),
                    `port` = '$params->{uplink_port}',
                    `status` = '1',
                    `ds_speed` = '-1',
                    `us_speed` = '-1',
                    `info` = Concat( 'Uplink to ', (SELECT `hostname` FROM `hosts` WHERE sw_id = '$params->{parent}') ),
                    `start_date` = NULL,
                    `vlan_id` = '$params->{control_vlan}',
                    `tag` = '0',
                    `maxhwaddr` = '-1',
                    `head_id` = NULL,
                    `phy_id` = '1',
                    `autoneg` = '1',
                    `speed` = NULL,
                    `duplex` = NULL
                    ";
                $DB::dbh->do( $sql ) or die $DB::dbh->errstr;

                print header( { -location => "$host/swctl/?do=0&mode=host&action=view&sw_id=".$new_sw_id } );
            }elsif( param("action") eq 'edit' ){
                my $rows = join "=?,", split/\s*,\s*/, $rows;
                $DB::dbh->do( "UPDATE hosts SET $rows =? WHERE sw_id=?", undef, @$params{@vals}, param("sw_id") ) or die $DB::dbh->errstr;
                print header( { -location => "$host/swctl/?do=0&mode=host&action=view&sw_id=".param("sw_id") } );
            }
            exit;
        }

        my $in_base = 0;
        if( param("sw_id") )
        {
            $sth = $DB::dbh->prepare( "SELECT * FROM hosts WHERE sw_id=?" );
            $sth->execute( param('sw_id') );
            $c->{host} = $in_base = $sth->fetchrow_hashref();
            $c->{'sw_id'} = param("sw_id");
        }
        $c->{action} = 'edit' if param("action") =~ /^edit$/;
        $c->{action} = 'add' if param("action") =~ /^add$/;

        $sth = $DB::dbh->prepare( "SELECT model_id, model_name FROM models order by model_name" );
        $sth->execute( );
        while( $_ = $sth->fetchrow_hashref() ){ set_sel($_,$in_base,'model_id','model_id'); push @{$c->{models}}, $_ }

        $sth = $DB::dbh->prepare( "SELECT sw_id, hostname FROM hosts order by hostname" );
        $sth->execute( );
        while( $_ = $sth->fetchrow_hashref() ){ set_sel($_,$in_base,'parent','sw_id'); push @{$c->{parents}}, $_ }

        $sth = $DB::dbh->prepare( "SELECT DISTINCT grp, grp FROM hosts order by grp" );
        $sth->execute( );
        while( $_ = $sth->fetchrow_hashref() ){ set_sel($_,$in_base,'grp','grp',1); push @{$c->{groups}}, $_ }

        $sth = $DB::dbh->prepare( "SELECT street_id, street_name FROM streets s order by street_name" );
        $sth->execute( );
        while( $_ = $sth->fetchrow_hashref() ){ set_sel($_,$in_base,'street_id','street_id'); push @{$c->{streets}}, $_ }

        $sth = $DB::dbh->prepare( "SELECT zone_id, CONCAT(zone_name, ' (', `desc`, ')') as name FROM vlan_zones order by zone_id" );
        $sth->execute( );
        while( $_ = $sth->fetchrow_hashref() ){ set_sel($_,$in_base,'zone_id','zone_id'); push @{$c->{vlan_zones}}, $_ }

        $template->process("edithost.tt", $c) || die $template->error();
    }
}elsif( param("mode") eq 'mac' && param("action") eq 'view' && param('sw_id') ){
    use Net::SNMP;
    use oui;

    $sth = $DB::dbh->prepare( "SELECT hostname, clients_vlan, lib, rocom, ip FROM models m, hosts h WHERE m.model_id=h.model_id and h.sw_id=?" );
    $sth->execute( param('sw_id') );
    my $host_info = $c->{sw} = $sth->fetchrow_hashref();
    $c->{title} = $c->{sw}{hostname}." MAC's";

    sub snmp_get
    {
        my $OID = shift || die;
        my $comm_inf = shift || '';
        my($session, $error) = Net::SNMP->session(
            -hostname  => $host_info->{ip},
            -version   => 1,
            -community => $host_info->{rocom}.$comm_inf,
            -timeout   => 3,
        );

        if( !defined $session )
        {
            printf("ERROR: %s. Only control vlan shown.\n", $error);
            return {};
        }

        #my $OID = '1.3.6.1.2.1.17.7.1.2.2.1.2';
        #my $OID = '1.3.6.1.2.1.17.4.3.1.2';

        my $result = $session->get_entries( -columns => [ $OID ] );

        if( !defined $result )
        {
            #printf("ERROR: %s. Only control vlan shown.\n", $session->error);
            $session->close;
            return {};
        }
        $session->close;
        return $result;
    }

    my $OID;
    my $result;
    my %stats;
    if( !$host_info->{lib} || $host_info->{lib} !~ /^cat/i )
    {
        #dlink,zyxel
        $result = snmp_get( $OID ='1.3.6.1.2.1.17.7.1.2.2.1.2' );
        my %macs;
        for( keys %$result )
        {
            my($vlan,$mac)=$_=~/^\Q$OID.\E([^.]+)\.(.*)$/;
            $mac = join':',map{sprintf("%.2x",$_)}split/\./,$mac;
            $macs{$vlan}{$result->{$_}}{$mac}=1;
        }
        $c->{total} = keys %$result || 0;

        for my $vlan ( @{$c->{vlans_list}} = sort{$a<=>$b}keys%macs )
        {
            my @vlan;
            for my $port ( sort{$a<=>$b}keys%{$macs{$vlan}} )
            {
                my @port;
                for my $vlan ( sort keys%{$macs{$vlan}{$port}} )
                {
                    push@port, { value => $vlan, oui => &oui::oui($vlan) };
                    $stats{$port}++;
                }
                push@vlan, { name => $port, macs => \@port };
            }
            push @{$c->{vlans}}, { name => $vlan, ports => \@vlan };
        }
        push @{$c->{stats}}, { port => $_, count => $stats{$_} } for sort{$a<=>$b}keys%stats;
        $c->{vlans_current} = keys%macs;
    }else{
        &chk_acess(1) if $host_info->{lib} !~ /^catioslt/i;
        #cisco
        #http://www.cisco.com/en/US/tech/tk648/tk362/technologies_tech_note09186a00801c9199.shtml
        my %ifDescr;

        {
            #$result = snmp_get( $OID = '1.3.6.1.2.1.2.2.1.2' ); #ifDescr
            $result = snmp_get( $OID = '1.3.6.1.2.1.31.1.1.1.1' ); #ifName
            %ifDescr = map{ my$v = $result->{$_}; s/^$OID\.//; $_,$v }keys %$result;
        }
        #my @vlans = values %{snmp_get( $OID = '1.3.6.1.4.1.9.5.1.9.2.1.1' )}; #VlanIndex
        $OID = '1.3.6.1.4.1.9.9.46.1.3.1.1.2.1';
        my @vlans = map{s/^\.?$OID\.//;$_} keys %{snmp_get( $OID )};
        #my @vlans = 1..1000;
        #my @vlans = map$_->[0], @{$DB::dbh->selectall_arrayref( "SELECT distinct vlan_id FROM swports WHERE sw_id = '".(param('sw_id'))."'" )};
        #push @vlans, $host_info->{clients_vlan} if $host_info->{clients_vlan} && !grep /^$host_info->{clients_vlan}$/, @vlans;

        for my $vlan ( @{$c->{vlans_list}} = sort{$a<=>$b} @vlans )
        {
            my %port_mac;
            my %bridge_port_TO_bridge_port_number = %{snmp_get( $OID = '1.3.6.1.2.1.17.1.4.1.2', "\@$vlan" )};
            %bridge_port_TO_bridge_port_number = map{my$v=$bridge_port_TO_bridge_port_number{$_};s/^\.?$OID\.//;$_,$v} keys %bridge_port_TO_bridge_port_number;
            $result = snmp_get( $OID = '1.3.6.1.2.1.17.4.3.1.2', "\@$vlan" ); #dot1dTpFdbPort

            for my $mac( keys %$result )
            {
                my $bridge_port = $result->{$mac};
                my $port_idx = $bridge_port_TO_bridge_port_number{ $bridge_port };
                $mac =~ s/^$OID\.//;
                $mac = join':',map{sprintf("%.2x",$_)}split/\./, $mac;
                my $descr = exists $ifDescr{$port_idx} ? $ifDescr{$port_idx} : 'self';
                push @{$port_mac{$descr}}, $mac;
                $c->{total}++;
            }

            my @vlan;
            {
                no warnings;
                for my $port ( sort{my@a=split/\//,$a;my@b=split/\//,$b;$a[0]cmp$b[0]||$a[-1]<=>$b[-1]} keys %port_mac )
                {
                    push@vlan, { name => $port, macs => [ map{$stats{$port}++;{ value => $_, oui => &oui::oui($_) }} sort @{$port_mac{$port}} ] };
                }
            }
            next unless @vlan;
            $c->{vlans_current}++;
            push @{$c->{vlans}}, { name => $vlan, ports => \@vlan };
        }
        push @{$c->{stats}}, { port => $_, count => $stats{$_} } for sort{my@a=split/\//,$a;my@b=split/\//,$b;$a[0]cmp$b[0]||$a[-1]<=>$b[-1]}keys%stats;
        $c->{vlans_total} = @vlans - 4;
    }

    $template->process("macs.tt", $c) || die $template->error();
}elsif( param("mode") eq 'creted_but_not_used_vlans' ){
    &chk_acess(1);
    my $vlans;
    #kogda budut zoni nado peredelat
    $sth = $DB::dbh->prepare( "SELECT zone_id, vlan_id, info, `desc` FROM vlan_list v WHERE ltype_id not in (20,0) and v.vlan_id not in (select IFNULL(vlan_id,0) from swports union select IFNULL(clients_vlan,0) as vlan_id from hosts)" );
    $sth->execute( );
    my @free_vlans;
    while( $_ = $sth->fetchrow_hashref() ){ push @free_vlans, { zone_id => $_->{zone_id}, vlan_id => $_->{vlan_id}, info => $_->{info}, desc => $_->{desc}} }

    $c->{title} = 'Free But Registered Vlans';

    $c->{free_vlans} = \@free_vlans;
    $template->process("creted_but_not_used_vlans.tt", $c) || die $template->error();
}elsif( param("mode") eq 'free_vlans' ){
    &chk_acess(1);
    my $vlans;
    #kogda budut zoni nado peredelat
    $sth = $DB::dbh->prepare( "SELECT zone_id, vlan_id FROM vlan_list WHERE zone_id = 1 and ltype_id != 20 and ltype_id > 0" );
    $sth->execute( );
    while( $_ = $sth->fetchrow_hashref() ){ $vlans->{0}{$_->{vlan_id}}=1 }

    $sth = $DB::dbh->prepare( "SELECT clients_vlan, zone_id FROM hosts WHERE clients_vlan > 0" );
    $sth->execute( );
    while( $_ = $sth->fetchrow_hashref() ){ $vlans->{0}{$_->{clients_vlan}}=1 }
    $c->{title} = 'Free Vlans';

    my @free_vlans;
    for my $zone ( sort{$a<=>$b}keys %{$vlans} )
    {
        my %vlans;
        $vlans{$_}++ for (1..2000);
        for my $vlan ( sort{$a<=>$b}keys %{$vlans->{$zone}} )
        {
            delete $vlans{$vlan} if defined $vlans{$vlan};
        }

        if( param("print_ranges") ){
            my( $start, $prev, @free_vlans1, $last );
            for( sort{$a<=>$b}keys %vlans )
            {
                $last = $_;
                if( defined $start && $_ == $prev+1 )
                {
                    $prev++;
                }elsif( defined $start && $_ != $prev+1 ){
                    if( $start == $prev )
                    {
                        push @free_vlans1, $start;
                        undef $start;
                    }else{
                        push @free_vlans1, "$start-$prev";
                        $start = $prev = $_;
                    }
                }elsif( !defined $start ){
                    $start = $prev = $_
                }
            }
            if( $start == $last )
            {
                push @free_vlans1, $start;
            }else{
                push @free_vlans1, "$start-$last";
            }
            push @free_vlans, { zone => $zone, vlans => \@free_vlans1 };
        }else{
            push @free_vlans, { zone => $zone, vlans => [ sort{$a<=>$b}keys %vlans ] };
        }
    }
    $c->{free_vlans} = \@free_vlans;
    $template->process("free_vlans.tt", $c) || die $template->error();
}elsif( param("mode") eq 'port' ){
    &chk_acess(1);
    if( param("action") =~ /^edit|add|del$/ ){
        if( param("do") )
        {
            my $params = $q->Vars;

            $params->{$_} ||= 0 for qw|communal tag autoneg duplex|;
            $params->{$_} =~ s/^\s*on\s*$/1/i for keys %$params;
            for( qw|snmp_idx portpref port_ip ds_speed us_speed mac_port info login head_id speed duplex changer ip_subnet start_date| )
            {
                $params->{$_} = undef if defined$params->{$_} && $params->{$_} =~ /^(null|0|\s*)$/i;
            }

            my $rows = "snmp_idx, port_id, ltype_id, communal, type, sw_id, portpref, port, status, ds_speed, us_speed, info, start_date, vlan_id, tag, maxhwaddr, head_id, phy_id, autoneg, speed, duplex";
            my @vals = split/\s*,\s*/, $rows;
            my $phs = join ',', ("?") x @vals;

            if( param("action") eq 'add' )
            {
                $DB::dbh->do( "INSERT INTO swports ($rows) VALUES ($phs)", undef, @$params{@vals} ) or die $DB::dbh->errstr;
            }elsif( param("action") eq 'edit' ){
                my $rows = join "=?,", split/\s*,\s*/, $rows;
                $DB::dbh->do( "UPDATE swports SET $rows =? WHERE port_id=?", undef, @$params{@vals}, param("port_id") ) or die $DB::dbh->errstr;
            }elsif( param("action") eq 'del' ){
                $DB::dbh->do( "DELETE FROM swports WHERE port_id=?", undef, param("port_id") ) or die $DB::dbh->errstr;
            }
            print header( { -location => "$host/swctl/?do=0&mode=host&action=view&sw_id=".param("sw_id") } );
            exit;
        }

        $c->{'sw_id'} = param("sw_id") if param("sw_id");
        my $in_base = 0;
        if( param("port_id") )
        {
            $sth = $DB::dbh->prepare( "SELECT * FROM swports s WHERE s.port_id = ?" );
            $sth->execute( param('port_id') );
            $c->{'port'} = $in_base = $sth->fetchrow_hashref();
            $c->{'sw_id'} = $c->{'port'}{'sw_id'};
            $c->{'port'}{'head_id'} ||= '';
            $c->{'port_id'} ||= param("port_id") || $c->{'port'}{'port_id'};
        }
        $c->{action} = 'edit' if param("action") =~ /^edit$/;
        $c->{action} = 'add' if param("action") =~ /^add$/;


        $sth = $DB::dbh->prepare( "SELECT phy_id, phy_name FROM phy_types order by phy_name" );
        $sth->execute();
        while( $_ = $sth->fetchrow_hashref() ){ set_sel($_,$in_base,'phy_id','phy_id'); push @{$c->{phy_types}}, $_ }

        $sth = $DB::dbh->prepare( "SELECT ltype_id, ltype_name, `desc` FROM link_types order by ltype_id" );
        $sth->execute();
        push @{$c->{link_types}}, [0,''];
        while( $_ = $sth->fetchrow_hashref() ){ set_sel($_,$in_base,'ltype_id','ltype_id'); push @{$c->{link_types}}, $_ }

        for( { id => 1, name => "Up" }, { id => 0, name => "Down" } )
        {
            set_sel($_,$in_base,'status','id');
            push @{$c->{status_types}}, $_
        }

        for( { id => 1, name => "Real" }, { id => 0, name => "Virtual" } )
        {
            set_sel($_,$in_base,'type','id');
            push @{$c->{port_types}}, $_
        }

        $sth = $DB::dbh->prepare( "SELECT head_id, `desc` FROM heads ORDER by `desc`" );
        $sth->execute();
        while( $_ = $sth->fetchrow_hashref() ){ set_sel($_,$in_base,'head_id','head_id',1); push @{$c->{head_types}}, $_ }

        $template->process("editport.tt", $c) || die $template->error();
    }
}elsif( param("mode") eq 'model' ){
    &chk_acess(1);
    if( param("action") =~ /^edit|add$/ ){
        if( param("do") )
        {
            my $params = $q->Vars;

            $params->{$_} ||= 0 for qw|manage bw_free|;
            $params->{$_} =~ s/^\s*on\s*$/1/i for keys %$params;
            for( qw|lib| )
            {
                $params->{$_} = undef if defined$params->{$_} && $params->{$_} =~ /^(null|0|\s*)$/i;
            }

            my $rows = "model_name, template, extra, comment, image, lastuserport, def_trunk, manage, lib, admin_login, admin_pass, ena_pass, mon_login, mon_pass, bw_free, rocom, rwcom, old_admin, old_pass, sysDescr";
            my @vals = split/\s*,\s*/, $rows;
            my $phs = join ',', ("?") x @vals;

            if( param("action") eq 'add' )
            {
                $DB::dbh->do( "INSERT INTO models ($rows) VALUES ($phs)", undef, @$params{@vals} ) or die $DB::dbh->errstr;
                print header( { -location => "$host/swctl/?do=0&mode=model&action=edit&model_id=".$DB::dbh->{'mysql_insertid'} } );
            }elsif( param("action") eq 'edit' ){
                my $rows = join "=?,", split/\s*,\s*/, $rows;
                $DB::dbh->do( "UPDATE models SET $rows =? WHERE model_id=?", undef, @$params{@vals}, param("model_id") ) or die $DB::dbh->errstr;
                print header( { -location => "$host/swctl/?do=0&mode=model&action=edit&model_id=".param("model_id") } );
            }
            exit;
        }

        my $in_base = 0;
        if( param("model_id") )
        {
            $sth = $DB::dbh->prepare( "SELECT * FROM models WHERE model_id = ?" );
            $sth->execute( param('model_id') );
            $c->{'model'} = $in_base = $sth->fetchrow_hashref();
            $c->{'model_id'} = param("model_id");
        }
        $c->{action} = 'edit' if param("action") =~ /^edit$/;
        $c->{action} = 'add' if param("action") =~ /^add$/;

        $template->process("editmodel.tt", $c) || die $template->error();
    }
}elsif( param("mode") eq 'vlan' ){
    &chk_acess(1);
    if( param("action") =~ /^edit|add$/ ){
        if( param("do") )
        {
            my $params = $q->Vars;

            $params->{$_} =~ s/^\s*on\s*$/1/i for keys %$params;
            $params->{"port_id"} = undef if defined$params->{"port_id"} && $params->{"port_id"} =~ /^(null|0|\s*)$/i;
            my $rows = "vlan_id, zone_id, port_id, ltype_id, info, desc";
            my @vals = split/\s*,\s*/, $rows;
            my $phs = join ',', ("?") x @vals;
            if( param("action") eq 'add' )
            {
                my $rows = join ",", map{"`$_`"} split/\s*,\s*/, $rows;
                $DB::dbh->do( "INSERT INTO vlan_list ($rows) VALUES ($phs)", undef, @$params{@vals} ) or die $DB::dbh->errstr;
            }elsif( param("action") eq 'edit' ){
                my $rows = join "=?,", map{"`$_`"} split/\s*,\s*/, $rows;
                $DB::dbh->do( "UPDATE vlan_list SET $rows =? WHERE vlan_id=? and zone_id=?", undef, @$params{@vals}, param("vlan_id"), param("zone_id") ) or die $DB::dbh->errstr;
            }
            print header( { -location => "$host/swctl/?do=0&mode=vlan&action=edit&vlan_id=".param("vlan_id")."&zone_id=".param("zone_id") } );
            exit;
        }

        my $in_base = 0;
        if( param("vlan_id") && param("zone_id") )
        {
            $sth = $DB::dbh->prepare( "SELECT * FROM vlan_list WHERE vlan_id = ? and zone_id = ?" );
            $sth->execute( param('vlan_id'), param('zone_id') );
            $c->{'vlan'} = $in_base = $sth->fetchrow_hashref();
            $c->{'vlan_id'} = param("vlan_id");
            $c->{'zone_id'} = param("zone_id");
        }
        $c->{action} = 'edit' if param("action") =~ /^edit$/;
        $c->{action} = 'add' if param("action") =~ /^add$/;


        $sth = $DB::dbh->prepare( "SELECT zone_id, CONCAT(zone_name, ' (', `desc`, ')') as name FROM vlan_zones order by zone_id" );
        $sth->execute( );
        while( $_ = $sth->fetchrow_hashref() ){ set_sel($_,$in_base,'zone_id','zone_id'); $c->{zone_desc}=$_->{name} if param("zone_id") && $_->{zone_id} == param("zone_id"); push @{$c->{vlan_zones}}, $_ }

        $sth = $DB::dbh->prepare( "SELECT ltype_id, ltype_name, `desc` FROM link_types order by ltype_name" );
        $sth->execute();
        while( $_ = $sth->fetchrow_hashref() ){ set_sel($_,$in_base,'ltype_id','ltype_id'); push @{$c->{link_types}}, $_ }

        $template->process("editvlan.tt", $c) || die $template->error();
    }
}elsif( param("mode") eq 'jobs' ){
    &chk_acess(1);
    $sth = $DB::dbh->prepare( "SELECT *,(CASE date_exec WHEN '0000-00-00 00:00:00' THEN 99999999999 ELSE date_exec END) as date_exec_sort,(CASE archiv WHEN 0 THEN 99999999999 ELSE 0 END) as archiv_sort FROM link_types t, bundle_jobs j, hosts h, swports p WHERE j.ltype_id=t.ltype_id and h.sw_id=p.sw_id and j.port_id=p.port_id ORDER by archiv_sort desc, date_exec_sort desc, date_insert limit 200" );
    $sth->execute();
    while( $_ = $sth->fetchrow_hashref() )
    {
        $_->{done} = 0 + ( $_->{job_id}==$_->{archiv} );
        $_->{state} = 'unknown';
        $_->{state} = 'done' if $_->{done};
        $_->{state} = 'pending' unless $_->{archiv};
        $_->{state} = 'running' if $_->{archiv} && $_->{archiv} == 1;

        my @a = split/[;:]/, $_->{parm};
        $_->{parm} = [];
        while( @a )
        {
            push @{$_->{parm}}, { name => shift@a, value => shift@a }
        };
        push @{$c->{jobs}}, $_;
    }
    $c->{title} = 'Jobs list';

    $template->process("jobs.tt", $c) || die $template->error();
}elsif( param("mode") eq 'delete_old_logs' ){
    &chk_acess(1);
    print "Calculating rows count...<br>";
    my $cnt = $DB::dbh->selectall_arrayref( "select count(*) FROM `log` WHERE time < date_sub(now(),INTERVAL 2 month)" );
    print "Deleting $cnt->[0][0] rows...<br>";
    $DB::dbh->do( "delete FROM `log` WHERE time < date_sub(now(),INTERVAL 2 month)" );
    print "done.";
}elsif( param("mode") eq 'logs' ){
    &chk_acess(1);
    $sth = $DB::dbh->prepare( "select `time`, `table`, `event`, group_concat(`changes` SEPARATOR ' <br>') as changes  from `log` group by `time`, `table`, `event` order by `time` desc, `table`, `event` limit 300" );
    $sth->execute();
    while( $_ = $sth->fetchrow_hashref() ){ $_->{changes}=~s!(?:(?<=\s)|(?=^))(\S+)(?=\s*=\s*")!<b>$1</b>!g; push @{$c->{logs}}, $_ }
    $c->{title} = 'Logs';

    $template->process("logs.tt", $c) || die $template->error();
}elsif( param("mode") eq 'create_trigger' ){
    &chk_acess(1);
#CREATE TABLE `switchnet_dev`.`log` (
#  `id` INT NOT NULL AUTO_INCREMENT,
#  `event` VARCHAR(20)  NOT NULL,
#  `table` VARCHAR(255) NOT NULL,
#  `time` DATETIME NOT NULL,
#  `changes` VARCHAR(4096) NOT NULL,
#  PRIMARY KEY (`id`)
#)

    my $database = 'vlancontrol';
    my @tables = map$_->[0], @{$DB::dbh->selectall_arrayref( "SELECT table_name FROM INFORMATION_SCHEMA.TABLES WHERE table_schema = '$database'" )};

    print "<pre>";
    for my $table ( @tables )
    {
        next if grep/^$table$/, qw|log bundle_jobs ap_login_info dhcp_addr head_link|;
        my $cols = $DB::dbh->selectall_hashref( "SELECT column_name, column_key FROM INFORMATION_SCHEMA.columns WHERE table_schema = '$database' and table_name = '$table'", "column_name" );
        for my $event ( qw|insert update delete| )
        {
            my $str =
                qq|
                CREATE TRIGGER ${table}_log_${event} AFTER  $event ON $table
                FOR EACH ROW
                BEGIN
                |;
            if( $event eq 'update' ){
                for my $pri_col ( grep{$cols->{$_}{column_key}=~/^pri$/i} keys %$cols )
                {
                    $str .=
                    qq|
                        INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), '$event', '$table', CONCAT('PK_$pri_col: from="', IFNULL(old.`$pri_col`,''), '" to="', IFNULL(new.`$pri_col`,''),'"'));
                    |;
                }
            }
            for my $col ( keys %$cols )
            {
                if( $event eq 'delete' )
                {
                    $str .=
                    qq|
                        INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), '$event', '$table', CONCAT('$col="',IFNULL(old.`$col`,''),'"') );
                    |;
                }elsif( $event eq 'insert' ){
                    $str .=
                    qq|
                        INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                        (now(), '$event', '$table', CONCAT('$col="', IFNULL(new.`$col`,''),'"'));
                    |;
                }elsif( $event eq 'update' ){
                    $str .=
                    qq|
                        IF IFNULL(old.`$col`,'') != IFNULL(new.`$col`,'') THEN
                            INSERT INTO `log` ( `time`, `event`, `table`, `changes` ) VALUES
                            (now(), '$event', '$table', CONCAT('$col: from="', IFNULL(old.`$col`,''), '" to="', IFNULL(new.`$col`,''),'"'));
                        END IF;
                    |;
                }
            }
            $str .= "\nEND;\n";
            #print $str;
            eval{ $DB::dbh->do( "drop trigger if exists `${table}_log_${event}`" ); };
            eval{ $DB::dbh->do( join" ", split /\s+\n\s+/,$str ); };
            print "Created trigger ${table}_log_${event}\n";
        }
    }
}else{
    die "<font color=red><h1>Something wrong</h1></font>";
}



$sth->finish() if $sth;

