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

# This can be used to test the .deb squashing script "create_dpkg_diff_list.py"

set -eu
set -o pipefail

SCRIPT_HOME=$(cd $(dirname $0) ; pwd)

USAGE="$0 <old iso> <new iso> <output delta iso>"

if [ -z "${1:-}" -o -z "${2:-}" -o -z "${3:-}" ]; then
    echo $USAGE
    exit 1
fi

source $SCRIPT_HOME/../bin/libci.sh

OLDISO=$1
NEWISO=$2
OUTPUT_ISO=$3

# From create_iso.sh
ISOGEN=$(dirname $(readlink -f $0))
OUTPUT=$ISOGEN/output
DEVTOOLS=$(cd $(dirname $0)/.. ; pwd)

cleanup() {
    [ "${NO_CLEANUP:-}" ] && return

    sudo umount $MOUNT_POINT_OLD || true
    sudo umount $MOUNT_POINT_NEW || true

    sudo rm -fr $TEMP
    trap - SIGHUP SIGINT SIGTERM EXIT
}

TEMP=$(mktemp -d /tmp/iso_deb_diff.XXXX)
trap cleanup SIGHUP SIGINT SIGTERM EXIT

MOUNT_POINT_OLD=$TEMP/old
MOUNT_POINT_NEW=$TEMP/new
DPKGKIT=$TEMP/dpkgkit
FINALKIT=$TEMP/newkit

mkdir -p $MOUNT_POINT_OLD
mkdir -p $MOUNT_POINT_NEW

sudo mount $OLDISO $MOUNT_POINT_OLD
sudo mount $NEWISO $MOUNT_POINT_NEW

python $ISOGEN/create_dpkg_diff_list.py \
    --report $TEMP/kitdiffs.yaml \
    $MOUNT_POINT_OLD \
    $MOUNT_POINT_NEW \
    --action squash \
    --outputdir $DPKGKIT

if [ ! -e $DEVTOOLS/venv_report.yaml ]; then
    branchdir=$(get_branch_path)
    scratchdir="scratch-$branchdir"
    python $ISOGEN/venv_diff_report.py \
        --verbose \
        --report $DEVTOOLS/venv_report.yaml \
        $MOUNT_POINT_OLD \
        $DEVTOOLS/$scratchdir
fi

python $ISOGEN/venv_delta_iso.py \
    --report $DEVTOOLS/venv_report.yaml \
    --outputdir $FINALKIT \
    $DPKGKIT

$ISOGEN/write_iso.sh $OUTPUT_ISO $FINALKIT
