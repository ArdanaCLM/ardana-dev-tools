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

aib_logs=/root/ardana_image_build
aib_script=base
mkdir -p ${aib_logs}
exec 1>> ${aib_logs}/${aib_script}.log
exec 2>> ${aib_logs}/${aib_script}.log

# track if we need an grub update
grub_updated=

# Note: if the cdrom contains an iso, in sles12 it will automatically be added as a repo

# Check for any repos specified as kernel command line parameters
echo "[Checking for repo URLs in /proc/cmdline]"
for repo in pool updates updates_test
do
	url_name=sles_${repo}_url
	url_info=$(grep -o "${url_name}"'=[^ ]*' /proc/cmdline || true)
	if [ -n "${url_info}" ]; then
		echo "[Found ${url_name} in /proc/cmdline]"
		eval "${url_info}"

		echo "[Removing ${url_name} from grub kernel command line]"
		sed -i -e "s, *${url_name}=[^ ]* *, ," /etc/default/grub
		grub_updated=1
	fi
done

# Add any repos if found
[ -z "${sles_pool_url}" ] || zypper addrepo "${sles_pool_url}" Pool
[ -z "${sles_updates_url}" ] || zypper addrepo "${sles_updates_url}" Updates
[ -z "${sles_updates_test_url}" ] || zypper addrepo "${sles_updates_test_url}" Updates-test

# Run zypper update if the updates repo has been specified
if [ -n "${sles_updates_url}" ]; then
	# Install minimal set of updates for packages that we have
	echo "[Running zypper update]"
	zypper update --no-recommends -ly
fi

# We should have sufficient software installed by the autoyast package list.
# However if there are additional packages we need to install, do so here
#echo "[Install additional packages]"
#zypper -f install --no-recommends kernel-devel-`uname -r` dkms nfs-utils

# Make ssh faster by not waiting on DNS
if ! grep -qs "^[[:space:]]*UseDNS[[:space:]][[:space:]]*no$" /etc/ssh/sshd_config; then
	echo "[Adding 'UseDNS no' to sshd_config]"
	echo "UseDNS no" >> /etc/ssh/sshd_config
fi

# Elminate extraneous spectre_v2=off entries in /proc/cmdline
while [ "$(grep -o spectre_v2=off /etc/default/grub | wc -l | tr -d '[[:space:]]')" -gt 1 ]
do
	echo "[Removing duplicate 'spectre_v2=off' from grub kernel command line]"
	sed -i -e 's,spectre_v2=off ,,' /etc/default/grub
	grub_updated=1
done

# Elminate extraneous mitigations=off entries in /proc/cmdline
while [ "$(grep -o mitigations=off /etc/default/grub | wc -l | tr -d '[[:space:]]')" -gt 1 ]
do
	echo "[Removing duplicate 'mitigations=off' from grub kernel command line]"
	sed -i -e 's,mitigations=off ,,' /etc/default/grub
	grub_updated=1
done

# Refresh grub.cfg if we modified the grub settings
if [ -n "${grub_updated}" ]; then
	echo "[Refreshing grub.cfg]"
	grub2-mkconfig -o /boot/grub2/grub.cfg
fi
