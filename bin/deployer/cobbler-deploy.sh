#!/bin/bash
#
# (c) Copyright 2016 Hewlett Packard Enterprise Development LP
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
# Runs in the deployer.
#

set -eux
set -o pipefail

export PYTHONUNBUFFERED=1
# Note: This must _NOT_ go into the default ansible config.
export ANSIBLE_MAX_FAIL_PERCENTAGE=0

ARDANA_USER="${1}"
SLES_VERSION="${2:-sles12sp3}"

pushd "${HOME}/openstack/ardana/ansible"

# Update the default SLES version setting in cobbler defaults
# to specify the desired SLES version
cobbler_defaults=roles/cobbler/defaults/main.yml
if grep -qs "^sles_version_name:" "${cobbler_defaults}"; then
    if ! grep -qs "^sles_version_name:.*${SLES_VERSION}" "${cobbler_defaults}"; then
        sed -i \
            -e 's,^\(sles_version_name:[[:space:]]*\).*,\1 "'${SLES_VERSION}'",' \
            "${cobbler_defaults}"
        git add -A
        git commit -m "Update default SLES version to '${SLES_VERSION}'"
    fi
fi

# increase the root volume disk space by 10G if needed:
cobbler_fs=/srv/www
srv_www_avail=$(df -m --output=avail ${cobbler_fs} | tail -1 | tr -d '[[:space:]]')
if (( srv_www_avail < 10240 )); then
    (( extra_space = ((((10240 + 255) - srv_www_avail)/256)*256) ))
    sudo lvresize -r -L +${extra_space}M $(df -m --output=source ${cobbler_fs} | tail -1)
fi

sudo mkdir -p /opt/ardana_packager/preseed/
sudo date +%Y%m%d%H%M%S | sudo tee /opt/ardana_packager/preseed/timestamp > /dev/null
# CI check for deployer in CP
sudo cat /opt/ardana_packager/preseed/timestamp | sudo tee /etc/cobbler_ardana_installeda > /dev/null

ansible-playbook -i hosts/localhost cobbler-deploy.yml \
    -e ardanauser_password="${ARDANA_USER}" | tee ${HOME}/cobbler-deployer.log

# vim:shiftwidth=4:tabstop=4:expandtab
