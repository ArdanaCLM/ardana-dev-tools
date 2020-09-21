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
    echo "Usage:"
    echo "    $SCRIPT_NAME [--no-setup] [--no-update-rpms] [--no-build] [cloud]"
    echo
    echo "NOTE: cloud defaults to dac-min"
    echo
    echo "Note that if the --project-stack is specified then the concept of"
    echo "the cloud changes. By default we pull the input model from"
    echo "ardana-input-model, but when --project-stack is set we always copy"
    echo "the control plane from the specified project. This cloud uses"
    echo "the 'project' ardana-input-model as a basis."
    echo
    echo "--debug               -- Generate useful debug output"
    echo "--no-setup            -- Don't run dev-env-install.yml"
    echo "--ansible-sync        -- Enable sync of local ansible sources to the"
    echo "                         deployer openstack/ardana/ansible tree."
    echo "--no-ansible-sync     -- Disable sync of local ansible sources to the"
    echo "                         deployer openstack/ardana/ansible tree."
    echo "                         (default)"
    echo "--no-artifacts        -- Don't download artifacts or build vagrant,"
    echo "                         guest or OVA images"
    echo "--no-update-rpms      -- Don't run updated_rpms.sh to rebuild RPMs"
    echo "--no-git-update       -- Don't update git cached sources"
    echo "--prebuilt-images     -- Download pre-built qcow2 images for use in"
    echo "                         creating Vagrant boxes (default)"
    echo "--prebuilt-version TIMESTAMP"
    echo "                      -- Version timestamp to use for pre-built SLES"
    echo "                         and RHEL qcow2 images."
    echo "--build-images        -- Build qcow2 images locally for use in"
    echo "                         creating Vagrant boxes."
    echo "--enable-mitigations  -- Enable kernel mitigations (e.g. Spectre V2 when"
    echo "                         building qcow2 images; enables --build-images"
    echo "                         implicitly."
    echo "--enable-spectrev2    -- Backwards compat alias for --enable-mitigations"
    echo "--pre-destroy         -- Destroy any existing instance of the Vagrant"
    echo "                         cloud before trying to deploy it."
    echo "--ibs-prj PRJ[/PKG][@DIST]"
    echo "                      -- Specifies an IBS project, and optionally a"
    echo "                         specific package in that project and/or the"
    echo "                         name of the distro repo, defaulting to a"
    echo "                         distro appropriate value, whose RPMs should"
    echo "                         be included into the C<X>_NEW_RPMS (where "
    echo "                         <X> is the Cloud version) area. (repeatable)"
    echo "--ibs-repo PRJ        -- Specify an IBS project to be added to SLES"
    echo "                         nodes as a source for RPMs. (repeatable)"
    echo "--obs-prj PRJ[/PKG][@DIST]"
    echo "                      -- Specifies an OBS project, and optionally a"
    echo "                         specific package in that project and/or the"
    echo "                         name of the distro repo, defaulting to a"
    echo "                         distro appropriate value, whose RPMs should"
    echo "                         be included into the C<X>_NEW_RPMS (where "
    echo "                         <X> is the Cloud version) area. (repeatable)"
    echo "--obs-repo PRJ        -- Specify an OBS project to be added to SLES"
    echo "                         nodes as a source for RPMs. (repeatable)"
    echo "--disable-no-log      -- Remove no_log entries from ansible code"
    echo "                         before deploying to make debugging easier."
    echo "--c9|--cloud9-deployer"
    echo "                      -- Use SOC/CLM 9 deployer setup (default)"
    echo "--c9-staging          -- Use staging (DC9S), updates & pool repos"
    echo "                         (default)"
    echo "--c9-devel            -- Use devel (DC9), updates & pool repos"
    echo "--c9-updates-test     -- Use updates-test, updates & pool repos"
    echo "--c9-updates          -- Use updates & pool repos"
    echo "--c9-pool             -- Use pool repo only"
    echo "--c9-iso              -- Use Cloud9 ISO repo only"
    echo "--c9-milestone MILESTONE"
    echo "                      -- Use specified Cloud9 milestone ISO,"
    echo "                         implicitly enables --c9-iso."
    echo "--c9-artifacts|cloud9-artifacts"
    echo "                      -- Use SOC/CLM 9 artifacts"
    echo "--c8|--cloud8-deployer"
    echo "                      -- Use SOC/CLM 8 deployer setup"
    echo "--c8-hos              -- Enable HPE Helion OpenStack Cloud mode"
    echo "--c8-soc              -- Enable SUSE OpenStack Cloud mode (default)"
    echo "--c8-staging          -- Use staging (DC8S), updates & pool repos"
    echo "                         (default)"
    echo "--c8-devel            -- Use devel (DC8), updates & pool repos"
    echo "--c8-updates-test     -- Use updates-test, updates & pool repos"
    echo "--c8-updates          -- Use updates & pool repos"
    echo "--c8-pool             -- Use pool repo only"
    echo "--c8-iso              -- Use Cloud8 ISO repo only"
    echo "--c8-artifacts|cloud8-artifacts"
    echo "                      -- Use SOC/CLM 8 artifacts"
    echo "--rhel                -- Include any RHEL artifacts"
    echo "--rhel-compute        -- Switch compute nodes to use rhel"
    echo "--rhel-compute-nodes nodes"
    echo "                      -- Colon separated list of nodes to be setup"
    echo "                         as RHEL computes. (repeatable)"
    echo "--sles12sp3           -- Use SLES12 SP3 as the SLES distro"
    echo "--sles12sp4           -- Use SLES12 SP4 as the SLES distro"
    echo "--sles-compute        -- Switch compute nodes to use sles"
    echo "--sles-compute-nodes nodes"
    echo "                      -- Colon separated list of nodes to be setup"
    echo "                         as SLES computes. (repeatable)"
    echo "--cobble-nodes nodes  -- Specify a list of nodes to re-image with cobbler"
    echo "                         before running the Ardana OpenStack deployment."
    echo "--cobble-rhel-nodes nodes"
    echo "                      -- Specify a list of nodes to configured as RHEL"
    echo "                         if being re-imaged by cobbler."
    echo "--cobble-sles-nodes nodes"
    echo "                      -- Specify a list of nodes to configured as SLES"
    echo "                         if being re-imaged by cobbler."
    echo "--cobble-all-nodes    -- Cobble all but the deployer nodes"
    echo "--no-cloud            -- Just setup the environment to be ready to"
    echo "                         deploy specified cloud, but don't bring it"
    echo "                         up or deploy it."
    echo "--no-config           -- Do not execute the config-processor"
    echo "--no-site             -- Do not execute the site.yml playbook during"
    echo "                         deployment"
    echo "--ci                  -- Sets the same options for running in the CI"
    echo "                         CDL lab."
    echo "--run-tests           -- Run tests after deployment"
    echo "--run-tests-filter FILTER"
    echo "                      -- The tempest test filter to use, default 'ci'."
    echo "                         You can see which filters are available to be run"
    echo "                         in the roles/tempest/files/run_filters directory"
    echo "                         under ~/openstack/ardana/ansible or in the"
    echo "                         ardana/tempest-ansible.git repo."
    echo "                         NOTE: This option implies --run-tests also"
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
    echo "--ipv4 NET-INDICES    -- Specify comma sepatared list of net interface indices"
    echo "                         in [0..8] e.g. 0,1,3,5 to indicate that these will"
    echo "                         need an IPv4 address.)"
    echo "--ipv6 NET-INDICES    -- Specify comma sepatared list of net interface indices"
    echo "                         in [0..8] e.g. 0,1,3,5 to indicate that these will"
    echo "                         need an IPv6 address.)"
    echo "--ipv6-all            -- All net interfaces will need an IPv6 address."
    echo "--guest-images        -- Include any guest image artifacts"
    echo "--extra-vars VARS     -- Pass extra vars to any locally run playbooks"
    echo ""
    echo "Deprecated options that have no effect:"
    echo "--c8-mirror|--c9-mirror"
    echo "                      -- Mirroring always used now."
    echo "--c8-caching|--c9-caching"
    echo "                      -- No longer supported."
    echo "--c8-qa-tests         -- Do not use; legacy venv builds no longer"
    echo "                         supported."
    echo "--legacy              -- Do not use; legacy deployment no longer"
    echo "                         supported."
    echo "--no-build            -- Don't build venv, reuse existing packages"
    echo "--skip-extra-playbooks"
    echo "                      -- Skip extra playbook on deployer setup."
    echo "--sles                -- Include any SLES artifacts"
    echo "--sles-control        -- Switch control nodes to use sles"
    echo "--sles-control-nodes nodes"
    echo "                      -- Colon separated list of nodes to be setup"
    echo "                         as SLES controllers. (repeatable)"
    echo "--sles-deployer       -- Switch deployer node to use sles"
    echo "                         (deprecated - deployer will use whichever"
    echo "                         distro is used for control plane."
    echo "--squashkit           -- Specify a kit to compare this against for squashing. You"
    echo "                         probable don't need to run this."
    echo "                         supported."
    echo "--tarball TARBALL     -- Specify a prebuilt deployer tarball to use."
    echo "--update-only         -- Just update the git sources"
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
            ansible-playbook -i "$DEVTOOLS/ansible/hosts/cloud.yml" \
                "$FEATURE/$FEATURE_SCRIPT" \
                --limit "$DEPLOYER_NODE"
        fi
    done
}

