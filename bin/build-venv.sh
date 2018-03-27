#!/bin/bash
#
# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
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
#
# Called by CI
#

set -eux
set -o pipefail

eval "$($(dirname "$(readlink -e "${BASH_SOURCE[0]}")")/ardana-env)"

SCRIPT_NAME=$(basename $0)
SCRIPT_HOME=$(cd $(dirname $0) ; pwd)

usage() {
    set +x
    echo "$SCRIPT_NAME [--help] [--ci] [--rhel] [--sles] [--stop] [packages...]"
    echo
    echo "Manage all aspects of the venv building."
    echo "This includes downloading any needed artifacts, building vargant"
    echo "box images, bringing up the build VM's, and finally building any"
    echo "or all venv packages."
    echo
    echo "--rhel         -- Build venv packages for RHEL"
    echo "--sles         -- Build venv packages for SLES"
    echo "--cloud8       -- Use Cloud8 artifacts during venv build"
    echo "--no-artifacts -- Don't fetch any required artifacts, assume we"
    echo "                  have them already."
    echo "--no-checkout  -- Don't checkout any git sources, assume we have"
    echo "                  them already."
    echo "--rebuild      -- Rebuild the venv package."
    echo "--stop         -- Destroy the build VM's after successfully building"
    echo "                  the specified packages."
}

TEMP=$(getopt -o h -l help,ci,cloud8,rhel,sles,no-artifacts,no-checkout,rebuild,stop -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

DO_STOP=
NO_ARTIFACTS=
NO_CHECKOUT=
ARDANA_FORCE_VENV_REBUILD=${ARDANA_FORCE_VENV_REBUILD:-}

while true ; do
    case "$1" in
        -h | --help) usage ; exit 0 ;;
        --ci) export ARDANAUSER=ardanauser ; shift ;;
        --cloud8) export ARDANA_CLOUD8_ARTIFACTS=1 ; shift ;;
        --rhel) export ARDANA_RHEL_ARTIFACTS=1 ; shift ;;
        --sles) export ARDANA_SLES_ARTIFACTS=1 ; shift ;;
        --no-artifacts) NO_ARTIFACTS=1 ; shift ;;
        --no-checkout) NO_CHECKOUT=1 ; shift ;;
        --rebuild) ARDANA_FORCE_VENV_REBUILD=1 ; shift ;;
        --stop) DO_STOP=1 ; shift ;;
        --) shift ; break ;;
        *) break ;;
    esac
done

# select a default distro if none specified
if [ -z "${ARDANA_RHEL_ARTIFACTS:-}" -a \
     -z "${ARDANA_SLES_ARTIFACTS:-}" ]; then
    export ARDANA_SLES_ARTIFACTS=1
fi

source "$(dirname $0)/libci.sh"

jpackages=

if [ $# -gt 0 ]; then
    jpackages='{"packages": []}'
    for package in $* ; do
        jpackages=$(echo $jpackages | jq ".packages=.packages + [\"$package\"]")
    done
fi

if [ -z "$NO_ARTIFACTS" ]; then
    $SCRIPT_HOME/build-distro-artifacts
fi

if [ -z "$NO_CHECKOUT" ]; then
    # Get the venv repos.
    ansible-playbook -i $DEVTOOLS/ansible/hosts/localhost \
        $DEVTOOLS/ansible/get-venv-sources.yml ${jpackages:+-e "$jpackages"}
fi

pushd "$DEVTOOLS/build-vagrant"

$SCRIPT_HOME/deploy-vagrant-up

# Specify the max number of "forks" (parallel host actions) used by
# Ansible during the venv build phase. A large fork factor (>50) may
# help when there are lots of fast CPUs, and a fast, low latency, I/O
# subsystem, e.g. SSD. However this has been found to be unreliable in
# general, and for CI driven testing in particular. For that reason the
# default setting is conservative, though if running in developer mode
# we use the number of system CPUs times three, on the assumption that
# developers are (a) more likely to tolerate infrequent failures and
# try again, (b) will probably have more capable hardware, and (c) will
# likely be using cached wheel builds, so most parallel actions will be
# minimal in nature, and thus not encounter the problem scenarios.

if [ "${ARDANA_ANSIBLE_FORKS:+true}" != "true" ]; then
    if [ "${ARDANA_DEVELOPER:+true}" == "true" ]; then
        ARDANA_ANSIBLE_FORKS=$(( $(nproc) * 3 ))
    else
        ARDANA_ANSIBLE_FORKS=20
    fi
fi

vagrant_data_on_error env ARDANA_SKIP_REPO_CHECKOUT=1 ansible-playbook \
    -f ${ARDANA_ANSIBLE_FORKS} -i ../ansible/hosts/vagrant.py \
    ../ansible/venv-build.yml \
    ${ARDANA_FORCE_VENV_REBUILD:+-e rebuild=True} \
    ${jpackages:+'-e "$jpackages"'}

# halting a vagrant image can introduce a problem where if someone does
# a vagrant up after, it will clear out the /tmp/persistent folder.
[ -z "$DO_STOP" ] || vagrant destroy

exit 0  # The last line can return 1 from the script
