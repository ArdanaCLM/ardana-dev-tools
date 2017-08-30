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
# This script is CI'd and is supported to be used by developers.
#

set -eux
set -o pipefail

SCRIPT_NAME=$(basename $0)
SCRIPT_HOME=$(cd $(dirname $0) ; pwd)

usage() {
    set +x
    echo "$SCRIPT_NAME venv [playbook]"
    echo
    echo "This script (optionally) builds the venv package 'venv'"
    echo "Copies the package to the correct location on the deployer."
    echo "Updates the appropriate index, and then runs any (or none)"
    echo "user specified playbooks."
    echo
    echo "--no-build     -- Use the latest existing venv package otherwise"
    echo "                  we build a new package"
    echo "--rhel         -- build any specific RHEL venv package"
    echo "--sles         -- build any specific SLES venv package"
    echo "--no-artifacts -- Don't check and fetch any new artifacts including"
    echo "                  any necessary vagrant images."
    echo "--no-checkout  -- Skip checking out all the source repositories"
    echo "--rebuild      -- Rebuild the venv package"
    echo "--stop         -- Destroy the build VM's after successfully building"
    echo "                  the specified package."
}

copy_venv_to_deployer()
{
  scratch=$1
  DEPLOYER_PATH=$2

  latest_venv=$(ls -tr $scratch/$PACKAGE*.tgz | tail -1)
  latest_venv_name=$(basename $latest_venv)

  deployer=$(get_deployer_node)

  scp -F $ARDANA_VAGRANT_SSH_CONFIG $latest_venv $deployer:~/$latest_venv_name
  ssh -F $ARDANA_VAGRANT_SSH_CONFIG $deployer sudo cp \~/$latest_venv_name $DEPLOYER_PATH
  ssh -F $ARDANA_VAGRANT_SSH_CONFIG $deployer sudo /opt/stack/service/packager/venv/bin/create_index --dir $DEPLOYER_PATH
}

NO_BUILD=
VENV_ARGS=
RHEL=
SLES=

TEMP=$(getopt -o h -l help,ci,no-config,no-build,rhel,sles,no-artifacts,no-checkout,rebuild,stop -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -h | --help) usage ; exit 0 ;;
        --ci) export ARDANAUSER=ardanauser ; shift ;;
        --no-build) NO_BUILD=1 ; shift ;;
        --rhel) RHEL=1 ; shift ;;
        --sles) SLES=1 ; shift ;;
        --no-artifacts|--no-checkout|--rebuild|--stop)
            VENV_ARGS="$VENV_ARGS $1"
            shift ;;
        --) shift ; break ;;
        *) break ;;
    esac
done

set -x

if [ -z "${1:-}" ]; then
    usage
    exit 1
fi

PACKAGE=$1
PLAYBOOK="${2:-}"

source $SCRIPT_HOME/libci.sh
ensure_in_vagrant_dir $SCRIPT_NAME

ARDANA_VERSION=$(python -c "import yaml ; print yaml.load(open('../../ansible/roles/product/defaults/main.yml'))['product_name_version']")
DEPLOYER_PATH=/opt/ardana_packager/$ARDANA_VERSION/hlinux_venv

export ARDANA_HLINUX_ARTIFACTS=
if [ -z "$RHEL" -a -z "$SLES" ]; then
    export ARDANA_HLINUX_ARTIFACTS=1
fi

if [ -z "$NO_BUILD" ]; then
    $SCRIPT_HOME/build-venv.sh ${RHEL:+--rhel} ${SLES:+--sles} $VENV_ARGS $PACKAGE
fi

generate_ssh_config

branch=$(git config --file $(git rev-parse --show-toplevel)/.gitreview \
    --get gerrit.defaultbranch | tr '/' '_')
scratch="$SCRIPT_HOME/../scratch-$branch"
copy_venv_to_deployer $scratch $DEPLOYER_PATH
if [ -n "$SLES" ]; then
    DEPLOYER_PATH=/opt/ardana_packager/$ARDANA_VERSION/sles_venv
    scratch="$SCRIPT_HOME/../scratch-$branch/suse"
    copy_venv_to_deployer $scratch $DEPLOYER_PATH
fi
if [ -n "$RHEL" ]; then
    DEPLOYER_PATH=/opt/ardana_packager/$ARDANA_VERSION/rhel_venv
    scratch="$SCRIPT_HOME/../scratch-$branch/redhat"
    copy_venv_to_deployer $scratch $DEPLOYER_PATH
fi

if [ -n "$PLAYBOOK" ]; then
    $SCRIPT_HOME/run-in-deployer.sh \
        $SCRIPT_HOME/deployer/run-in-scratch.sh $PLAYBOOK
fi
