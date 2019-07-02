#!/bin/bash
#
# (c) Copyright 2019 SUSE LLC
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
# Utility functions for interacting with the deployer
#
#
# Run the setup_deployer_utils() function, passing in the name of
# the cloud being worked on to setup the runtime environment for
# the functions in this library.

setup_deployer_utils()
{
    declare -g _libdu_vagrant_dir _libdu_ssh_opts
    declare -g ANSIBLE_FORCE_COLOR VAGRANT_FORCE_COLOR
    local cloud_name="${1}" lib_dir="$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"

    _libdu_vagrant_dir="$(readlink -e "${lib_dir}/../../ardana-vagrant-models")/${cloud_name}-vagrant"

    if [[ ! -d "${_libdu_vagrant_dir}" ]]
    then
        echo "ERROR: Invalid cloud name '${cloud_name}'."
        exit 1
    fi

    if [[ -t 1 ]]
    then
        _libdu_ssh_opts="-t"
        export ANSIBLE_FORCE_COLOR=True
        export VAGRANT_FORCE_COLOR=True
    else
        _libdu_ssh_opts=
    fi
}

deployer_ssh()
{
    ssh -F ${_libdu_vagrant_dir}/astack-ssh-config ${_libdu_ssh_opts} deployer "${@}"
}

deployer_scp()
{
    local dest="${1}"

    shift

    scp -F ${_libdu_vagrant_dir}/astack-ssh-config "${@}" deployer:"${dest}"
}

deployer_run()
{
    local script_path="${1}" script_name script_dest script_cmd

    shift

    script_name="$(basename "${script_path}")"
    script_dest="./${script_name}"
    script_cmd="${script_dest} ${@}"

    deployer_scp "${script_dest}" "${script_path}"

    deployer_ssh "${script_cmd}"
}

ardana_deployer_run_playbook()
{
    local node="${1}" pb="${2}" pd="${3}"

    if [[ "${node:-}" == "all" ]]
    then
        node=""
    fi

    shift 3

    echo "***** [ Running '${pd}/${pb}' ${node:+ limited to '${node}'} on deployer ] *****"
    deployer_ssh \
        "cd ${pd} && \
         ansible-playbook ${pb}.yml \
            ${node:+--limit ${node}} \
             ${@}"
}

ardana_openstack_run_playbook()
{
    local node="${1}" pb="${2}"

    shift 2

    ardana_deployer_run_playbook \
        "${node}" \
        "${pb}" \
        "~ardana/openstack/ardana/ansible" \
        "${@}"
}

ardana_scratch_run_playbook()
{
    local node="${1}" pb="${2}"

    shift 2

    ardana_deployer_run_playbook \
        "${node}" \
        "${pb}" \
        "~ardana/scratch/ansible/next/ardana/ansible" \
        "${@}"
}

ardana_scratch_update_status()
{
    local node="${1}"

    shift

    ardana_scratch_run_playbook "${node}" ardana-update-status "${@}"
}

deployer_needs_update()
{
    ardana_scratch_update_status deployer 2>&1 | grep "ardana-update.yml"
}

deployer_needs_reboot()
{
    ardana_scratch_update_status deployer 2>&1 | grep "ardana-reboot.yml"
}

# vim:shiftwidth=4:tabstop=4:expandtab
