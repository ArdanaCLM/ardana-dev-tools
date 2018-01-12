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
# This script is CI'd and is supported to be used by developers.
#

set -eux
set -o pipefail

eval "$($(dirname "$(readlink -e "${BASH_SOURCE[0]}")")/ardana-env)"

SCRIPT_NAME=$(basename $0)
SCRIPT_HOME=$(cd $(dirname $0) ; pwd)

usage() {
    set +x
    echo "$SCRIPT_NAME [--ci] [cloud]"
    echo
    echo "Run an upgrade test from a 'recent' build kit."
    echo "See $SCRIPT_HOME/run-upgrade --help"
    echo
    echo "--ci                  -- Set options for running in the cdl"
    echo "--restrict-by-project -- See astack.sh --help"
}

TEMP=$(getopt -o -h -l help,ci,restrict-by-project: -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

CI=
ARGS=

while true ; do
    case "$1" in
        -h | --help) usage ; exit 0 ;;
        --ci)
            export ARDANAUSER=ardanauser
            CI=yes
            shift;;
        --restrict-by-project) ARGS="${ARGS}${ARGS:+' '}$2" ; shift 2 ;;
        --) shift ; break;;
        *) break ;;
    esac
done

set -x

$SCRIPT_HOME/run-upgrade --kit recent.iso ${CI:+--ci} $ARGS $*
