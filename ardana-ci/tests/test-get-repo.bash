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

REPO=${1:-ardana/keystone-ansible}
REPONAME=$(basename $REPO)

SCRIPT_HOME=$(readlink -e $(dirname $0))
CLONE_DIR=$(readlink -e $SCRIPT_HOME/../../..)
DEVTOOLS=$(readlink -e $CLONE_DIR/ardana-dev-tools)
SCRATCH_DIR=$DEVTOOLS/scratch-$(git config -f $DEVTOOLS/.gitreview gerrit.defaultbranch | tr '/' '_')
BUILD_SOURCES=$SCRATCH_DIR/build-sources.json

# we use the command line jq tool to parse the BUILD_SOURCES and extract
# out the info for the repo in question, either from the venvs or the ansible
JQ_FILTER='if .venvs | has("'$REPONAME'") then .venvs["'$REPONAME'"] elif .ansible | has("'$REPONAME'") then .ansible["'$REPONAME'"] else null end'
_jq_check_log=$(mktemp /tmp/.jq_filter_check_log.XXXXXXXX)

if [[ ! -r $BUILD_SOURCES ]]; then
    echo 1>&2 "ERROR: Missing $BUILD_SOURCES file; did you run the dump-sources.yml play?"
    exit 1
elif ! jq "$JQ_FILTER" $BUILD_SOURCES >$_jq_check_log 2>&1; then
    echo "Content of $BUILD_SOURCES:"
    cat $BUILD_SOURCES
    echo 1>&2 "ERROR: Failed to parse $BUILD_SOURCES"
    cat $_jq_check_log
    rm -f $_jq_check_log
    exit 1
elif [[ "$(jq "$JQ_FILTER" $BUILD_SOURCES)" == "null" ]]; then
    echo 1>&2 "ERROR: Not a venv or ansible source repo: $REPO"
    exit 1
fi

# query results are quoted so assign them using eval so that quoting
# is handled appropriately.
eval "branch=$(jq "$JQ_FILTER | .branch" $BUILD_SOURCES)"
eval "url=$(jq "$JQ_FILTER | .url" $BUILD_SOURCES)"

if [ ! -e "$CLONE_DIR/$REPONAME" ]; then
    git clone -b $branch $(dirname $(dirname $url))/$REPO $CLONE_DIR/$REPONAME
fi
