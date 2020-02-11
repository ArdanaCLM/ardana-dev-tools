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
# Must be in an ardana-vagrant-models/<cloud>-vagrant directory or
# the cloud-vagrant symlink must exist and point to a valid model's
# vagrant directory.
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
        --ci) export ARDANAUSER=${ARDANAUSER:-ardana} ; shift ;;
        --) shift ; break ;;
        *) break ;;
    esac
done

source $SCRIPT_HOME/libci.sh
ensure_in_vagrant_dir $SCRIPT_NAME

deployscript="$1"
shift

script="/home/$ARDANAUSER/$(basename $deployscript)"
${SCRIPT_HOME}/ardana-scp $deployscript deployer:$script

vagrant_data_on_error "${SCRIPT_HOME}/ardana-ssh -t deployer $script $@"
