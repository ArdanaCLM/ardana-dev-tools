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
# Remove no_log entries from Ansible code base to make debugging easier.
#

set -eux
set -o pipefail

pushd "${HOME}/openstack/ardana/ansible"

grep -ril "^ *no_log: *true$" | xargs sed -i -e "/^ *no_log: *[Tt]rue$/d"

git add -A
git commit --allow-empty -m "Remove no_log entries"
