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

set -eux
set -o pipefail

REPO=${1:-ardana/keystone-ansible}
REPONAME=$(basename $REPO)

SCRIPT_HOME=$(cd $(dirname $0) ; pwd)
DEVTOOLS=$(cd $SCRIPT_HOME/../../.. ; pwd)

pushd $SCRIPT_HOME
branch=$(cat $(git rev-parse --show-toplevel)/.gitreview |
    awk -F= '/defaultbranch/ { print $2 }')
url=$(git config --get remote.origin.url)
popd

if [ ! -e "$DEVTOOLS/$REPONAME" ]; then
    git clone -b $branch $(dirname $(dirname $url))/$REPO $DEVTOOLS/$REPONAME
fi
