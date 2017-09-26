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
# Tempest was added as a service in 4.0 time frame. It was not a service
# before this release so we need to make sure that we add it into the upgrade
# job that would start with a model that didn't deploy tempest as a service.
#

set -eux
set -o pipefail

pushd "$HOME/openstack/my_cloud/definition/data/"

for file in control_plane* ; do
    if grep -qE '\- lifecycle-manager$' $file ; then
        # This is the deployer
        if ! grep -qE '\- tempest$' $file ; then
            # We don't have tempest - add it in
            sed -i 's/\(.*\)\(lifecycle-manager\)$/\1\2\n\1tempest/' $file
        fi
    fi
done

if test -n "$(git status --porcelain)" ; then
    git add -A
    git commit -m "Added tempest as a service to the input model"
fi
