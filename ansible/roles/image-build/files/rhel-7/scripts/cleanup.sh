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

aib_logs=/root/ardana_image_build
aib_script=cleanup
mkdir -p ${aib_logs}
exec 1>> ${aib_logs}/${aib_script}.log
exec 2>> ${aib_logs}/${aib_script}.log

# Remove any packages we don't want included in final image
echo "[Removing packages that are not needed]"
yum -y erase gtk2 libX11 hicolor-icon-theme avahi bitstream-vera-fonts

# Final image should have no DVD or EPEL repos or cached metadata
echo "[Clean out yum cache and DVD or RPEL repo definitions]"
yum -y clean all
rm -rf /etc/yum.repos.d/{epel,dvdrom}.repo

# Delete any artifacts we may have added
#echo "[Deleting imaging artifacts]"
#rm -rf VBoxGuestAdditions_*.iso

# Remove traces of mac address from network configuration
echo "[Remove node specific network settings]"
sed -i '/UUID/d' /etc/sysconfig/network-scripts/ifcfg-e*
sed -i '/HWADDR/d' /etc/sysconfig/network-scripts/ifcfg-e*
rm -fv /etc/udev/rules.d/70-persistent-net.rules
