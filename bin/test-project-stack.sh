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

eval "$($(dirname "$(readlink -e "${BASH_SOURCE[0]}")")/ardana-env)"

SCRIPT_NAME=$(basename $0)
SCRIPT_HOME=$(cd $(dirname $0) ; pwd)

usage() {
    set +x
    echo "$SCRIPT_NAME [--ci] project"
    echo
    echo "Execute the test plan from project in the minimal cloud"
    echo
}

TEMP=$(getopt -o -h -l help,ci -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -h | --help) usage ; exit 0 ;;
        --ci) export ARDANAUSER=ardanauser ; shift ;;
        --) shift ; break;;
        *) break ;;
    esac
done

set -x

source $SCRIPT_HOME/libci.sh

ensure_in_vagrant_dir $SCRIPT_NAME

if [ -z "${1:-}" ]; then
    echo "Please specify a project to find the test-plan.yaml from" >&2
    exit 1
fi
project=$(basename $1)

base_project_files="$SCRIPT_HOME/../../$project/ardana-ci"
if [ ! -e "$base_project_files" ]; then
    echo "Project files for $project do not exist.

** Please implement the service side of this job **

Exiting successfully." >&2
    exit 0
fi

# Assume that the astack-ssh-config is uptodate
generate_ssh_config

test_plan="$base_project_files/tests/test-plan.yaml"

DEPLOYERNODE="$(get_deployer_node)"

project_tests="$base_project_files/tests"
rsync -rav -e "ssh -F $ARDANA_VAGRANT_SSH_CONFIG" \
    $project_tests/* \
    $DEPLOYERNODE:~/ardana-ci-tests

python $SCRIPT_HOME/lib/exec-test-plan.py \
    --ssh-config $ARDANA_VAGRANT_SSH_CONFIG \
    $test_plan
