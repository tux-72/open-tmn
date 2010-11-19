#!/usr/bin/perl

my $debug=1;

package SWFuncAAA;

use strict;

#use locale;
use POSIX qw(strftime);
use DBI();
use SWFunc;

use Authen::Radius;
Authen::Radius->load_dictionary();

use Data::Dumper;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION);
use Exporter ();

$VERSION = 1.0;

@ISA = qw(Exporter);

@EXPORT_OK = qw();
%EXPORT_TAGS = ();

@EXPORT = qw( send_pod
);

my $start_conf	= \%SWConf::conf;
my $dbi		= \%SWConf::dbconf;
my $nas_conf	= \%SWConf::aaa_conf;

my $Querry_start = '';
my $Querry_end = '';
my $res;
my $dbm;

############ SUBS ##############

sub send_pod {

    my $param = shift;
    my $sender = shift;
    # nas_ip nas_port nas_secret login

    my ( $res, $a, $err, $strerr );
    my $res_attr = "attr:";

    my $r = new Authen::Radius(Host => $param->{'nas_ip'}.":".$param->{'nas_port'}, Secret => $param->{'nas_secret'}, Debug => 0);
    $r->add_attributes (
      { Name => 'User-Name', Value => $param->{'login'} }
    );

    $r->send_packet(DISCONNECT_REQUEST);
    $res = $r->recv_packet();

    $err = $r->get_error;
    $strerr = $r->strerror;

    for $a ($r->get_attributes()) {
        $res_attr .= ",".$a->{'Name'}."='".$a->{'Value'}."'";
        if($a->{'Name'} eq 'Error-Cause' &&  $a->{'Value'} eq 'Session-Context-Not-Found') {
            $res = 41;
        }
    }
    return ( $res+0, "strerr:".$strerr.";".$res_attr );

}


1;
