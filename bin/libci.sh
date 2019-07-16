#
# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
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
export DEVTOOLS=$(cd $(dirname ${BASH_SOURCE[0]})/.. ; pwd)
export DEVROOT=$(readlink -e ${DEVTOOLS}/..)
export LOGSROOT="${WORKSPACE:-${DEVROOT}}/logs"
export ARDANA_OSC_CACHE="${HOME}/.cache/ardana-osc"
export ARDANA_OVERRIDE_RPMS="${WORKSPACE:-${DEVROOT}}/C${ARDANA_CLOUD_VERSION:-9}_NEW_RPMS"
PS4='+${BASH_SOURCE/$HOME/\~}@${LINENO}(${FUNCNAME[0]}):'

export ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-${DEVTOOLS}/ansible/ansible.cfg}"

# CDL convention
cfg=/etc/profile.d/proxy.sh
if [ -e $cfg ] ; then
    source $cfg
fi

# Validated ansible-playbook to use.
export PATH=$DEVTOOLS/tools/venvs/ansible/bin/:$PATH
export EXTRA_VARS=${EXTRA_VARS:-}
if [ -n "$EXTRA_VARS" ]; then
    shopt -s expand_aliases
    alias ansible-playbook="ansible-playbook -e '$EXTRA_VARS'"
fi

export ANSIBLE_LOG_PATH=${LOGSROOT}/vm_host_ansible.log
# Prevent ssh host key errors
export ANSIBLE_HOST_KEY_CHECKING=False

export PYTHONUNBUFFERED=1

