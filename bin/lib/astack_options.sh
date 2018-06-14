# -*- sh -*-
#
# (c) Copyright 2016-2017 Hewlett Packard Enterprise Development LP
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
# Source multiple times to reset variables. If a project-stack
# job defines a astack-options file, then we re-source this, resetting
# all the option variables that control astack.sh
#

# Manage list of long options as a sorted array of option names which
# we then join with commas to form the argument to getopt.
long_opts=(
    c8
    c8-artifacts
    c8-caching
    c8-devel
    c8-hos
    c8-mirror
    c8-pool
    c8-qa-tests
    c8-soc
    c8-staging
    c8-updates
    c8-updates-test
    ci
    cloud8-artifacts
    cloud8-deployer
    cobble-all-nodes
    cobble-nodes:
    cobble-rhel-compute
    cobble-rhel-nodes:
    cobble-sles-compute
    cobble-sles-control
    cobble-sles-nodes:
    disable-no-log
    disable-services:
    extra-vars:
    feature-dir:
    guest-images
    help
    legacy
    no-artifacts
    no-build
    no-config
    no-git-update
    no-prepare
    no-setup
    no-site
    pre-destroy
    project-stack:
    restrict-by-project:
    rhel
    rhel-compute
    rhel-compute-nodes:
    run-tests
    run-tests-filter:
    skip-extra-playbooks
    sles
    sles-compute
    sles-compute-nodes:
    sles-control
    sles-control-nodes:
    sles-deployer
    squashkit:
    tarball:
    update-only
)

# join long_opts members with ","
printf -v OPTIONS ",%s" "${long_opts[@]:1}"
OPTIONS="${long_opts[0]}${OPTIONS}"

