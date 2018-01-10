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

set -eu
set -o pipefail
set -x

eval "$($(dirname "$(readlink -e "${BASH_SOURCE[0]}")")/ardana-env)"

SCRIPT_NAME=$(basename $0)
SCRIPT_HOME=$(cd $(dirname $0) ; pwd)

usage() {
    set +x
    echo "$SCRIPT_NAME [ARGS] SCRIPT [SCRIPT_ARGS...]"
    echo
    echo "Run SCRIPT on the deployer passing in any arguments "
}

TEMP=$(getopt -o h -l help,ci -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -h | --help) usage ; exit 0 ;;
        --ci) export ARDANAUSER=ardanauser ; shift ;;
        --) shift ; break ;;
        *) break ;;
    esac
done

source $SCRIPT_HOME/libci.sh
ensure_in_vagrant_dir $SCRIPT_NAME

deployscript="$1"
shift

DEPLOYERNODE="$(get_deployer_node)"

generate_ssh_config

script="/home/$ARDANAUSER/$(basename $deployscript)"
scp -F $ARDANA_VAGRANT_SSH_CONFIG $deployscript $DEPLOYERNODE:$script

vagrant_data_on_error "ssh -F $ARDANA_VAGRANT_SSH_CONFIG $ARDANAUSER@$DEPLOYERNODE $script $@"
