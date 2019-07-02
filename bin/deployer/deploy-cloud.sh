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

# Optional based but will use the defaults if not specified
ANSIBLE_FORKS="${1:-}"
HTTP_PROXY="${2:-}"

pushd "${HOME}/scratch/ansible/next/ardana/ansible"

if [ -n "$ANSIBLE_FORKS" ]; then
    ANSIBLE_FORKS="-f $ANSIBLE_FORKS"
fi

# Hack workaround for not installing monasca or freezer agents (SOC-10253)
if ! grep "^[[:space:]]*-[[:space:]]*\(monasca\|freezer\)-agent[[:space:]]*$" \
     ${HOME}/openstack/my_cloud/definition/data/control_plane*.yml >/dev/null 2>&1; then
    (
        [[ ! -e ardana-ssh-keyscan.yml ]] || ansible-playbook ardana-ssh-keyscan.yml;
        ansible resources -b -m zypper -a "name=python-oslo.log state=present" 2>&1 || true
    ) | tee ${HOME}/python-oslo.log_install.log
fi

ansible-playbook ${ANSIBLE_FORKS} -i hosts/verb_hosts site.yml 2>&1 |
  tee ${HOME}/site.log

# Customer optional
EXTRAARGS_CC=""

if [ -n "$HTTP_PROXY" ]; then
    EXTRAARGS_CC="-e proxy=\"$HTTP_PROXY\""
fi

ansible-playbook ${ANSIBLE_FORKS} -i hosts/verb_hosts \
    ardana-cloud-configure.yml $EXTRAARGS_CC 2>&1 |
  tee ${HOME}/ardana-cloud-configure.log

# vim:shiftwidth=4:tabstop=4:expandtab