TEMP=$(getopt -o -h -l $OPTIONS -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

# Are you running in CI and should do extra steps
export CI=${CI:-}

# Default to using ardana user homed under /var/lib/ardana
export ARDANAUSER="${ARDANAUSER:-ardana}"
export ARDANA_USER_HOME_BASE="${ARDANA_USER_HOME_BASE:-/var/lib}"

# Dynamically build the SLES Extras tarball by default
export ARDANA_SLES_NET_REPOS=${ARDANA_SLES_NET_REPOS:-true}

NO_SETUP=
NO_ARTIFACTS=
NO_BUILD=
BUILD_HLINUX_OVA=
export ARDANA_LEGACY_DEPLOYER=${ARDANA_LEGACY_DEPLOYER:-}
export ARDANA_CLOUD8_ARTIFACTS=${ARDANA_CLOUD8_ARTIFACTS:-}
export ARDANA_CLOUD8_DEPLOYER=${ARDANA_CLOUD8_DEPLOYER:-}
export ARDANA_CLOUD8_REPOS=${ARDANA_CLOUD8_REPOS:-}
export ARDANA_CLOUD8_CACHING_PROXY=${ARDANA_CLOUD8_CACHING_PROXY:-}
export ARDANA_CLOUD8_MIRROR=${ARDANA_CLOUD8_MIRROR:-}
export ARDANA_CLOUD8_HOS=${ARDANA_CLOUD8_HOS:-}
export ARDANA_CLOUD8_SOC=${ARDANA_CLOUD8_SOC:-}
export ARDANA_UPGRADE_NO_RHEL=${ARDANA_UPGRADE_NO_RHEL:-}
export ARDANA_RHEL_ARTIFACTS=${ARDANA_RHEL_ARTIFACTS:-}
export ARDANA_RHEL_OPTIONAL_REPO_ENABLED=${ARDANA_RHEL_OPTIONAL_REPO_ENABLED:-}
export ARDANA_RHEL_COMPUTE=${ARDANA_RHEL_COMPUTE:-}
export ARDANA_RHEL_COMPUTE_NODES=${ARDANA_RHEL_COMPUTE_NODES:-}
export ARDANA_UPGRADE_NO_SLES=${ARDANA_UPGRADE_NO_SLES:-}
export ARDANA_SLES_ARTIFACTS=${ARDANA_SLES_ARTIFACTS:-}
export ARDANA_SLES_CONTROL=${ARDANA_SLES_CONTROL:-}
export ARDANA_SLES_CONTROL_NODES=${ARDANA_SLES_CONTROL_NODES:-}
export ARDANA_SLES_COMPUTE=${ARDANA_SLES_COMPUTE:-}
export ARDANA_SLES_COMPUTE_NODES=${ARDANA_SLES_COMPUTE_NODES:-}
export ARDANA_GUEST_IMAGE_ARTIFACTS=${ARDANA_GUEST_IMAGE_ARTIFACTS:-}
export ARDANA_DISABLE_SERVICES=${ARDANA_DISABLE_SERVICES:-}
export ARDANA_GIT_UPDATE=${ARDANA_GIT_UPDATE:-}
export ARDANA_NO_SETUP_QA=${ARDANA_NO_SETUP_QA:-}
export EXTRA_VARS=${EXTRA_VARS:-}
# By default don't run the extra playbooks that we run during CI
# Override this if we declare that we in the CI system with --ci
SKIP_EXTRA_PLAYBOOKS=--skip-extra-playbooks
DEPLOYER_TARBALL=
# Nodes to re-image with cobbler
COBBLER_NODES=
COBBLER_RHEL_NODES=
COBBLER_SLES_NODES=
COBBLER_RHEL_COMPUTE=
COBBLER_SLES_CONTROL=
COBBLER_SLES_COMPUTE=
COBBLER_ALL_NODES=
COBBLER_ENABLED=
NO_CONFIG=
NO_SITE=
UPDATE_ONLY=
USE_PROJECT_STACK=
SQUASH_KIT=
FEATURE_DIRS=
FEATURE_PREPARE=1
RUN_TESTS=
RUN_TESTS_FILTER=${RUN_TESTS_FILTER:-ci}
PRE_DESTROY=
NO_LOG_DISABLE=
C8_QA_TESTS=

# Total system memory rounded up to nearest multiple of 8GB
TOTMEM_GB=$(awk '/^MemTotal:/ {gb_in_k=(1024*1024);tot_gb=int(($2+(8*gb_in_k)-1)/(8*gb_in_k))*8; print tot_gb}' /proc/meminfo)
BLDVM_MB=$(( (TOTMEM_GB / 4) * 1024 ))

while true ; do
    case "$1" in
        -h | --help) usage ; exit 0 ;;
        --run-tests) RUN_TESTS=1 ; shift ;;
        --run-tests-filter)
            RUN_TESTS=1
            RUN_TESTS_FILTER=$2
            shift 2 ;;
        --ci)
            SKIP_EXTRA_PLAYBOOKS=
            export CI=yes
            export ARDANA_BUILD_MEMORY=${ARDANA_BUILD_MEMORY:-${BLDVM_MB}}
            # Since there could be up to 3 build VMs, only overcommit
            # system CPU resources by at most 50%
            export ARDANA_BUILD_CPU=$(( $(nproc) / 2 ))
            shift ;;
        --no-setup) NO_SETUP=1 ; shift ;;
        --no-artifacts) NO_ARTIFACTS=1 ; shift ;;
        --no-build) NO_BUILD=1 ; shift ;;
        --no-git-update) export ARDANA_GIT_UPDATE=no ; shift ;;
        --pre-destroy)
            PRE_DESTROY=1
            shift ;;
        --disable-no-log)
            NO_LOG_DISABLE=1
            shift ;;
        --cloud8-artifacts)
            export ARDANA_CLOUD8_ARTIFACTS=1
            shift ;;
        --legacy)
            export ARDANA_LEGACY_DEPLOYER=1
            shift ;;
        --c8|--cloud8-deployer)
            export ARDANA_CLOUD8_DEPLOYER=1
            shift ;;
        --c8-hos)
            export ARDANA_CLOUD8_HOS=1
            shift ;;
        --c8-soc)
            export ARDANA_CLOUD8_SOC=1
            shift ;;
        --c8-mirror)
            export ARDANA_CLOUD8_MIRROR=1
            shift ;;
        --c8-caching)
            export ARDANA_CLOUD8_CACHING_PROXY=1
            shift ;;
        --c8-staging)
            export ARDANA_CLOUD8_REPOS='["staging"]'
            shift ;;
        --c8-devel)
            export ARDANA_CLOUD8_REPOS='["devel"]'
            shift ;;
        --c8-updates-test)
            export ARDANA_CLOUD8_REPOS='["updates-test", "updates", "pool"]'
            shift ;;
        --c8-updates)
            export ARDANA_CLOUD8_REPOS='["updates", "pool"]'
            shift ;;
        --c8-pool)
            export ARDANA_CLOUD8_REPOS='["pool"]'
            shift ;;
        --c8-qa-tests)
            RUN_TESTS=1
            C8_QA_TESTS=1
            shift ;;
        --rhel) export ARDANA_RHEL_ARTIFACTS=1 ; shift ;;
        --rhel-compute)
            export ARDANA_RHEL_COMPUTE=1
            shift ;;
        --rhel-compute-nodes)
            ARDANA_RHEL_COMPUTE_NODES="${ARDANA_RHEL_COMPUTE_NODES:+${ARDANA_RHEL_COMPUTE_NODES}:}$2"
            shift 2 ;;
        --sles) export ARDANA_SLES_ARTIFACTS=1 ; shift ;;
        --sles-deployer|--sles-control)
            export ARDANA_SLES_CONTROL=1
            shift ;;
        --sles-control-nodes)
            ARDANA_SLES_CONTROL_NODES="${ARDANA_SLES_CONTROL_NODES:+${ARDANA_SLES_CONTROL_NODES}:}$2"
            shift 2 ;;
        --sles-compute)
            export ARDANA_SLES_COMPUTE=1
            shift ;;
        --sles-compute-nodes)
            ARDANA_SLES_COMPUTE_NODES="${ARDANA_SLES_COMPUTE_NODES:+${ARDANA_SLES_COMPUTE_NODES}:}$2"
            shift 2 ;;
        --guest-images) export ARDANA_GUEST_IMAGE_ARTIFACTS=1 ; shift ;;
        --tarball)
            export DEPLOYER_TARBALL=$2
            shift 2 ;;
        --cobble-nodes)
            COBBLER_NODES="${COBBLER_NODES:+${COBBLER_NODES}:}$2"
            shift 2 ;;
        --cobble-rhel-nodes)
            COBBLER_RHEL_NODES="${COBBLER_RHEL_NODES:+${COBBLER_RHEL_NODES}:}$2"
            shift 2 ;;
        --cobble-sles-nodes)
            COBBLER_SLES_NODES="${COBBLER_SLES_NODES:+${COBBLER_SLES_NODES}:}$2"
            shift 2 ;;
        --cobble-rhel-compute) COBBLER_RHEL_COMPUTE=1 ; shift ;;
        --cobble-sles-control) COBBLER_SLES_CONTROL=1 ; shift ;;
        --cobble-sles-compute) COBBLER_SLES_COMPUTE=1 ; shift ;;
        --cobble-all-nodes) COBBLER_ALL_NODES=1 ; shift ;;
        --disable-services)
            ARDANA_DISABLE_SERVICES="${ARDANA_DISABLE_SERVICES}${ARDANA_DISABLE_SERVICES:+' '}$2"
            shift 2 ;;
        --no-config)
            # If we don't run config processor then we shouldn't run site.yml either
            NO_CONFIG=1
            NO_SITE=1
            shift ;;
        --no-site) NO_SITE=1 ; shift ;;
        --skip-extra-playbooks) SKIP_EXTRA_PLAYBOOKS=--skip-extra-playbooks ; shift ;;
        --update-only) UPDATE_ONLY=1 ; shift ;;
        --project-stack)
            USE_PROJECT_STACK=$2
            shift 2 ;;
        --feature-dir)
            FEATURE_DIRS="$FEATURE_DIRS $2"
            shift 2 ;;
        --no-prepare) FEATURE_PREPARE= ; shift ;;
        --restrict-by-project) ZUUL_PROJECT=$2 ; shift 2 ;;
        --squashkit) SQUASH_KIT=$2 ; shift 2 ;;
        --extra-vars)
            export EXTRA_VARS=$2
            shift 2 ;;
        --) shift ; break;;
        *) break ;;
    esac
