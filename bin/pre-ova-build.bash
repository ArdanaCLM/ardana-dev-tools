#!/bin/bash
#
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
# Install VMware tools needed for OVA creation

set -eux
set -o pipefail

## VMware-vix and ovftools to build ova from qcow2
export VMWARE_TOOLS_REPO="${VMWARE_TOOLS_REPO:-http://hpsoft.suse.provo.cloud}"
export VMWARE_OVFTOOL="${VMWARE_OVFTOOL:-VMware-ovftool-4.0.0-2189843-lin.x86_64.bundle}"
export VMWARE_VIX_DISKLIB="${VMWARE_VIX_DISKLIB:-VMware-vix-disklib-5.5.3-1909144.x86_64.tar.gz}"

if [ ! -f "${VMWARE_OVFTOOL}" ]; then
    wget "${VMWARE_TOOLS_REPO}/${VMWARE_OVFTOOL}"
    sudo bash ./"${VMWARE_OVFTOOL}" --console --eulas-agreed
fi

if [ ! -f "${VMWARE_VIX_DISKLIB}" ]; then
    wget "${VMWARE_TOOLS_REPO}/${VMWARE_VIX_DISKLIB}"
    tar xvzf "${VMWARE_VIX_DISKLIB}"
    cd vmware-vix-disklib-distrib && sudo ./vmware-install.pl --default EULA_AGREED=yes
    cd ..
fi
# Disk size in GB
export HLINUX_OVA_DISK_SIZE="${HLINUX_OVA_DISK_SIZE:-40}"
export HLINUX_OVA_USER_NAME="${HLINUX_OVA_USER_NAME:-stack}"

# Tool to build qcow2 disk-image-builer or packer
export QCOW2_BUILD_TOOL=${QCOW2_BUILD_TOOL:-DIB}
export OVA_OUTPUT_DIR=${OVA_OUTPUT_DIR:-/tmp}
