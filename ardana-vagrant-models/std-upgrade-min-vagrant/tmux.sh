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
cmd_dir="$(dirname "$(readlink -e ${0})")"
ssh_conf="${cmd_dir}/astack-ssh-config"

astack_ssh="ssh -F ${ssh_conf}"
astack_nodes=( $(grep "^Host" "${ssh_conf}" | awk '{print $2}') )
session="astack"

${DEBUG:+echo} tmux new -d -s "${session}" -n "${astack_nodes[0]}" "${astack_ssh} ${astack_nodes[0]}"
for node in "${astack_nodes[@]:1}"
do
    ${DEBUG:+echo} tmux neww -n "${node}" "${astack_ssh} ${node}"
done

${DEBUG:+echo} tmux select-window -t :0
${DEBUG:+echo} tmux attach -d -t "${session}"

exit 0
