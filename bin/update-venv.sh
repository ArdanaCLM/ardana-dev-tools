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
    echo "--hlinux       -- Build venv package for hLinux"
    echo "--rhel         -- Build venv package for RHEL"
    echo "--sles         -- Build venv package for SLES"
    echo "--no-artifacts -- Don't check and fetch any new artifacts including"
    echo "                  any necessary vagrant images."
    echo "--no-checkout  -- Skip checking out all the source repositories"
    echo "--rebuild      -- Rebuild the venv package"
    echo "--stop         -- Destroy the build VM's after successfully building"
    echo "                  the specified package."
}

copy_venv_to_deployer()
{
  scratch_dir=$1
  deployer_path=$2
  package=$3

  latest_venv=$(ls -tr $scratch_dir/$package*.tgz | tail -1)
  latest_venv_name=$(basename $latest_venv)

  deployer=$(get_deployer_node)

  scp -F $ARDANA_VAGRANT_SSH_CONFIG $latest_venv $deployer:~/$latest_venv_name
  ssh -F $ARDANA_VAGRANT_SSH_CONFIG $deployer sudo cp \~/$latest_venv_name $deployer_path
  ssh -F $ARDANA_VAGRANT_SSH_CONFIG $deployer sudo mkdir $deployer_path
  ssh -F $ARDANA_VAGRANT_SSH_CONFIG $deployer sudo /opt/stack/service/packager/venv/bin/create_index --dir $deployer_path
}

distros=()
venv_args=()
NO_BUILD=

TEMP=$(getopt -o h -l help,ci,no-config,no-build,hlinux,rhel,sles,no-artifacts,no-checkout,rebuild,stop -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

while true ; do
    case "$1" in
        (-h|--help) usage ; exit 0 ;;
        (--ci) export ARDANAUSER=ardanauser ; shift ;;
        (--no-build) NO_BUILD=1 ; shift ;;
        (--hlinux|--rhel|--sles)
            distros+=( ${1:2} )
            venv_args+=( $1 )
            shift ;;
        (--no-artifacts|--no-checkout|--rebuild|--stop)
            venv_args+=( $1 ); shift ;;
        (--) shift ; break ;;
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

# select default distro if none specified
if (( ${#distros[@]} == 0)); then
    # TODO(fergal): switch to sles as default
    distros=( hlinux )
fi

if [ -z "$NO_BUILD" ]; then
    $SCRIPT_HOME/build-venv.sh "${venv_args[@]}" $PACKAGE
fi

if ! generate_ssh_config; then
    echo "Aborting" >&2
    exit 1
fi

branch=$(git config --file $(git rev-parse --show-toplevel)/.gitreview \
    --get gerrit.defaultbranch | tr '/' '_')

# paths under scratch dir where distro venvs are located
declare -A distro_dirs
distro_dirs["hlinux"]=""
distro_dirs["rhel"]="redhat"
distro_dirs["sles"]="suse"

for distro in ${distros[@]}
do
    copy_venv_to_deployer \
        "$SCRIPT_HOME/../scratch-$branch/${distro_dirs[$distro]}" \
        /opt/ardana_packager/$ARDANA_VERSION/${distro}_venv \
        $PACKAGE
done

if [ -n "$PLAYBOOK" ]; then
    $SCRIPT_HOME/run-in-deployer.sh \
        $SCRIPT_HOME/deployer/run-in-scratch.sh $PLAYBOOK
fi
