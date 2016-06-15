#!/usr/bin/env bash

DEV="$1"
IP="$2"
PREF0="$3"

if [ -z $PREF0 ]; then
  PREF0=24
fi

cat << EOS > /etc/sysconfig/network-scripts/ifcfg-$DEV
BOOTPROTO=static
PREFIX0=$PREF0
DEVICE=$DEV
IPADDR0=$IP
ONBOOT=yes
EOS

#反映
ifdown $1; ifup $1
