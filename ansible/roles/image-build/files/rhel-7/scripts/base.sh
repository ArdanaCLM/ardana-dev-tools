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

# we should have sufficient software installed by the kickstart
#yum -y install gcc make gcc-c++ kernel-devel-`uname -r` zlib-devel openssl-devel readline-devel sqlite-devel perl wget dkms nfs-utils

# Make ssh faster by not waiting on DNS
echo "UseDNS no" >> /etc/ssh/sshd_config
