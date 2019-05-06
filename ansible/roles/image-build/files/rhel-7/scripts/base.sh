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

aib_logs=/root/ardana_image_build
aib_script=base
mkdir -p ${aib_logs}
exec 1>> ${aib_logs}/${aib_script}.log
exec 2>> ${aib_logs}/${aib_script}.log

# add cdrom as repo for install if needed
#mkdir -p /media/cdrom
#mount -t iso9660 /dev/cdrom /media/cdrom
#cat > /etc/yum.repos.d/dvdrom.repo <<EOF
#[DVD]
#name=RedHat Enterprise Linux 7.2 x86_64
#baseurl=file:///media/cdrom
#gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
#gpgcheck=1
#enabled=1
#EOF

# Run yum distribution-synchronization to update to latest versions
# of installed packages
echo "[Running zypper update]"
yum -y distribution-synchronization

# We should have sufficient software installed by the kickstart package list.
# However if there are additional packages we need to install, do so here
#echo "[Install additional packages]"
#yum -y install kernel-devel-`uname -r` dkms nfs-utils

# Make ssh faster by not waiting on DNS
if ! grep -qs "^[[:space:]]*UseDNS[[:space:]][[:space:]]*no$" /etc/ssh/sshd_config; then
	echo "[Adding 'UseDNS no' to sshd_config]"
	echo "UseDNS no" >> /etc/ssh/sshd_config
fi
