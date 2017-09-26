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

pushd "${HOME}/openstack/ardana/ansible"

if [ -n "$ANSIBLE_FORKS" ]; then
    ANSIBLE_FORKS="-f $ANSIBLE_FORKS"
fi

ansible-playbook ${ANSIBLE_FORKS} \
    -i hosts/localhost \
    config-processor-run.yml \
    -e encrypt="" -e rekey="" 2>&1 |
  tee ${HOME}/ardana-upgrade-config-processor-run.log

ansible-playbook ${ANSIBLE_FORKS} \
    -i hosts/localhost \
    ready-deployment.yml 2>&1 |
  tee ${HOME}/ardana-upgrade-ready-deployment.log

popd

pushd "${HOME}/scratch/ansible/next/ardana/ansible"

ansible-playbook ${ANSIBLE_FORKS} \
    -i hosts/verb_hosts \
    ardana-upgrade.yml 2>&1 |
  tee ${HOME}/ardana-upgrade.log

# Customer optional
EXTRAARGS_CC=""

if [ -n "$HTTP_PROXY" ]; then
    EXTRAARGS_CC="-e proxy=\"$HTTP_PROXY\""
fi

ansible-playbook ${ANSIBLE_FORKS} \
    -i hosts/verb_hosts \
    ardana-cloud-configure.yml $EXTRAARGS_CC 2>&1 |
  tee ${HOME}/ardana-cloud-configure.log

popd
