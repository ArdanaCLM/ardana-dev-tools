#!/bin/sh -e
#
# Copyright (c) 2010-2012 Patrick Debois
# (c) Copyright 2016 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017 SUSE LLC
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#

echo "### Cleaning up udev rules"
rm -rf /dev/.udev/
rm /lib/udev/rules.d/75-persistent-net-generator.rules

if [ -d "/etc/sysconfig/network-scripts/" ]; then
    sed -i '/UUID/d' /etc/sysconfig/network-scripts/ifcfg-e*
    sed -i '/HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-e*
fi
if [ -d "/var/lib/dhcp" ]; then
    rm /var/lib/dhcp/*
fi

echo "### Cleaning up tmp dirs"
rm -rf /tmp/* /var/tmp/*

echo "### Cleaning up apt"
apt-get -y autoremove --purge
apt-get -y clean
apt-get -y autoclean

# if we add VirtualBox builder support
#rm -rf VBoxGuestAdditions_*.iso

echo "### Purging bash history"
# remove bash history
unset HISTFILE
rm -f /root/.bash_history
rm -f /home/*/.bash_history

echo "### Remove log files"
find /var/log -type f | while read f; do echo -ne '' > $f; done;
