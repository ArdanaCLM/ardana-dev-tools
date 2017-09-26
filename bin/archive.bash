#!/bin/bash
#
# (c) Copyright 2015-2016 Hewlett Packard Enterprise Development LP
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
# Called by CI
#
# Parse the artifacts file and copy all listed files to location to be
# uploaded to Gozer static server by Jenkins in the ardana-artifact-publisher
#

set -eux
set -o pipefail

source $(dirname $0)/libci.sh

if [ -z "$WORKSPACE" ] ; then
    echo "ERROR: WORKSPACE environment variable must be set"
    exit 1
fi

# DEST is read by Jenkins ardana-artifact-publisher which copies
# all files to Gozer static.
DEST=$WORKSPACE/artifacts

if [ ! -e $ARTIFACTS_FILE ] ; then
    # No artifacts to store. This happens during CI.
    exit 0
fi

while read line ; do
    data=( $line )
    type=${data[0]}
    branch=${data[1]}
    version=${data[2]}
    filename=${data[3]} # must be absolute
    name=$(basename $filename)

    # We are generating URL from the branch so swap /'s with -'s
    branch=$(echo $branch | sed -e 's,/,-,g')

    mkdir -p $DEST/$type/$branch/$version
    cp $filename $DEST/$type/$branch/$version/$name
done < $ARTIFACTS_FILE
