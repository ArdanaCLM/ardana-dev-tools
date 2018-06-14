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
    echo "$SCRIPT_NAME [--ci] [--no-setup] [--no-build] [--skip-deploy] [cloud]"
    echo
    echo "Deploy cloud and immediately follow up by running the ardana-upgrade.yml"
    echo "playbooks with the same version of everything."
    echo
    echo "--skip-deploy         -- Assume we have a working cloud and just run"
    echo "                         the upgrade script and skip the initial"
    echo "                         call to 'astack.sh'"
    echo "--no-setup            -- See astack.sh --help"
    echo "--no-build            -- See astack.sh --help"
    echo "--restrict-by-project -- See astack.sh --help"
}

TEMP=$(getopt -o -h -l help,ci,no-setup,no-build,restrict-by-project:,skip-deploy -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

CI=
ARGS=
SKIP_DEPLOY=

echo $*

while true ; do
    echo "$1 & ${2:-}"
    case "$1" in
        -h | --help) usage ; exit 0 ;;
        --ci)
            export ARDANAUSER=${ARDANAUSER:-ardana}
            export CI=yes
            ARGS=" $1"
            shift ;;
        --no-setup|--no-build) ARGS="${ARGS}${ARGS:+ }$1" ; shift ;;
        --restrict-by-project) ARGS="${ARGS}${ARGS:+ }$1 $2" ; shift 2 ;;
        --skip-deploy) SKIP_DEPLOY=1 ; shift ;;
        --) shift ; break;;
        *) break ;;
    esac
done

set -x

# Start running in parallel
cloud=${1:-multi-cp}

if [ -z "$SKIP_DEPLOY" ]; then
    # Deploy the system
    $SCRIPT_HOME/astack.sh $ARGS $cloud
fi

# Uppgrade to ourself
pushd $SCRIPT_HOME/../ardana-vagrant-models/${cloud}-vagrant
# Log onto the deployer and run the appropriate upgrade playbooks
$SCRIPT_HOME/run-in-deployer.sh $SCRIPT_HOME/deployer/run-upgrade.sh
