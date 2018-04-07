#!/bin/bash
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
# This script is CI'd and is supported to be used by developers.
#

set -eux
set -o pipefail

eval "$($(dirname "$(readlink -e "${BASH_SOURCE[0]}")")/ardana-env)"

SCRIPT_NAME=$(basename $0)
SCRIPT_HOME=$(cd $(dirname $0) ; pwd)

usage() {
    set +x
    echo "$SCRIPT_NAME [--ci] [--no-setup] [--no-build] [cloud]"
    echo
    echo "NOTE: cloud defaults to dac-min"
    echo
    echo "Note that if the --project-stack is specified then the concept of"
    echo "the cloud changes. By default we pull the input model from"
    echo "ardana-input-model, but when --project-stack is set we always copy"
    echo "the control plane from the specified project. This cloud uses"
    echo "the 'project' ardana-input-model as a bases."
    echo
    echo "--no-setup            -- Don't run dev-env-install.yml"
    echo "--no-artifacts        -- Don't download artifacts or build vagrant,"
    echo "                         guest or OVA images"
    echo "--no-build            -- Don't build venv, reuse existing packages"
    echo "--no-git-update       -- Don't update git cached sources"
    echo "--pre-destroy         -- Destroy any existing instance of the cloud"
    echo "                         before deploying."
    echo "--disable-no-log      -- Remove no_log entries from ansible code"
    echo "                         before deploying to make debugging easier."
    echo "--c8|--cloud8-deployer"
    echo "                      -- Use Cloud8 deployer setup"
    echo "--c8-hos              -- Enable HPE Helion OpenStack Cloud mode"
    echo "--c8-soc              -- Enable SUSE OpenStack Cloud mode (default)"
    echo "--c8-caching          -- Enable caching proxy, running on Cloud8"
    echo "                         deployer, that will be used to access all"
    echo "                         non-local repos (default if mirroring not"
    echo "                         enabled)"
    echo "--c8-mirror           -- Enable local mirroring of repos"
    echo "--c8-staging          -- Use staging (DC8S), updates & pool repos"
    echo "                         (default)"
    echo "--c8-devel            -- Use devel (DC8), updates & pool repos"
    echo "--c8-updates-test     -- Use updates-test, updates & pool repos"
    echo "--c8-updates          -- Use updates & pool repos"
    echo "--c8-pool             -- Use pool repo only"
    echo "--c8-artifacts|cloud8-artifacts"
    echo "                      -- Use Cloud8 artifacts"
    echo "--rhel                -- Include any RHEL artifacts"
    echo "--rhel-compute        -- Switch compute nodes to use rhel"
    echo "--rhel-compute-nodes nodes"
    echo "                      -- Colon separated list of nodes to be setup"
    echo "                         as RHEL computes. (repeatable)"
    echo "--sles                -- Include any SLES artifacts"
    echo "--sles-control        -- Switch control nodes to use sles"
    echo "--sles-control-nodes nodes"
    echo "                      -- Colon separated list of nodes to be setup"
    echo "                         as SLES controllers. (repeatable)"
    echo "--sles-compute        -- Switch compute nodes to use sles"
    echo "--sles-compute-nodes nodes"
    echo "                      -- Colon separated list of nodes to be setup"
    echo "                         as SLES computes. (repeatable)"
    echo "--sles-deployer       -- Switch deployer node to use sles"
    echo "                         (deprecated - deployer will use whichever"
    echo "                         distro is used for control plane."
    echo "--guest-images        -- Include any guest image artifacts"
    echo "--tarball TARBALL     -- Specify a prebuilt deployer tarball to use."
    echo "--cobble-nodes nodes  -- Specify a list of nodes to re-image with cobbler"
    echo "                         before running the Ardana OpenStack deployment."
    echo "--cobble-rhel-nodes nodes"
    echo "                      -- Specify a list of nodes to configured as RHEL"
    echo "                         if being re-imaged by cobbler."
    echo "--cobble-sles-nodes nodes"
    echo "                      -- Specify a list of nodes to configured as SLES"
    echo "                         if being re-imaged by cobbler."
    echo "--cobble-all-nodes    -- Cobble all but the deployer nodes"
    echo "--no-config           -- Do not execute the config-processor"
    echo "--no-site             -- Do not execute the site.yml playbook during"
    echo "                         deployment"
    echo "--update-only         -- Just update the git sources"
    echo "--ci                  -- Sets the same options for running in the CI"
    echo "                         CDL lab."
    echo "--run-tests           -- Run tests after deployment"
    echo "--disable-services    -- Disable specified services"
    echo "--project-stack       -- The stack (cloud etc) will be customized for"
    echo "                         this project, using files in the specified"
    echo "                         project's ardana-ci directory, e.g."
    echo "                         --project-stack ardana/glance-ansible"
    echo "--feature-dir dir     -- Add in an additional feature to be tested during"
    echo "                         deployment. This may be specified multiple times."
    echo "--no-prepare          -- Don't run the preparation steps for feature dirs"
    echo "--restrict-by-project -- Specify a project to test. This restricts the number"
    echo "                         of services we run in the cloud based on the project"
    echo "                         we set here. CI sets this value via the environmental"
    echo "                         value 'ZUUL_PROJECT'"
    echo "--squashkit           -- Specify a kit to compare this against for squashing. You"
    echo "                         probable don't need to run this."
    echo "--extra-vars          -- Pass extra vars to any locally run playbooks"
}