# Used in run-lint.bash
export GOZER_GIT_MIRROR=${GOZER_GIT_MIRROR:-https://gerrit.prv.suse.net}
export PYPI_MIRROR_URL=${PYPI_MIRROR_URL:-http://${PYPI_BASE_HOST:-pypi.ci.prv.suse.net}/openstack/latest}

# Default to using an ardana user, with home directory /var/lib/ardana
# which can be overriden by setting up these environment variables
# before we source this file.
export ARDANAUSER=${ARDANAUSER:-ardana}
export ARDANA_USER_HOME_BASE=${ARDANA_USER_HOME_BASE:-/var/lib}

export VAGRANT_LOG_DIR="${LOGSROOT}/vagrant"
export CONSOLE_LOG_DIR="${LOGSROOT}/console"
export CP_LOG_DIR="${LOGSROOT}/configProcessor"
[[ ! -d "${VAGRANT_LOG_DIR}" ]] && mkdir -p "${VAGRANT_LOG_DIR}"
[[ ! -d "${CONSOLE_LOG_DIR}" ]] && mkdir -p "${CONSOLE_LOG_DIR}"
[[ ! -d "${CP_LOG_DIR}" ]] && mkdir -p "${CP_LOG_DIR}"

export VAGRANT_DEFAULT_PROVIDER=libvirt

export ARDANA_SUBUNIT_VENV=$DEVTOOLS/tools/venvs/subunit
export ARDANA_RUN_SUBUNIT_OUTPUT=${WORKSPACE:-$PWD}/ardanarun.subunit

export ARDANA_CLOUD_SSH_CONFIG="astack-ssh-config"
export ARDANA_VAGRANT_SSH_CONFIG="vagrant-ssh-config"
export ARDANA_ASTACK_ENV=".astack_env"

export ARTIFACTS_FILE=$DEVTOOLS/artifacts-list.txt


devenvinstall() {
    local STATUS
    pushd $DEVTOOLS/ansible
    ansible-playbook -i hosts/localhost dev-env-install.yml
    STATUS=$?
    # clear out hashed executables to pick up anything installed
    hash -r
    popd
    return $STATUS
}

reporttimeout() {
    local STATUS=$?
    if [ $STATUS -eq 124 ]; then
        # Make it easy to search in ELK for timeouts
        echo "*** TIMEOUT RUNNING $1 ***"
    fi

    return $STATUS
}

installsubunit() {
    if [ -n "$CI" ]; then
        if [ ! -d $ARDANA_SUBUNIT_VENV ]; then
            virtualenv $ARDANA_SUBUNIT_VENV
            timeout 2m $ARDANA_SUBUNIT_VENV/bin/pip install --upgrade pip wheel || reporttimeout "pip install --upgrade pip wheel"
            timeout 2m $ARDANA_SUBUNIT_VENV/bin/pip install "setuptools<34.0.0" || reporttimeout "pip install setuptools<34.0.0"
        fi

        if [ ! -x $ARDANA_SUBUNIT_VENV/bin/subunit-output ]; then
            timeout 2m $ARDANA_SUBUNIT_VENV/bin/pip install python-subunit || reporttimeout "pip install python-subunit"
        fi

        mkdir -p $(dirname $ARDANA_RUN_SUBUNIT_OUTPUT)
        rm -f $ARDANA_RUN_SUBUNIT_OUTPUT
    fi
}

logsubunit() {
    if [ -n "$CI" ]; then
        local status="$1"
        local testid="ardanarun.$2"
        $ARDANA_SUBUNIT_VENV/bin/subunit-output $status $testid >> $ARDANA_RUN_SUBUNIT_OUTPUT
    fi
}

# CMD1 &&CMD2 && ... || logfail testid [status]
logfail() {
    # Must be the first line to capture status or else we have to pass it in
    local STATUS=${2:-$?}
    if [ -n "$CI" ]; then
        logsubunit --fail "$1"
    fi
    exit $STATUS
}

# timeout 10s || logtimeoutfail testid
logtimeoutfail() {
    local STATUS=$?
    if [ $STATUS -eq 124 ]; then
        # Make it easy to search in ELK for timeouts
        echo "*** TIMEOUT RUNNING $1 ***"
    fi

    logfail $1 $STATUS
}

ensure_in_vagrant_dir() {
    local caller="${1:-$(basename $0)}"

    if [ ! -f Vagrantfile ]; then
        echo "$caller must be run in directory containing Vagrantfile" >&2
        exit 1
    fi

    case "${PWD}" in
    (*/ardana-vagrant-models/*-vagrant|*/build-vagrant)
        # all good
        ;;
    (*)
        cat 1>&2 << _EOF_
${caller} must be run either from within a <cloud>-vagrant subdirectory
under the ardana-dev-tools/ardana-vagrant-models, or from within the
ardana-dev-tools/build-vagrant directory.
_EOF_
        exit 1
        ;;
    esac

    if ! grep -q "/ardana_vagrant_helper.rb" Vagrantfile; then
        echo "Vagrantfile in this directory doesn't look like the right kind." >&2
        exit 1
    fi
}

ensure_astack_env_exists()
{
    if [[ ! -e "${ARDANA_ASTACK_ENV}" ]]; then
        echo "No ${ARDANA_ASTACK_ENV} found; has this cloud been initialised?" >&2
        exit 1
    fi
}

# Generate the .astack_env file
generate_astack_env()
{
    ensure_in_vagrant_dir generate_astack_env

    if [ \( ! -e ${ARDANA_ASTACK_ENV} \) -o \( -n "${1:-}" \) ]; then
        export -p | \
            grep -e "^declare -x \(ANSIBLE\|ARDANA\|ARTIFACTS_FILE\|CI\|DEVROOT\|DEVTOOLS\|VAGRANT\)" | \
            sed  -e 's,-x \([^=]*\)="\(.*\)"$,-x \1="${\1:-\2}",g' \
            > ${ARDANA_ASTACK_ENV}
    fi
}

# Generate the ssh-config file
# Requires the environmental variable VAGRANT_LOG_DIR to be set
generate_ssh_config() {
    ensure_in_vagrant_dir generate_ssh_config

    if [ ! -e ${ARDANA_VAGRANT_SSH_CONFIG} -o -n "${1:-}" ]; then
        local log="${VAGRANT_LOG_DIR}/${ARDANA_VAGRANT_SSH_CONFIG}.log"
        vagrant --debug ssh-config 2>>"$log" >${ARDANA_VAGRANT_SSH_CONFIG}.new
        local status=$?
        if [ $status != 0 ]; then
            echo "vagrant ssh-config failed; check $log" >&2
        else
            mv ${ARDANA_VAGRANT_SSH_CONFIG}.new $ARDANA_VAGRANT_SSH_CONFIG
            generate_astack_env
        fi
        return $status
    fi
}

get_deployer_node() {
    ensure_in_vagrant_dir get_deployer_node
    awk '/^deployer_node/ {gsub(/\"/,"",$3);print $3}' Vagrantfile
}

get_branch() {
    pushd $DEVTOOLS >/dev/null
    local branch=$(cat $(git rev-parse --show-toplevel)/.gitreview | awk -F= '/defaultbranch/ { print $2 }')
    popd >/dev/null

    echo $branch
}

get_branch_path() {
    echo $(get_branch) | tr '/' '_'
}

# gather debug data on vagrant env failures
gather_data() {
    printf "Dump vagrant status, ethX PCI addresses, ip addresses, link traffic stats, routes, neighbors, iptables, bridge, virsh data\n"
    vagrant status
    vagrant global-status
    n_devices="$(netstat -ia | grep -e "^eth" | wc -l)"
    for i in $(seq 0 $((${n_devices}-1)))
    do
        sudo ethtool -i eth${i} | grep -e bus-info
    done
    ip address
    ip -s link
    ip route
    ip neighbour show
    sudo iptables -L -n -v
    sudo iptables -t nat -L -n -v
    brctl show
    sudo virsh net-list
    machines=$(vagrant --machine-readable status | \
        awk -F, '/provider-name/ {print $2}')
    printf "Machines: ${machines}\n"
    for machine in ${machines} ; do
        printf "\nmachine $machine data:\n"
        cmd='
set -x
n_devices="$(netstat -ia | grep -e "^eth" | wc -l)"
for i in $(seq 0 $((${n_devices}-1)))
do
    sudo ethtool -i eth${i} | grep -e bus-info
done
ip address
ip -s link
ip route
ip neighbour show
sudo ovs-vsctl show
sudo brctl show
'
        vagrant ssh -c "$cmd" $machine
    done
    for vm in $(sudo virsh list --all --name) ; do
        printf "\nvm $vm configuration:\n"
        sudo virsh dumpxml $vm
    done
}

gather_data_on_error() {
    local cmd="$1"
    local err_log=$2
    if eval "${cmd}" ; then
        return 0
    fi
    if set -o | grep -q '^errexit[[:space:]]*on' ; then
        set +o errexit
        local setflag=true
    fi
    printf "\n'$cmd' failed\n"
    gather_data > ${err_log} 2>&1
    [[ -n "${setflag}" ]] && set -o errexit
    return 1
}

vagrant_data_on_error() {
    local cmd="$@"
    if test -z "${CI:-}" ; then
        eval $cmd
    else
        gather_data_on_error "$cmd" "${VAGRANT_LOG_DIR}/deploy-vagrant-setup-fail.log"
    fi
}

# vim:shiftwidth=4:tabstop=4:expandtab
