#!/bin/sh -e
#
# Copyright (c) 2010-2012 Patrick Debois
# (c) Copyright 2017 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017-2018 SUSE LLC
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
#zypper remove gtk2 libX11 hicolor-icon-theme avahi bitstream-vera-fonts
zypper clean --all
zypper repos | grep -e "^[[:digit:]]\+" | awk '{print $3}' | while read repo
do
    zypper removerepo "${repo}"
done

# if we add VirtualBox builder support
#rm -rf VBoxGuestAdditions_*.iso

# Remove traces of mac address from network configuration
#sed -i '/UUID/d' /etc/sysconfig/network-scripts/ifcfg-e*
#sed -i '/HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-e*

rm -fv /etc/udev/rules.d/70-persistent-net.rules