ORIGINAL_ARGUMENTS=$@

# Set variables
source $SCRIPT_HOME/lib/astack_options.sh

set -x

source $SCRIPT_HOME/libci.sh

feature_prepare() {
    local FEATURE_SCRIPT="$1"
    local FEATURE
    for FEATURE in $FEATURE_DIRS
    do
        if [ -e "$FEATURE/$FEATURE_SCRIPT" ]; then
            ansible-playbook \
                "$FEATURE/$FEATURE_SCRIPT"
        fi
    done
}

feature_ansible() {
    local FEATURE_SCRIPT="$1"
    local DEPLOYER_NODE=$(get_deployer_node)
    local FEATURE
    for FEATURE in $FEATURE_DIRS
    do
        if [ -e "$FEATURE/$FEATURE_SCRIPT" ]; then
            ansible-playbook -i "$DEVTOOLS/ansible/hosts/vagrant.py" \
                "$FEATURE/$FEATURE_SCRIPT" \
                --limit "$DEPLOYER_NODE"
        fi
    done
}

if [ -n "${ARDANA_DISABLE_SERVICES:-}" -a -n "${USE_PROJECT_STACK:-}" ]; then
    echo "Combining --disable-services and --project-stack isn't allowed." >&2
    exit 1
fi

if [ -n "$UPDATE_ONLY" ]; then
    if [ "${ARDANA_GIT_UPDATE:-}" = "no" ]; then
        echo "Running update-only with ARDANA_GIT_UPDATE turned off. This doesn't make sense."
        echo "Turning git update on"
        export ARDANA_GIT_UPDATE=yes
    fi
    ansible-playbook -i $DEVTOOLS/ansible/hosts/localhost \
        $DEVTOOLS/ansible/get-venv-sources.yml
    ansible-playbook -i $DEVTOOLS/ansible/hosts/localhost \
        $DEVTOOLS/ansible/get-ansible-sources.yml
    # We are only updating the git sources so exit now
    exit 0
fi

# Cloud based configuration
if [ -n "$USE_PROJECT_STACK" ]; then
    CLOUDNAME=project
    PROJECT_CLOUD=${1:-project}
else
    CLOUDNAME=${1:-dac-min}
fi

