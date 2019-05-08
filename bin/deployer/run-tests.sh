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

SCRIPT_NAME=$(basename $0)

usage() {
    set +x
    echo "$SCRIPT_NAME [--timeout] JOB_TYPE CLOUD_NAME [TAGS]"
}

TEMP=$(getopt -o h -l help,tempest-only,timeout:,no-ironic -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

# The overall test time available (in minutes)
TEST_TIMEOUT=240
NO_IRONIC=

while true ; do
    case "$1" in
        -h|--help) usage ; exit 0 ;;
        --timeout) TEST_TIMEOUT=$2 ; shift 2 ;;
        --no-ironic) NO_IRONIC=1 ; shift ;;
        # option retained for backwards compatibility
        --tempest-only) shift ;;
        --) shift ; break;;
        *) break ;;
    esac
done

source ~/service.osrc

# Same ordering as test-artifacts
ARDANA_CLOUD_NAME="${2:?ARDANA_CLOUD_NAME must be specified}"
JOB_TYPE="${1:?JOB_TYPE must be specified}"
if [[ "$JOB_TYPE" == "canary" ]]; then
    RUN_FILTER="smoke"
else
    RUN_FILTER="$JOB_TYPE"
fi
TAGS=${3:-$RUN_FILTER}

# Tempest timeout is 75% of TEST_TIMEOUT (in seconds)
TEMPEST_TIMEOUT=$((TEST_TIMEOUT / 4 * 3 * 60))
ANSIBLE_NEXT="${HOME}/scratch/ansible/next/ardana/ansible"

pushd "${ANSIBLE_NEXT}"

# Setup the deployer so it can access API endpoints.
export PYTHONUNBUFFERED=1

ansible-playbook \
    -i hosts/verb_hosts \
    cloud-client-setup.yml
source /etc/environment

# Flush all caches across all of the nodes
echo "Flushing all page & inode caches across all nodes"
ansible \
    -b \
    -i hosts/verb_hosts \
    resources \
    -m shell \
    -a "sync; echo 3 > /proc/sys/vm/drop_caches; sync"

# Run Keystone sanity check
openstack token issue

# Run tempest and timeout after 30min
ansible-playbook \
    -i hosts/verb_hosts \
    tempest-run.yml \
    -e run_filter=${RUN_FILTER} \
    -e ssh_timeout=600 \
    -e tempest_timeout_secs=$TEMPEST_TIMEOUT \
    ${NO_IRONIC:+ --limit "!tempest_cp-bm-region3"} \
    -e tempest_test_axis=control_plane
popd

echo "Completed tempest tests successfully; finishing now."

# vim:shiftwidth=4:tabstop=4:expandtab
