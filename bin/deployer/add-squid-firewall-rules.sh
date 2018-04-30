#!/bin/bash
#
# (c) Copyright 2018 SUSE LLC
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
# Runs in the deployer to add squid port settings to cloud firewall rules
#

set -eux
set -o pipefail

export PYTHONUNBUFFERED=1
# Note: This must _NOT_ go into the default ansible config.
export ANSIBLE_MAX_FAIL_PERCENTAGE=0

ARDANA_CLOUD_NAME="${1}"

pushd "${HOME}/openstack/ardana/ansible"

fw_rules=${HOME}/openstack/my_cloud/definition/data/firewall_rules_squid.yml

if [ ! -e "${fw_rules}" ]; then
    cat > "${fw_rules}" << _EOF_
# Add firewall rules to permit Squid (port 3128) traffic.
# The Ardana config processor will merge these rules with the existing
# rules automatically, so we can just add via an additional file, rather
# than appending to existing file.
---
  product:
    version: 2

  firewall-rules:
    - name: SQUID
      network-groups:
      - MANAGEMENT
      - ARDANA
      rules:
      - type: allow
        remote-ip-prefix:  0.0.0.0/0
        port-range-min: 3128
        port-range-max: 3128
        protocol: tcp
_EOF_
fi

git add -A
git commit --allow-empty -m "Add squid firewall rules to $ARDANA_CLOUD_NAME"

# vim:shiftwidth=4:tabstop=4:expandtab
