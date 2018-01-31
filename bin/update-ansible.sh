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
# This script is CI'd and is supported to be used by developers.
#

set -eux
set -o pipefail

eval "$($(dirname "$(readlink -e "${BASH_SOURCE[0]}")")/ardana-env)"

SCRIPT_NAME=$(basename $0)
SCRIPT_HOME=$(cd $(dirname $0) ; pwd)

usage() {
    set +x
    echo "$SCRIPT_NAME ansible-repo [playbook]"
    echo
    echo "This copies the specified locally checked out ansible"
    echo "repo onto the deployer and into the ~/openstack git repository."
    echo "It commits the changes to this repository and runs"
    echo "config-processor-run.yml and ready-deployment.yml"
    echo "playbooks to setup the ~/scratch area correctly."
    echo
    echo "Next we optionally run the specified playbook"
    echo
    echo "This most be run from within the vagrant directory"
}

NO_CONFIG=

TEMP=$(getopt -o -h -l help,ci,no-config -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

while true ; do
    case "$1" in
        -h | --help) usage ; exit 0 ;;
        --ci) export ARDANAUSER=ardanauser ; shift ;;
        --no-config) NO_CONFIG=--no-config ; shift ;;
        --) shift ; break ;;
        *) break ;;
    esac
done

set -x

if [ -z "${1:-}" ]; then
    usage
    exit 1
fi

ANSIBLE_REPO=$(basename $1)
PLAYBOOK="${2:-}"

source $SCRIPT_HOME/libci.sh

rsync -rav -e "ssh -F $ARDANA_VAGRANT_SSH_CONFIG" --exclude=ardana-ci \
    $SCRIPT_HOME/../../$ANSIBLE_REPO/* \
    $(get_deployer_node):~/openstack/ardana/ansible

$SCRIPT_HOME/run-in-deployer.sh \
    $SCRIPT_HOME/deployer/commit-changes.sh \
    "Update $ANSIBLE_REPO from host machine"
$SCRIPT_HOME/run-in-deployer.sh $SCRIPT_HOME/deployer/config-cloud.sh -- $NO_CONFIG

if [ -n "$PLAYBOOK" ]; then
    $SCRIPT_HOME/run-in-deployer.sh \
        $SCRIPT_HOME/deployer/run-in-scratch.sh $PLAYBOOK
fi
