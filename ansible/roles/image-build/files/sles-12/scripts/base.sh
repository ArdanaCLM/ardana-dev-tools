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

# add cdrom as repo for install if needed
# Note: if the cdrom contains an iso, in sles12 it will automatically be added as a repo
#mkdir -p /media/cdrom
#mount /dev/cdrom /media/cdrom
#zypper addrepo /media/cdrom mycdrom

# We should have sufficient software installed by the autoyast.
# The names of packages my differ from below.
#zypper -f install gcc make gcc-c++ kernel-devel-`uname -r` zlib-devel openssl-devel readline-devel sqlite-devel perl wget dkms nfs-utils

# Make ssh faster by not waiting on DNS
echo "UseDNS no" >> /etc/ssh/sshd_config
