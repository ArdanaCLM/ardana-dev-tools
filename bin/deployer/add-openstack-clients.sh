#!/bin/bash
#
# (c) Copyright 2016-2017 Hewlett Packard Enterprise Development LP
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
#

set -eux
set -o pipefail

pushd "$HOME/openstack/my_cloud/definition/data/"

clients=(openstack-client
ceilometer-client
cinder-client
designate-client
glance-client
heat-client
ironic-client
keystone-client
magnum-client
neutron-client
nova-client
swift-client
monasca-client
barbican-client)

# Add all clients to the deployer node even if they are already listed.
for file in control_plane* ; do
    for client in ${clients[@]}; do
        echo $client
        # Find the definition for the deployer.
        if grep -qE '\- +lifecycle-manager$' $file ; then
            sed -i "s/\(^ *\- \+\)\(lifecycle-manager\)\$/\1\2\n\1$client/" $file
        fi
    done
done

if test -n "$(git status --porcelain)" ; then
    git add -A
    git commit -m "Added all openstack clients to the input model"
fi
