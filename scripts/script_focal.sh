#!/bin/bash
##########################################################################################
# Author: Ray
# Email: veidongray@qq.com
# Description: This script is used to configure the root filesystem in chroot environment.
##########################################################################################

USERNAME="root"
PASSWORD="root"

mount -vt proc /proc /proc
mount -vt sysfs /sys /sys
mount -vt devtmpfs /dev /dev

echo "Ubuntu" > /etc/hostname
echo "${USERNAME}:${PASSWORD}" | chpasswd

# Here we install some basic packages, you can modify this part to fit your needs.
apt -y update && apt -y upgrade
apt install -y vim build-essential network-manager xterm udhcpc picocom

# Configure netplan
# This will make NetworkManager manage all devices and by default.
# Any Ethernet device will come up with DHCP,
# once carrier is detected. fellows:
# cat /etc/netplan/00-default.yaml
# network:
#   version: 2
#   renderer: NetworkManager
echo -e "network:\n"\
"  version: 2\n"\
"  renderer: NetworkManager\n"\
> /etc/netplan/00-default.yaml

umount -v /proc
umount -v /sys
umount -v /dev