# Skip this if NO_UPDATE_RPMS is set
if [ -z "${NO_UPDATE_RPMS:-}" ]; then
    ${SCRIPT_HOME}/update_rpms.sh
fi

# download and include any specified OBS project RPMs
if (( ${#OBS_PRJS[@]} > 0 )); then
    ${SCRIPT_HOME}/get_buildservice_project_rpms --obs "${OBS_PRJS[@]}"
fi

# download and include any specified IBS project RPMs
if (( ${#IBS_PRJS[@]} > 0 )); then
    ${SCRIPT_HOME}/get_buildservice_project_rpms --ibs "${IBS_PRJS[@]}"
fi

# Ensure the override RPMs repo exists
if [ ! -d "${ARDANA_OVERRIDE_RPMS}" ]; then
    mkdir -p "${ARDANA_OVERRIDE_RPMS}"
fi

if [ -n "${ARDANA_DISABLE_SERVICES:-}" -a -n "${USE_PROJECT_STACK:-}" ]; then
    echo "Combining --disable-services and --project-stack isn't allowed." >&2
    exit 1
fi

# Cloud based configuration
if [ -n "$USE_PROJECT_STACK" ]; then
    ARDANA_CLOUD_NAME=project
    export PROJECT_CLOUD=${1:-project}
else
    ARDANA_CLOUD_NAME=${1:-demo}
fi

ARDANA_VAGRANT_DIR="$DEVTOOLS/ardana-vagrant-models/${ARDANA_CLOUD_NAME}-vagrant"
export ARDANA_CLOUD_NAME ARDANA_VAGRANT_DIR

# For a CI run of the "standard" cloud we ensure that the
# third compute is RHEL.
if [ -n "$CI" -a "${ARDANA_CLOUD_NAME}" = "standard" ]; then
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
    unset ARDANA_SLES_COMPUTE
    unset ARDANA_SLES_COMPUTE_NODES
fi

installsubunit
logsubunit --inprogress total

# Setup
if [ -z "$NO_SETUP" ]; then
    logsubunit --inprogress setup
    devenvinstall || logfail setup
    logsubunit --success setup
fi

if [ ! -d "${ARDANA_VAGRANT_DIR}" ]; then
    echo "${ARDANA_VAGRANT_DIR} not found" >&2; exit 1
fi

# Setup the cloud-vagrant symlink
create_cloud_vagrant_link "${ARDANA_CLOUD_NAME}"

# Deploy and configure your cloud
pushd ${ARDANA_VAGRANT_DIR}

# Generate the .astack_env before bringing up the cloud
generate_astack_env "FORCE"

# Setup input model under ${ARDANA_VAGRANT_DIR}
$SCRIPT_HOME/setup-vagrant-input-model \
    --verbose \
    "${ARDANA_CLOUD_NAME}"

# Destroy any pre-existing incarnation of the cloud if requested
if [ -n "${PRE_DESTROY:-}" ]; then
    $SCRIPT_HOME/deploy-vagrant-destroy || logfail pre-destroy
    logsubunit --inprogress pre-destroy
fi

# generate the inventory and astack-ssh-config for the new cloud
$SCRIPT_HOME/setup-vagrant-inventory \
    --verbose \
    "${ARDANA_CLOUD_NAME}"

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

# Run any preparation step for features
if [ -n "$FEATURE_PREPARE" ]; then
    feature_prepare prepare-artifacts.yml
fi

if [ -n "${NO_CLOUD:-}" ]; then
    set +vx
    cat << _EOF_
The environment has been prepared to create a cloud, but the --no-cloud
option was specified. If you would like to deploy your cloud you can
run the following commands:

    % bin/ardana-vagrant up
    % bin/ardana-vagrant-ansible

Once those commands have completed successfully you will have a cloud
environment that is ready for you to log into and manually configure an
input model and then deploy the cloud.
_EOF_
    exit 0
fi

# Bring up vagrant VM's
$SCRIPT_HOME/deploy-vagrant-up || logfail deploy
logsubunit --inprogress deploy

# Configure radvd for IPv6 if needed.
if [ -n "${ARDANA_IPV6_NETWORKS}" ]; then
    # run playbook to configure radvd
    ansible-playbook -i $DEVTOOLS/ansible/hosts/localhost \
        $DEVTOOLS/ansible/dev-env-radvd-configure.yml
fi

generate_ssh_config "FORCE"

# setup the SOC/CLM nodes using a similar process to how
# the customer would in a real deployment
ansible-playbook -i $DEVTOOLS/ansible/hosts/cloud.yml \
    $DEVTOOLS/ansible/cloud-setup.yml

# Run any feature hooks between ardana-init.bash and initialising the input model
feature_ansible post-ardana-init.yml

if [ -n "${COBBLER_ENABLED:-}" ]; then
    # Edit the servers.yml file on deployer to configure specified distros
    $SCRIPT_HOME/run-in-deployer.sh \
        $SCRIPT_HOME/deployer/add-distros.py \
            -- \
            --default-distro=sles \
            --sles="sles${ARDANA_SLES_MAJOR}sp${ARDANA_SLES_SP}" \
            ${COBBLER_NODES:+--nodes="${COBBLER_NODES:-}"} \
            ${COBBLER_RHEL_NODES:+--rhel-nodes=${COBBLER_RHEL_NODES:-}} \
            ${COBBLER_SLES_NODES:+--sles-nodes=${COBBLER_SLES_NODES:-}} \
            ${COBBLER_RHEL_COMPUTE:+--rhel-compute} \
            ${COBBLER_SLES_COMPUTE:+--sles-compute} \
            ${ARDANA_CLOUD_NAME}
fi

# Init the model
$SCRIPT_HOME/run-in-deployer.sh \
    "$SCRIPT_HOME/deployer/init-input-model.sh" "${ARDANA_CLOUD_NAME}" || logfail deploy

# Apply RabbitMQ virtualised testing tweaks
$SCRIPT_HOME/run-in-deployer.sh \
    "$SCRIPT_HOME/deployer/virtual-testing-rabbitmq-tweaks" || logfail deploy

# If using Provo site, use different ntp server
if [ "${ARDANA_SITE:-provo}" = "provo" ]; then
    $SCRIPT_HOME/run-in-deployer.sh \
        "$SCRIPT_HOME/deployer/fix-ntp-server.sh" "${ARDANA_CLOUD_NAME}" || logfail deploy
fi

# If --project-stack is set then modify the input model appropriately.
if [ -n "$USE_PROJECT_STACK" ]; then
    # Copy and commit the project input model
    scp -F $ARDANA_CLOUD_SSH_CONFIG -r $project_input_model/* \
        $(get_deployer_node):~/openstack/my_cloud/definition/ || logfail deploy
    $SCRIPT_HOME/run-in-deployer.sh \
        $SCRIPT_HOME/deployer/commit-changes.sh \
        "Update project-stack input-model from $USE_PROJECT_STACK" || logfail deploy

    if [ -e "$base_project_files/tests" ]; then
        scp -F $ARDANA_CLOUD_SSH_CONFIG -r $base_project_files/tests \
            $(get_deployer_node):~/ardana-ci-tests
    fi
fi
logsubunit --inprogress deploy

# Enable ardana centos rpm repo support on RHEL required for nova computes.
# Flag is enabled when one or more RHEL compute is present in deployment.
if [ -n "${ARDANA_RHEL_OPTIONAL_REPO_ENABLED:-}" ]; then
    ansible-playbook -i $DEVTOOLS/ansible/hosts/cloud.yml \
        $DEVTOOLS/ansible/upload-rhel-centos-tarball-to-deployer.yml

    ansible-playbook -i $DEVTOOLS/ansible/hosts/cloud.yml \
        $DEVTOOLS/ansible/cloud-rhel-deployer-setup.yml
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

if [ -n "$COBBLER_NODES" -o -n "$COBBLER_ALL_NODES" ]; then
    # run cobbler-deploy.sh on deployer specifying which version
    # of SLES to use.
    $SCRIPT_HOME/run-in-deployer.sh \
        "$SCRIPT_HOME/deployer/cobbler-deploy.sh" \
            "$ARDANAUSER" \
            "sles${ARDANA_SLES_MAJOR}sp${ARDANA_SLES_SP}" \
            || logfail deploy
    logsubunit --inprogress deploy
fi

# Re-image any nodes with cobbler
if [ -n "${COBBLER_NODES}" -o -n "$COBBLER_ALL_NODES" ] ; then
    if [ -n "${COBBLER_NODES}" ]; then
        export ARDANA_COBBLER_NODES="$COBBLER_NODES"
    fi
    $SCRIPT_HOME/cobbler-set-pxe-on ${ARDANA_CLOUD_NAME} || logfail deploy
    $SCRIPT_HOME/cobbler-check-power-off ${ARDANA_CLOUD_NAME} || logfail deploy
    $SCRIPT_HOME/cobbler-set-pxe-off ${ARDANA_CLOUD_NAME} || logfail deploy
    $SCRIPT_HOME/cobbler-check-power-on ${ARDANA_CLOUD_NAME} || logfail deploy
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
    ansible-playbook -i $DEVTOOLS/ansible/hosts/cloud.yml \
            $DEVTOOLS/ansible/get-pkg-manifest.yml
fi

popd

# Connect deployer to external network
pushd $DEVTOOLS/ansible
case "${ARDANA_CLOUD_NAME}" in
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
  tee ${WORKSPACE:-$DEVTOOLS}/logs/dev-env-connect-deployer-to-extnet.log || logfail deploy

# Enable routing between management and neutron provider network.
# This is needed for octavia.
ansible-playbook -i hosts/localhost dev-env-route-provider-nets.yml $ROUTEEXTRAARGS || logfail deploy

popd

# Finished the deployment, log success
logsubunit --success deploy

if [ -n "$RUN_TESTS" -a -z "$USE_PROJECT_STACK" ]; then
    run_in_args=""
    run_test_args="--"

    pushd "${DEVTOOLS}/ardana-vagrant-models/${ARDANA_CLOUD_NAME}-vagrant"
    ${SCRIPT_HOME}/run-in-deployer.sh \
        ${run_in_args} \
        ${SCRIPT_HOME}/deployer/run-tests.sh \
            ${run_test_args} \
            ${RUN_TESTS_FILTER} \
            ${ARDANA_CLOUD_NAME}
    popd
fi

if [ -z "${NO_SITE}${NO_CONFIG}" ]; then
    cloud_state=deployed
elif [ -n "${NO_SITE}" ]; then
    cloud_state=configured
else
    cloud_state=provisioned
fi

set +vx

cat << _EOF_

The '${ARDANA_CLOUD_NAME}' cloud has been ${cloud_state}.

To see which nodes make up the cloud you can run the following command:

    % bin/ardana-nodes

Use the ardana-ssh helper scrupt to login to a node, e.g. to login to
the deployer you can run the following command:

    % bin/ardana-ssh deployer

NOTE: 'deployer' will be configured as an alias for the deployer node if
it is not called 'deployer'.

Similarly the ardana-scp and ardana-rsync helper scripts exist and can be
used to send or retrieve files from the cloud nodes.

To run a given filter's set of tempest tests against your cloud, once it
has been deployed, you can use the ardana-run-tests helper script, e.g.
to run the 'ci' filter against the current cloud:

    % bin/ardana-run-tests ci

_EOF_

# vim:shiftwidth=4:tabstop=4:expandtab
