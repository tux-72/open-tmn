#!/bin/sh

DIR="/usr/local/swctl"

if [ "$1" = "real" ]; then
    $DIR/sync_link_state.pl > /dev/null 2>&1
    $DIR/switch_control.pl checkterm
    $DIR/switch_control.pl checkport
    #$DIR/switch_control.pl checklink
fi 
