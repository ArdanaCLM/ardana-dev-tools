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

SCRIPT_NAME=$(basename $0)

export PYTHONUNBUFFERED=1
# Note: This must _NOT_ go into the default ansible config.
export ANSIBLE_MAX_FAIL_PERCENTAGE=0

NO_CONFIG=

TEMP=$(getopt -o -h -l no-config -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while [ -n "${1:-}" ]; do
    case "$1" in
        --no-config) NO_CONFIG=1 ; shift ;;
        --) shift ;;
        *) break ;;
    esac
done

pushd "${HOME}/openstack/ardana/ansible"

if [ -z "$NO_CONFIG" ]; then
    ansible-playbook -i hosts/localhost \
        config-processor-run.yml -e encrypt="" -e rekey="" 2>&1 |
      tee ${HOME}/config-processor-run.log
fi

ansible-playbook -i hosts/localhost ready-deployment.yml 2>&1 |
  tee ${HOME}/ready-deployment.log