# For a CI run of the "standard" cloud we ensure that the
# third compute is RHEL.
if [ -n "$CI" -a "$CLOUDNAME" = "standard" ]; then
    # Ensure we build RHEL artifacts
    export ARDANA_RHEL_ARTIFACTS=1

    if [[ -n "${COBBLER_ENABLED:-}" ]]; then
        # Test cobbler re-imaging of the 3rd compute
        COBBLER_RHEL_NODES="${COBBLER_RHEL_NODES:+${COBBLER_RHEL_NODES}:}COMPUTE-0003"
    else
        # Test RHEL compute deploy & upgrade
        export ARDANA_RHEL_COMPUTE_NODES="${ARDANA_RHEL_COMPUTE_NODES:+${ARDANA_RHEL_COMPUTE_NODES}:}COMPUTE-0003"
    fi
fi

# Check for upgrade flags disabling RHEL or SLES support
if [[ -n "$ARDANA_UPGRADE_NO_RHEL" ]]
then
    unset ARDANA_RHEL_ARTIFACTS
    unset ARDANA_RHEL_OPTIONAL_REPO_ENABLED
    unset ARDANA_RHEL_COMPUTE
    unset ARDANA_RHEL_COMPUTE_NODES
fi
if [[ -n "$ARDANA_UPGRADE_NO_SLES" ]]
then
    unset ARDANA_SLES_ARTIFACTS
    unset ARDANA_SLES_CONTROL
    unset ARDANA_SLES_CONTROL_NODES
    unset ARDANA_SLES_COMPUTE
    unset ARDANA_SLES_COMPUTE_NODES
fi

# Enable ardana centos rpm repo support on RHEL required for nova computes.
# Flag is enabled when one or more RHEL compute is present in deployment.
if [ -n "${ARDANA_RHEL_OPTIONAL_REPO_ENABLED:-}" ]; then
    _centos_repo_feature=$DEVTOOLS/ardana-ci/features/enable-centos-rpms-on-rhel
    if [ -d "$_centos_repo_feature" ]; then
        if ! echo "$FEATURE_DIRS" | grep -qs "/$(basename "$_centos_repo_feature")\>"; then
            FEATURE_DIRS="$FEATURE_DIRS $_centos_repo_feature"
        fi
    fi
fi


installsubunit
logsubunit --inprogress total

# Setup
if [ -z "$NO_SETUP" ]; then
    logsubunit --inprogress setup
    devenvinstall || logfail setup
    logsubunit --success setup
fi

clouddir="$DEVTOOLS/ardana-vagrant-models/${CLOUDNAME}-vagrant"
if [ ! -d "$clouddir" ]; then
    echo "$clouddir not found" >&2; exit 1
fi

# Deploy and configure your cloud
pushd $clouddir

if [ -n "$USE_PROJECT_STACK" ]; then
    # Assume this project is actually checked out
    base_project_files="$SCRIPT_HOME/../../$(basename $USE_PROJECT_STACK)/ardana-ci"
    project_files="${base_project_files}/$PROJECT_CLOUD"
    project_input_model="${project_files}/input-model"

    if [ ! -e $project_input_model ]; then
        echo "Project files for $USE_PROJECT_STACK do not exist.

** Please implement the service side of this job **

Exiting successfully." >&2
        exit 0
    fi

    servers="$project_input_model/data/servers.yml"
    if [ -e $servers ]; then
        export ARDANA_SERVERS=$servers
    fi

    if [ -e "$project_files/astack-options" ]; then
        # We have defined some default astack options for the cloud
        #
        # Reload the astack_options to set any variables defined there. This
        # reload the variables based on the options defined in this file and
        # potentially overridden by any of the arguments passed in by the
        # developer.
        set -- $(cat "$project_files/astack-options") $ORIGINAL_ARGUMENTS

        source $SCRIPT_HOME/lib/astack_options.sh
    fi

    if [ -x "$project_files/pre-project-stack-start" ]; then
        $project_files/pre-project-stack-start
    fi
fi

# setup vagrant boxes
if [ -z "${NO_ARTIFACTS:-}" ]; then
    $SCRIPT_HOME/build-distro-artifacts
fi

