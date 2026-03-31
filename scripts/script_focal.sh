#!/bin/bash

USERNAME="root"
PASSWORD="root"

mount -t proc /proc /proc
mount -t sysfs /sys /sys
mount -t devtmpfs /dev /dev

echo "Ubuntu" > /etc/hostname
echo "${USERNAME}:${PASSWORD}" | chpasswd
apt -y update && apt -y upgrade
apt install -y vim build-essential network-manager
echo -e "network:\n"\
"  version: 2\n"\
"  renderer: NetworkManager\n"\
"  ethernets:\n"\
"    eth0:\n"\
"      dhcp4: true\n"\
> /etc/netplan/00-default.yaml

umount /proc
umount /sys
umount /dev