done

# Enable Cloud8 mode if any relevant Cloud8 options specified,
# and legacy mode not enabled.
if [ -n "${C8_QA_TESTS:-}" -o \
     -n "${ARDANA_CLOUD8_HOS:-}" -o \
     -n "${ARDANA_CLOUD8_SOC:-}" -o \
     -n "${ARDANA_CLOUD8_REPOS:-}" -o \
     -n "${ARDANA_CLOUD8_MIRROR:-}" -o \
     -n "${ARDANA_CLOUD8_CACHING_PROXY:-}" ]; then
    export ARDANA_CLOUD8_DEPLOYER=1
fi

# Legacy and Cloud8 modes are mutually exclusive
if [ -n "${ARDANA_LEGACY_DEPLOYER:-}" -a \
     -n "${ARDANA_CLOUD8_DEPLOYER:-}" ]; then
    echo "ERROR: Legacy and Cloud8 modes cannot be combined!"
    exit 1
fi

# Default to Cloud8 mode if legacy mode not specified
if [ -z "${ARDANA_LEGACY_DEPLOYER:-}" ]; then
    export ARDANA_CLOUD8_DEPLOYER=1
fi

# Select appropriate settings if cloud8 deployer selected
if [ -n "${ARDANA_CLOUD8_DEPLOYER:-}" ]; then
    export ARDANA_CLOUD8_ARTIFACTS=1
    export ARDANA_SLES_CONTROL=1

    # Cloud8 requires that we are using ardana user homed under
    # /var/lib/ardana
    export ARDANAUSER=ardana
    export ARDANA_USER_HOME_BASE=/var/lib

    # disable building of legacy product venvs
    export ARDANA_PACKAGES_DIST='[]'

    # ensure we build & upload QA venvs only if --c8-qa-tests specified
    if [ -n "${C8_QA_TESTS:-}" ]; then
        # ensure we run tests
        RUN_TESTS=1

        # We could explicitly clear NO_BUILD here to ensure that we
        # force a build of the venvs, but since NO_BUILD defaults to
        # empty, meaning we trigger a venv build, and would only be
        # set if the --no-build option were specified, we trust that
        # the caller knows what they are doing.
    else
        # disable building & uploading QA venvs
        NO_BUILD=1
        export ARDANA_PACKAGES_NONDIST='[]'
        export ARDANA_NO_SETUP_QA=1
    fi

    # default to staging (DC8S) level of repos
    if [ -z "${ARDANA_CLOUD8_REPOS:-}" ]; then
        export ARDANA_CLOUD8_REPOS='["staging"]'
    fi

    # default to enabling mirroring if caching proxy not enabled.
    if [ -z "${ARDANA_CLOUD8_MIRROR:-}" -a \
         -z "${ARDANA_CLOUD8_CACHING_PROXY:-}" ]; then
        export ARDANA_CLOUD8_MIRROR=1
    fi

    # default to SOC8 mode if neither or both modes selected
    if [ \( -z "${ARDANA_CLOUD8_HOS:-}" -a \
            -z "${ARDANA_CLOUD8_SOC:-}" \) -o \
         \( -n "${ARDANA_CLOUD8_HOS:-}" -a \
            -n "${ARDANA_CLOUD8_SOC:-}" \) ]; then
        export ARDANA_CLOUD8_SOC=1
        export ARDANA_CLOUD8_HOS=
    fi