# Build
if [ -z "$NO_BUILD" -a -z "$DEPLOYER_TARBALL" ]; then
    logsubunit --inprogress build
    # artifacts should already have been build so skip
    $SCRIPT_HOME/build-venv.sh \
        ${CI:+--ci} \
        ${ARDANA_CLOUD8_ARTIFACTS:+--cloud8} \
        ${ARDANA_RHEL_ARTIFACTS:+--rhel} \
        ${ARDANA_SLES_ARTIFACTS:+--sles} \
        --no-artifacts \
        --stop || logfail build
    logsubunit --success build
fi

if [ -n "$SQUASH_KIT" ]; then
    branchdir=$(get_branch_path)
    scratchdir="scratch-$branchdir"
    kitiso="$HOME/.cache-ardana/$branchdir/artifacts/$SQUASH_KIT"
    url=$(dirname $(cat ${kitiso}.source))

    kitcleanup() {
        sudo umount $kittmp || true
        rm -fr $kittmp
        trap - SIGHUP SIGINT SIGTERM EXIT
    }
    kittmp=$(mktemp -d)
    trap kitcleanup SIGHUP SIGINT SIGTERM EXIT

    sudo mount $kitiso $kittmp

    kittar=$(ls $kittmp/ardana/*.tar)
    kittararray=( $kittar )
    if [ ${#kittararray[@]} -ne 1 ]; then
        echo "Failed to find the kit deployertarball from the kit in $url" >&2
        exit 1
    fi

    # Produce venv_report.yaml
    python $SCRIPT_HOME/../isogen/venv_diff_report.py \
        --verbose \
        --report $DEVTOOLS/venv_report.yaml \
        $kittmp \
        $DEVTOOLS/$scratchdir

    # Squash venv packages in scratch area based on report
    python $SCRIPT_HOME/../isogen/venv_squash_tool.py \
        --report $DEVTOOLS/venv_report.yaml \
        --previousurl $url \
        $kittmp $DEVTOOLS/$scratchdir $ARTIFACTS_FILE

    kitcleanup
fi

# Run any preparation step for features
if [ -n "$FEATURE_PREPARE" ]; then
    feature_prepare prepare-artifacts.yml
fi

if [ -n "${PRE_DESTROY:-}" ]; then
    $SCRIPT_HOME/deploy-vagrant-destroy || logfail pre-destroy
    logsubunit --inprogress pre-destroy
fi

# Bring up vagrant VM's
$SCRIPT_HOME/deploy-vagrant-up || logfail deploy
logsubunit --inprogress deploy

generate_ssh_config "FORCE"

if [[ -n "${ARDANA_CLOUD8_DEPLOYER:-}" ]]; then
    # ensure we have up-to-date input model sources if not using
    # a locally cloned ardana-input-model
    ansible-playbook -i $DEVTOOLS/ansible/hosts/localhost \
        $DEVTOOLS/ansible/get-input-model-sources.yml

    # setup the cloud8 nodes using a similar process to how
    # the customer would in a real deployment
    ansible-playbook -i $DEVTOOLS/ansible/hosts/vagrant.py \
        $DEVTOOLS/ansible/cloud8-setup.yml \
        -e "{\"deployer_node\": \"$(get_deployer_node)\"}"
fi

# Run any feature hooks between ardana-init.bash and initialising the input model
feature_ansible post-ardana-init.yml

if [[ ( -n "$COBBLER_ALL_NODES" ) || ( -n "$COBBLER_NODES" ) ]]; then
    # Edit the servers.yml file on deployer to configure specified distros
    $SCRIPT_HOME/run-in-deployer.sh \
        $SCRIPT_HOME/deployer/add-distros.py \
            -- \
            --default-distro=sles \
            ${COBBLER_NODES:+--nodes="${COBBLER_NODES:-}"} \
            ${COBBLER_RHEL_NODES:+--rhel-nodes=${COBBLER_RHEL_NODES:-}} \
            ${COBBLER_SLES_NODES:+--sles-nodes=${COBBLER_SLES_NODES:-}} \
            ${COBBLER_RHEL_COMPUTE:+--rhel-compute} \
            ${COBBLER_SLES_COMPUTE:+--sles-compute} \
            ${COBBLER_SLES_CONTROL:+--sles-control} \
            $CLOUDNAME
fi

# Init the model
$SCRIPT_HOME/run-in-deployer.sh \
    "$SCRIPT_HOME/deployer/init-input-model.sh" "$CLOUDNAME" || logfail deploy

# If using Provo site, use different ntp server
if [ "${ARDANA_SITE:-provo}" = "provo" ]; then
    $SCRIPT_HOME/run-in-deployer.sh \
        "$SCRIPT_HOME/deployer/fix-ntp-server.sh" "$CLOUDNAME" || logfail deploy
fi

# If --project-stack is set then modify the input model appropriately.
if [ -n "$USE_PROJECT_STACK" ]; then
    # Copy and commit the project input model
    scp -F $ARDANA_VAGRANT_SSH_CONFIG -r $project_input_model/* \
        $(get_deployer_node):~/openstack/my_cloud/definition/ || logfail deploy
    $SCRIPT_HOME/run-in-deployer.sh \
        $SCRIPT_HOME/deployer/commit-changes.sh \
        "Update project-stack input-model from $USE_PROJECT_STACK" || logfail deploy

    if [ -e "$base_project_files/tests" ]; then
        scp -F $ARDANA_VAGRANT_SSH_CONFIG -r $base_project_files/tests \
            $(get_deployer_node):~/ardana-ci-tests
    fi
fi
logsubunit --inprogress deploy

if [ -n "${ARDANA_RHEL_OPTIONAL_REPO_ENABLED:-}" ]; then
    ansible-playbook -i $DEVTOOLS/ansible/hosts/vagrant.py \
        $DEVTOOLS/ansible/upload-rhel-centos-tarball-to-deployer.yml \
        -e "{\"deployer_node\": \"$(get_deployer_node)\"}"
fi

# Run any feature hooks between initialising the input model and running CP
feature_ansible post-commit.yml

# If --project-stack is set then don't try and restrict the number of services down.
# This would likely cause confusion about and potentially disable services from a service
# teams stack.
if [ -z "$USE_PROJECT_STACK" ]; then
    # This script modifies and exports the ARDANA_DISABLE_SERVICES variable
    # if appropriate.
    # TODO(fergal) - re-enable restrict-services.sh once dependency chains
    #                have been revised.
    #source $SCRIPT_HOME/lib/restrict-services.sh

    if [ -n "${ARDANA_DISABLE_SERVICES:-}" ]; then
        # Takes the services to disable as arguments
        $SCRIPT_HOME/run-in-deployer.sh \
            "$SCRIPT_HOME/deployer/disable-services.sh" \
            "${ARDANA_DISABLE_SERVICES:-}" || logfail deploy
    fi
fi

if [ -z "${SKIP_EXTRA_PLAYBOOKS}" -o -n "$COBBLER_NODES" \
     -o -n "$COBBLER_ALL_NODES" ]; then
    # If requested via arguments, upload the distro ISOs to the deployer
    ansible-playbook -i $DEVTOOLS/ansible/hosts/vagrant.py \
        $DEVTOOLS/ansible/upload-distro-isos-to-deployer.yml \
        -e "{\"deployer_node\": \"$(get_deployer_node)\"}"

    $SCRIPT_HOME/run-in-deployer.sh \
        "$SCRIPT_HOME/deployer/cobbler-deploy.sh" "$ARDANAUSER" || logfail deploy
    logsubunit --inprogress deploy
fi

# Re-image any nodes with cobbler
if [ -n "${COBBLER_NODES}" -o -n "$COBBLER_ALL_NODES" ] ; then
    if [ -n "${COBBLER_NODES}" ]; then
        export ARDANA_COBBLER_NODES="$COBBLER_NODES"
    fi
    $SCRIPT_HOME/vagrant-set-pxe-on $CLOUDNAME || logfail deploy
    $SCRIPT_HOME/vagrant-check-power-off $CLOUDNAME || logfail deploy
    $SCRIPT_HOME/vagrant-set-pxe-off $CLOUDNAME || logfail deploy
    $SCRIPT_HOME/vagrant-check-power-on $CLOUDNAME || logfail deploy
    logsubunit --inprogress deploy
fi

# Check for --no-log-disable mode
if [ -n "$NO_LOG_DISABLE" ]; then
    # Remove no_log entries
    $SCRIPT_HOME/run-in-deployer.sh \
        "$SCRIPT_HOME/deployer/remove-no_log-entries.sh" || logfail deploy
fi

if [ -z "$NO_CONFIG" ]; then
    # Configure the cloud
    $SCRIPT_HOME/run-in-deployer.sh \
        "$SCRIPT_HOME/deployer/config-cloud.sh" || logfail deploy
fi
logsubunit --inprogress deploy

# Run any feature hooks between running CP and deploying
feature_ansible post-config-processor.yml

if [ -z "$NO_SITE" ]; then
    # Continue to deploy the cloud, run site.yml
    # Always run 1 more fork so that if localhost is included in
    # the group, there is sufficient numbers.
    forks=$(( $(vagrant --machine-readable status | \
        awk -F, '/provider-name/ {print $2}' | wc -l) + 1)) || logfail deploy
    $SCRIPT_HOME/run-in-deployer.sh \
        "$SCRIPT_HOME/deployer/deploy-cloud.sh" \
            "${forks}" "${HTTP_PROXY:-${http_proxy:-}}" || logfail deploy
fi

# Run any feature hooks after deploying
feature_ansible post-deploy.yml

# Upload guest images to Glance
if [ -n "$ARDANA_GUEST_IMAGE_ARTIFACTS" ] ; then
   $SCRIPT_HOME/run-in-deployer.sh \
        "$SCRIPT_HOME/deployer/upload-guest-images.sh" || logfail deploy
fi

# Generate package manifest
if [ -z "${COBBLER_NODES}" -a -z "$COBBLER_ALL_NODES" ] ; then
    ansible-playbook -i $DEVTOOLS/ansible/hosts/vagrant.py \
            $DEVTOOLS/ansible/get-pkg-manifest.yml
fi

popd

# Connect deployer to external network
pushd $DEVTOOLS/ansible
case "$CLOUDNAME" in
    "mid-size")
        EXTRAARGS='-e {"dev_env_ext_net":{"bridge_ip":"169.254.1.1","netmask":["172.31.0.1/16"],"vlan":"3367"}}';
        ROUTEEXTRAARGS='';;
    "multi-cp")
        EXTRAARGS='-e {"dev_env_ext_net":{"bridge_ip":"169.254.1.1","netmask":["172.31.0.1/16","172.32.0.1/16","172.33.0.1/16"],"vlan":"103"}}';
        ROUTEEXTRAARGS='-e {"dev_env_provider_net":{"bridge_ip":"192.168.245.1","octavia_net":[{"netmask":"172.30.1.1/24","vlan":"106"},{"netmask":"172.30.3.1/24","vlan":"107"}]}}';;
    *)
        EXTRAARGS='';
        ROUTEEXTRAARGS='';;
esac

ansible-playbook -i hosts/localhost dev-env-connect-deployer-to-extnet.yml $EXTRAARGS |
  tee ${WORKSPACE:-$PWD}/dev-env-connect-deployer-to-extnet.log || logfail deploy

# Enable routing between management and neutron provider network.
# This is needed for octavia.
ansible-playbook -i hosts/localhost dev-env-route-provider-nets.yml $ROUTEEXTRAARGS || logfail deploy

popd

# Finished the deployment, log success
logsubunit --success deploy

if [ -n "$RUN_TESTS" -a -z "$USE_PROJECT_STACK" ]; then
    test_args=""
    if [ -n "$CI" ]; then
        test_args="--ci"
    fi

    pushd "${DEVTOOLS}/ardana-vagrant-models/${CLOUDNAME}-vagrant"
    ${SCRIPT_HOME}/run-in-deployer.sh ${SCRIPT_HOME}/deployer/run-tests.sh ${test_args} ci ${CLOUDNAME}
    popd
fi

# vim:shiftwidth=4:tabstop=4:expandtab
