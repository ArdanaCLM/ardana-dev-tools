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
# Runs in the deployer.
#

set -eux
set -o pipefail

export PYTHONUNBUFFERED=1
# Note: This must _NOT_ go into the default ansible config.
export ANSIBLE_MAX_FAIL_PERCENTAGE=0

pushd "${HOME}/scratch/ansible/next/ardana/ansible"

# When found, upload the non legacy guest image to glance

IMAGE=${HOME}/*-image-x86_64*.rpm

if [ -f $IMAGE ]; then
    ansible-playbook  -i hosts/verb_hosts \
        service-guest-image.yml -e service_package=${IMAGE} 2>&1 |
      tee ${HOME}/service-guest-image.log
fi
