#!/bin/bash
#
# (c) Copyright 2015 Hewlett Packard Enterprise Development LP
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
set -u
set -o pipefail

eval "$($(dirname "$(readlink -e "${BASH_SOURCE[0]}")")/ardana-env)"

SCRIPT_NAME=$(basename $0)
SCRIPT_HOME=$(cd $(dirname $0) ; pwd)

function show_options () {
    echo "Usage: $SCRIPT_NAME [options]"
    echo
    echo "Get stats on the number of zuul merge failures occurring"
    echo
    echo "Options:"
    echo "    -h                -- this help"
    echo "    -p                -- port in use by gerrit server"
    echo "    -a                -- the age of reviews to look at"
    echo "    -s                -- gerrit server to retrieve changes from"
    echo
    exit $1
}

TEMP=$(getopt -o ha:p:s:t: -l help,age:,port:,server:test-data: -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

gerrit_server="gerrit.suse.provo.cloud"
gerrit_port="29418"
age="1h"
test_data=

while true ; do
    case "$1" in
        -h|--help) show_options 0 >&2;;
        -a|--age) age=$2; shift 2;;
        -p|--port) gerrit_port=$2; shift 2;;
        -s|--server) gerrit_server=$2; shift 2;;
        -t|--test-data) test_data=$2; shift 2;;
        --) shift ; break ;;
        *) echo "Error: unsupported option $1." >&2 ; show_options 1 >&2 ;;
    esac
done

# Setup how we send commands to gerrit
gerrit_cmd="ssh ${gerrit_server}${gerrit_port:+ -p}${gerrit_port} gerrit"
if [[ -n "${test_data}" ]]; then
    if [[ -s "${test_data}" ]]; then
        gerrit_output="$(cat "$test_data")"
    else
        echo "Error: test-data specified is not a file greater than 0 bytes." >&2
        show_options 1 >&2
    fi
fi

# Query gerrit for the changes to check
get_repo_changes() {
    # Cache the result of the query
    if [[ -z "${gerrit_output:-}" ]]; then
        local gerrit_output="$(${gerrit_cmd} query "NOT age:${age} " \
            --current-patch-set --format json --comments)"
    fi
    # The output is a number of json objects for each review, and a stats object
    # Turn it into an array of changes
    echo "$gerrit_output" | jq -s "map(select(.type != \"stats\"))"
}

# Get all changes for repo
changes="$(get_repo_changes)"

# Get total number of changes
num_changes="$(echo $changes | jq "length")"
echo "Total number of changes returned: ${num_changes}"

# Get number of changes with at least one merge failed comment
merge_failed_changes="$(echo $changes | jq ".[]" | jq -s 'map(select(.comments[].message | contains("\n\nMerge Failed.\n\nThis change was unable to be automatically merged with the current state of the repository. Please rebase your change and upload a new patchset.")))' 2>/dev/null)"
num_failed_changes="$(echo $merge_failed_changes | jq "unique | length")"
echo "Total number of failed changes returned: ${num_failed_changes}"
echo "Percentage of failed changes returned: $(expr 100 \* ${num_failed_changes} / ${num_changes})%"
echo

# Get max/min/ave of Merge failed comments per patch set
# a by-product of the select is that each merge failure is an entry in
# the array generated into merge_failed_changes
# So all we do is count each number
echo $merge_failed_changes | jq -r .[].number | awk '
    {
        freq[$0]++
        total++
    }
    END {
        min=999 ; max=0
        for (i in freq) {
            if (freq[i] > max) {
                max=freq[i]
            }
            if (freq[i] < min) {
                min=freq[i]
            }
        }
        printf("Total number of merge failures  :%6d\n", total)
        printf("Minimum number of merge failures:%6d\n", min)
        printf("Maximum number of merge failures:%6d\n", max)
        printf("Average number of merge failures:%6.2f\n", total/length(freq))
    }
'
