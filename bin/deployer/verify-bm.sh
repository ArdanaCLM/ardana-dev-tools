#!/bin/bash

# (c) Copyright 2019 SUSE LLC
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

SCRIPT_NAME=$(basename $0)

export PYTHONUNBUFFERED=1
# Note: This must _NOT_ go into the default ansible config.
export ANSIBLE_MAX_FAIL_PERCENTAGE=0

WIPE_DISKS=

TEMP=$(getopt -o -h -l wipe-disks -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while [ -n "${1:-}" ]; do
    case "$1" in
        --wipe-disks) WIPE_DISKS=1 ; shift ;;
        --) shift ;;
        *) break ;;
    esac
done

cd "${HOME}/scratch/ansible/next/ardana/ansible"

# To support validating fix for bsc#1110061 we need to
# clear out known_hosts of all but localhost entries
ssh-keyscan localhost > ${HOME}/.ssh/known_hosts

# The VMs may not be up yet so we need to retry. We can't handle this in
# the playbook because the set of nodes is determined by Ansible and we
# don't have access to the list of unreachable nodes (ttbomk) in our tasks.
set +e
n=0
until (( n > 9 ))
do
    ansible-playbook \
        -i hosts/verb_hosts \
        bm-verify.yml 2>&1 |
      tee ${HOME}/bm-verify.log
    retval=$?
    if (( $retval == 0 )) ; then
        break
    fi
    (( n++ ))
    sleep 30
done
set -e

if (( ${retval:-0} != 0 )) ; then
    exit $retval
fi

if [[ -n "${WIPE_DISKS:-}" ]]; then
    # To support validating fix for bsc#1110061 we need to
    # clear out known_hosts of all but localhost entries
    ssh-keyscan localhost > ${HOME}/.ssh/known_hosts
    ansible-playbook \
        -i hosts/verb_hosts \
        wipe_disks.yml \
            -e automate=True 2>&1 |
    tee ${HOME}/wipe_disks.log
    retval=$?
fi

exit ${retval}

# vim:shiftwidth=4:tabstop=4:expandtab