fi

# Select default control plane and compute distros if none selected
if [ -z "${ARDANA_SLES_CONTROL:-}" -a \
     -z "${ARDANA_SLES_CONTROL_NODES:-}" ]; then
    export ARDANA_SLES_CONTROL=1
fi
if [ -z "${ARDANA_SLES_COMPUTE:-}" -a \
     -z "${ARDANA_SLES_COMPUTE_NODES:-}" -a \
     -z "${ARDANA_RHEL_COMPUTE:-}" -a \
     -z "${ARDANA_RHEL_COMPUTE_NODES:-}" ]; then
    export ARDANA_SLES_COMPUTE=1
fi

# If a distro has been selected for control plane, compute or cobbler
# usage then we will need to build the required artifacts for it.
if [ -n "${ARDANA_SLES_CONTROL:-}" -o \
     -n "${ARDANA_SLES_COMPUTE:-}" -o \
     -n "${ARDANA_SLES_CONTROL_NODES:-}" -o \
     -n "${ARDANA_SLES_COMPUTE_NODES:-}" -o \
     -n "${COBBLER_SLES_CONTROL:-}" -o \
     -n "${COBBLER_SLES_COMPUTE:-}" -o \
     -n "${COBBLER_SLES_NODES:-}" ]; then
    export ARDANA_SLES_ARTIFACTS=1
fi
if [ -n "${ARDANA_RHEL_COMPUTE:-}" -o \
     -n "${ARDANA_RHEL_COMPUTE_NODES:-}" -o \
     -n "${COBBLER_RHEL_COMPUTE:-}" -o \
     -n "${COBBLER_RHEL_NODES:-}" ]; then
    export ARDANA_RHEL_ARTIFACTS=1
    # override following flag only when variable is not already set or is blank
    if [ -z "${ARDANA_RHEL_OPTIONAL_REPO_ENABLED}" ]; then
        export ARDANA_RHEL_OPTIONAL_REPO_ENABLED=1
    fi
fi

# Will we be cobbling any nodes
if [ -n "${COBBLER_NODES:-}" -a \
     -n "${COBBLER_ALL_NODES}" ]; then
     COBBLER_ENABLED=1
fi

# vim:shiftwidth=4:tabstop=4:expandtab
