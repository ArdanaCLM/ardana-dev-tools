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
    ansible-sync
    build-images
    c8
    c8-artifacts
    c8-caching
    c8-devel
    c8-hos
    c8-iso
    c8-mirror
    c8-pool
    c8-qa-tests
    c8-soc
    c8-staging
    c8-updates
    c8-updates-test
    c9
    c9-artifacts
    c9-caching
    c9-devel
    c9-iso
    c9-milestone:
    c9-mirror
    c9-pool
    c9-staging
    c9-updates
    c9-updates-test
    ci
    cloud8-artifacts
    cloud8-deployer
    cloud9-artifacts
    cloud9-deployer
    cobble-all-nodes
    cobble-nodes:
    cobble-rhel-compute
    cobble-rhel-nodes:
    cobble-sles-compute
    cobble-sles-control
    cobble-sles-nodes:
    debug
    disable-no-log
    disable-services:
    enable-mitigations
    enable-spectrev2
    extra-vars:
    feature-dir:
    guest-images
    help
    ibs-prj:
    ibs-repo:
    ipv4
    ipv6
    ipv6-all
    legacy
    no-ansible-sync
    no-artifacts
    no-build
    no-config
    no-cloud
    no-git-update
    no-prepare
    no-setup
    no-site
    no-update-rpms
    obs-prj:
    obs-repo:
    prebuilt-images
    prebuilt-version:
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
    sles12sp3
    sles12sp4
    sles-compute
    sles-compute-nodes:
    sles-control
    sles-control-nodes:
    sles-deployer
    squashkit:
    tarball:
    update-only
    update-rpms
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

# Allow specification of additional IBS & OBS projects whose repos
# will be added to all SLES nodes
OBS_REPOS=()
IBS_REPOS=()
export ARDANA_OBS_REPOS=${ARDANA_OBS_REPOS:-}
export ARDANA_IBS_REPOS=${ARDANA_IBS_REPOS:-}

# Allow specification of IBS & OBS projects whose RPMs will be
# be downloaded and added to the override RPMs area
OBS_PRJS=()
IBS_PRJS=()

NO_SETUP=
NO_ARTIFACTS=
NO_UPDATE_RPMS=
SOC_CLM_8=
SOC_CLM_9=

# ARDANA NETWORKS represented by corresponding net interface indices
DEFAULT_NET_INDICES="0,1,2,3,4,5,6,7,8"

# RANDOM UNIQUE LOCAL IPv6 PREFIXES for use in ARDANA NETWORKS
DEVTOOLS=$(cd $(dirname ${BASH_SOURCE[0]})/../.. ; pwd)
ipv6_ula_file=$DEVTOOLS/bin/default_ipv6_ula
DEFAULT_IPV6_ULA=`cat ${ipv6_ula_file}`

export ARDANA_DEBUG=${ARDANA_DEBUG:-}
export ARDANA_SYNC_ANSIBLE_SOURCES=${ARDANA_SYNC_ANSIBLE_SOURCES:-}
export ARDANA_PREBUILT_IMAGES=${ARDANA_PREBUILT_IMAGES:-1}
export ARDANA_QCOW2_TIMESTAMP=${ARDANA_QCOW2_TIMESTAMP:-}
export ARDANA_DISABLE_MITIGATIONS=${ARDANA_DISABLE_MITIGATIONS:-1}
export ARDANA_ATTACH_ISOS=${ARDANA_ATTACH_ISOS:-}
export ARDANA_CLOUD_VERSION=${ARDANA_CLOUD_VERSION:-}
export ARDANA_CLOUD_ARTIFACTS=${ARDANA_CLOUD_ARTIFACTS:-}
export ARDANA_CLOUD_REPOS=${ARDANA_CLOUD_REPOS:-}
export ARDANA_CLOUD_SOURCE=${ARDANA_CLOUD_SOURCE:-devel-staging}
export ARDANA_CLOUD_MIRROR=${ARDANA_CLOUD_MIRROR:-1}
export ARDANA_CLOUD_HOS=${ARDANA_CLOUD_HOS:-}
export ARDANA_CLOUD_SOC=${ARDANA_CLOUD_SOC:-}
export ARDANA_UPGRADE_NO_RHEL=${ARDANA_UPGRADE_NO_RHEL:-}
export ARDANA_RHEL_ARTIFACTS=${ARDANA_RHEL_ARTIFACTS:-}
export ARDANA_RHEL_OPTIONAL_REPO_ENABLED=${ARDANA_RHEL_OPTIONAL_REPO_ENABLED:-}
export ARDANA_RHEL_COMPUTE=${ARDANA_RHEL_COMPUTE:-}
export ARDANA_RHEL_COMPUTE_NODES=${ARDANA_RHEL_COMPUTE_NODES:-}
export ARDANA_UPGRADE_NO_SLES=${ARDANA_UPGRADE_NO_SLES:-}
export ARDANA_SLES_ARTIFACTS=${ARDANA_SLES_ARTIFACTS:-}
export ARDANA_SLES_MAJOR=${ARDANA_SLES_MAJOR:-}
export ARDANA_SLES_SP=${ARDANA_SLES_SP:-}
export ARDANA_SLES_COMPUTE=${ARDANA_SLES_COMPUTE:-}
export ARDANA_SLES_COMPUTE_NODES=${ARDANA_SLES_COMPUTE_NODES:-}
export ARDANA_SLES_MIRROR=${ARDANA_SLES_MIRROR:-1}  # default to enabled
# default to all possible SLE SERVER repos being enabled
export ARDANA_SLES_REPOS=${ARDANA_SLES_REPOS:-"['pool', 'updates', 'ltss-updates', 'updates-test', 'ltss-updates-test']"}
export ARDANA_GUEST_IMAGE_ARTIFACTS=${ARDANA_GUEST_IMAGE_ARTIFACTS:-}
export ARDANA_DISABLE_SERVICES=${ARDANA_DISABLE_SERVICES:-}
export ARDANA_GIT_UPDATE=${ARDANA_GIT_UPDATE:-}
export ARDANA_NO_SETUP_QA=${ARDANA_NO_SETUP_QA:-}
export ARDANA_IPV4_NETWORKS=${ARDANA_IPV4_NETWORKS:-${DEFAULT_NET_INDICES}}
export ARDANA_IPV6_NETWORKS=${ARDANA_IPV6_NETWORKS:-""}
export ARDANA_NET_IPV6_ULA=${ARDANA_NET_IPV6_ULA:-${DEFAULT_IPV6_ULA}}
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
COBBLER_SLES_COMPUTE=
COBBLER_ALL_NODES=
COBBLER_ENABLED=
NO_CLOUD=
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
NO_UPDATE_RPMS=1

# Total system memory rounded up to nearest multiple of 8GB
TOTMEM_GB=$(awk '/^MemTotal:/ {gb_in_k=(1024*1024);tot_gb=int(($2+(8*gb_in_k)-1)/(8*gb_in_k))*8; print tot_gb}' /proc/meminfo)

while true ; do
    case "$1" in
        -h | --help) usage ; exit 0 ;;
        --debug) export ARDANA_DEBUG=1 ; shift ;;
        --run-tests) RUN_TESTS=1 ; shift ;;
        --run-tests-filter)
            RUN_TESTS=1
            RUN_TESTS_FILTER=$2
            shift 2 ;;
        --ci)
            SKIP_EXTRA_PLAYBOOKS=
            export CI=yes
            # Since there could be up to 3 build VMs, only overcommit
            # system CPU resources by at most 50%
            export ARDANA_BUILD_CPU=$(( $(nproc) / 2 ))
            shift ;;
        --ansible-sync) export ARDANA_SYNC_ANSIBLE_SOURCES=1 ; shift ;;
        --no-ansible-sync) export ARDANA_SYNC_ANSIBLE_SOURCES= ; shift ;;
        --no-setup) NO_SETUP=1 ; shift ;;
        --no-artifacts) NO_ARTIFACTS=1 ; shift ;;
        --no-update-rpms) NO_UPDATE_RPMS=1 ; shift ;;
        --update-rpms) NO_UPDATE_RPMS= ; shift ;;
        --no-git-update) export ARDANA_GIT_UPDATE=no ; shift ;;
        --prebuilt-images) export ARDANA_PREBUILT_IMAGES=1 ; shift ;;
        --prebuilt-version)
            export ARDANA_QCOW2_TIMESTAMP=${2}
            shift 2 ;;
        --build-images) export ARDANA_PREBUILT_IMAGES=0 ; shift ;;
        --enable-mitigations|--enable-spectrev2)
            export ARDANA_PREBUILT_IMAGES=0
            export ARDANA_DISABLE_MITIGATIONS=
            shift ;;
        --ibs-prj) IBS_PRJS+=( "${2}" ); shift 2;;
        --ibs-repo) IBS_REPOS+=( "${2}" ); shift 2;;
        --obs-prj) OBS_PRJS+=( "${2}" ); shift 2;;
        --obs-repo) OBS_REPOS+=( "${2}" ); shift 2;;
        --pre-destroy)
            PRE_DESTROY=1
            shift ;;
        --disable-no-log)
            NO_LOG_DISABLE=1
            shift ;;
        --cloud8-artifacts)
            SOC_CLM_8=true
            export ARDANA_CLOUD_ARTIFACTS=1
            shift ;;
        --c8)
            SOC_CLM_8=true
            shift ;;
        --c8-hos)
            SOC_CLM_8=true
            export ARDANA_CLOUD_HOS=1
            shift ;;
        --c8-soc)
            SOC_CLM_8=true
            export ARDANA_CLOUD_SOC=1
            shift ;;
        --c8-mirror)
            SOC_CLM_8=true
            export ARDANA_CLOUD_MIRROR=1
            shift ;;
        --c8-staging)
            SOC_CLM_8=true
            export ARDANA_CLOUD_REPOS='["staging"]'
            export ARDANA_CLOUD_SOURCE="devel-staging"
            shift ;;
        --c8-devel)
            SOC_CLM_8=true
            export ARDANA_CLOUD_REPOS='["devel"]'
            export ARDANA_CLOUD_SOURCE="devel"
            shift ;;
        --c8-updates-test)
            SOC_CLM_8=true
            export ARDANA_CLOUD_REPOS='["updates-test", "updates", "pool"]'
            export ARDANA_CLOUD_SOURCE="Updates-test"
            # SLES repos default to LTSS-Updates-test, LTSS-Updates, Updates-test, Updates & Pool
            shift ;;
        --c8-updates)
            SOC_CLM_8=true
            export ARDANA_CLOUD_REPOS='["updates", "pool"]'
            export ARDANA_CLOUD_SOURCE="Updates"
            # Limit SLES repos to LTSS-Updates, Updates & Pool only
            export ARDANA_SLES_REPOS='["ltss-updates", "updates", "pool"]'
            shift ;;
        --c8-pool)
            SOC_CLM_8=true
            export ARDANA_CLOUD_REPOS='["pool"]'
            export ARDANA_CLOUD_SOURCE="Pool"
            # Limit SLES repos to LTSS-Updates, Updates & Pool only
            export ARDANA_SLES_REPOS='["ltss-updates", "updates", "pool"]'
            shift ;;
        --c8-iso)
            SOC_CLM_8=true
            export ARDANA_CLOUD_REPOS='["iso"]'
            export ARDANA_ATTACH_ISOS=true
            # Limit SLES repos to LTSS-Updates, Updates & Pool only
            export ARDANA_SLES_REPOS='["ltss-updates", "updates", "pool"]'
            NO_UPDATE_RPMS=1
            shift ;;
        --cloud9-artifacts)
            SOC_CLM_9=true
            export ARDANA_CLOUD_ARTIFACTS=1
            shift ;;
        --c9)
            SOC_CLM_9=true
            shift ;;
        --c9-mirror)
            SOC_CLM_9=true
            export ARDANA_CLOUD_MIRROR=1
            shift ;;
        --c9-staging)
            SOC_CLM_9=true
            export ARDANA_CLOUD_REPOS='["staging"]'
            export ARDANA_CLOUD_SOURCE="devel-staging"
            shift ;;
        --c9-devel)
            SOC_CLM_9=true
            export ARDANA_CLOUD_REPOS='["devel"]'
            export ARDANA_CLOUD_SOURCE="devel"
            shift ;;
        --c9-updates-test)
            SOC_CLM_9=true
            export ARDANA_CLOUD_REPOS='["updates-test", "updates", "pool"]'
            export ARDANA_CLOUD_SOURCE="Updates-test"
            # SLES repos default to LTSS-Updates-test, LTSS-Updates, Updates-test, Updates & Pool
            shift ;;
        --c9-updates)
            SOC_CLM_9=true
            export ARDANA_CLOUD_REPOS='["updates", "pool"]'
            export ARDANA_CLOUD_SOURCE="Updates"
            # Limit SLES repos to LTSS-Updates, Updates & Pool only
            export ARDANA_SLES_REPOS='["ltss-updates", "updates", "pool"]'
            shift ;;
        --c9-pool)
            SOC_CLM_9=true
            export ARDANA_CLOUD_REPOS='["pool"]'
            export ARDANA_CLOUD_SOURCE="Pool"
            # Limit SLES repos to LTSS-Updates, Updates & Pool only
            export ARDANA_SLES_REPOS='["ltss-updates", "updates", "pool"]'
            shift ;;
        --c9-milestone)  # NOTE: this must immediately preceed --c9-iso
            export ARDANA_CLOUD9_MILESTONE="${2}"
            shift  # only consume one argument as next pattern block also shifts
            ;&  # continue with commands in next pattern's action block
        --c9-iso)
            SOC_CLM_9=true
            export ARDANA_CLOUD_REPOS='["iso"]'
            export ARDANA_ATTACH_ISOS=true
            # Limit SLES repos to LTSS-Updates, Updates & Pool only
            export ARDANA_SLES_REPOS='["ltss-updates", "updates", "pool"]'
            NO_UPDATE_RPMS=1
            shift ;;
        --rhel) export ARDANA_RHEL_ARTIFACTS=1 ; shift ;;
        --rhel-compute)
            export ARDANA_RHEL_COMPUTE=1
            shift ;;
        --rhel-compute-nodes)
            ARDANA_RHEL_COMPUTE_NODES="${ARDANA_RHEL_COMPUTE_NODES:+${ARDANA_RHEL_COMPUTE_NODES}:}$2"
            shift 2 ;;
        --sles12sp3)
            export ARDANA_SLES_MAJOR=12
            export ARDANA_SLES_SP=3
            shift ;;
        --sles12sp4)
            export ARDANA_SLES_MAJOR=12
            export ARDANA_SLES_SP=4
            shift ;;
        --sles-compute)
            export ARDANA_SLES_COMPUTE=1
            shift ;;
        --sles-compute-nodes)
            ARDANA_SLES_COMPUTE_NODES="${ARDANA_SLES_COMPUTE_NODES:+${ARDANA_SLES_COMPUTE_NODES}:}$2"
            shift 2 ;;
        --guest-images) export ARDANA_GUEST_IMAGE_ARTIFACTS=1 ; shift ;;
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
        --cobble-sles-compute) COBBLER_SLES_COMPUTE=1 ; shift ;;
        --cobble-all-nodes) COBBLER_ALL_NODES=1 ; shift ;;
        --disable-services)
            ARDANA_DISABLE_SERVICES="${ARDANA_DISABLE_SERVICES}${ARDANA_DISABLE_SERVICES:+' '}$2"
            shift 2 ;;
        --no-cloud)
            NO_CLOUD=1
            ;&  # fall through to --no-config handling
        --no-config)
            NO_CONFIG=1
            ;&  # fall through to --no-site handling
        --no-site)
            NO_SITE=1
            shift ;;
        --project-stack)
            USE_PROJECT_STACK=$2
            shift 2 ;;
        --feature-dir)
            FEATURE_DIRS="$FEATURE_DIRS $2"
            shift 2 ;;
        --no-prepare) FEATURE_PREPARE= ; shift ;;
        --restrict-by-project) ZUUL_PROJECT=$2 ; shift 2 ;;
        --ipv4) export ARDANA_IPV4_NETWORKS="$2" ; shift 2 ;;
        --ipv6) export ARDANA_IPV6_NETWORKS="$2" ; shift 2 ;;
        --ipv6-all) export ARDANA_IPV6_NETWORKS=${DEFAULT_NET_INDICES} ; shift ;;
        --extra-vars)
            export EXTRA_VARS=$2
            shift 2 ;;
        # Handle deprecated options
        --c8-caching|--c9-caching) ;&  # fall through to next block
        --c8-qa-tests|--cloud8-deployer|--cloud9-deployer) ;&
        --cobble-sles-control|--sles|--sles-control|--sles-deployer) ;&
        --skip-extra-playbooks|--legacy|--no-build|--update-only)
            echo "Deprecated option '${1}' - ignored"
            shift ;;
        --sles-control-nodes|--squashkit|--tarball)
            echo "Deprecated option '${1} ${2}' - ignored"
            shift 2 ;;
        --) shift ; break;;
        *) break ;;
    esac
done

#
# Sanity check option settings and set reasonable defaults of no specific options specified.
#

# Our product uses a SLES based control plane so we
# always want SLES based artifacts
export ARDANA_SLES_ARTIFACTS=1
export ARDANA_CLOUD_ARTIFACTS=1

# SOC/CLM requires that we are using ardana user homed under
# /var/lib/ardana
export ARDANAUSER=ardana
export ARDANA_USER_HOME_BASE=/var/lib

# default to Staging repos as Cloud package source
if [ -z "${ARDANA_CLOUD_SOURCE:-}" ]; then
    export ARDANA_CLOUD_SOURCE="devel-staging"
fi

# default to SOC mode if neither or both modes selected
if [ \( -z "${ARDANA_CLOUD_HOS:-}" -a \
        -z "${ARDANA_CLOUD_SOC:-}" \) -o \
     \( -n "${ARDANA_CLOUD_HOS:-}" -a \
        -n "${ARDANA_CLOUD_SOC:-}" \) ]; then
    export ARDANA_CLOUD_SOC=1
    export ARDANA_CLOUD_HOS=
fi

# default to Staging as set of Cloud repos to use
if [ -z "${ARDANA_CLOUD_REPOS:-}" ]; then
    if [ -n "${ARDANA_CLOUD_HOS:-}" ]; then
        export ARDANA_CLOUD_REPOS='["devel"]'
    else
        export ARDANA_CLOUD_REPOS='["staging"]'
    fi
fi

# Mixing SOC_CLM_8 & SOC_CLM_9 options is not supported.
if [ -n "${SOC_CLM_8:-}" -a \
     -n "${SOC_CLM_9:-}" ]; then
    echo "ERROR: Cannot mix --c8* & --c9* options!"
    exit 1
fi

# If neither SOC_CLM_8 or SOC_CLM_9 has been set
if [ -z "${SOC_CLM_8:-}" -a \
     -z "${SOC_CLM_9:-}" ]; then
    # default to SOC_CLM_9
    SOC_CLM_9=true
fi

# Setup appropriate Cloud and SLES version settings
if [ -n "${SOC_CLM_9:-}" ]; then
    export ARDANA_CLOUD_VERSION=9
    export ARDANA_SLES_MAJOR=12
    export ARDANA_SLES_SP=4
    if [ -n "${ARDANA_CLOUD_HOS:-}" ]; then
        echo "ERROR: No HOS variant for SOC 9"
        exit 1
    fi
elif [ -n "${SOC_CLM_8:-}" ]; then
    export ARDANA_CLOUD_VERSION=8
    export ARDANA_SLES_MAJOR=12
    export ARDANA_SLES_SP=3
fi

# Ensure mirroring is enabled
if [ -z "${ARDANA_CLOUD_MIRROR:-}" ]; then
    export ARDANA_CLOUD_MIRROR=1
fi

# Select default compute distro if none selected
if [ -z "${ARDANA_SLES_COMPUTE:-}" -a \
     -z "${ARDANA_SLES_COMPUTE_NODES:-}" -a \
     -z "${ARDANA_RHEL_COMPUTE:-}" -a \
     -z "${ARDANA_RHEL_COMPUTE_NODES:-}" ]; then
    export ARDANA_SLES_COMPUTE=1
fi

# If RHEL distro has been selected for compute or cobbler
# usage then we will need to build the required artifacts for it.
if [ -n "${ARDANA_RHEL_COMPUTE:-}" -o \
     -n "${ARDANA_RHEL_COMPUTE_NODES:-}" -o \
     -n "${COBBLER_RHEL_COMPUTE:-}" -o \
     -n "${COBBLER_RHEL_NODES:-}" ]; then
    export ARDANA_RHEL_ARTIFACTS=1
fi

# Will we be cobbling any nodes
if [ -n "${COBBLER_NODES:-}" -o \
     -n "${COBBLER_SLES_COMPUTE:-}" -o \
     -n "${COBBLER_SLES_NODES:-}" -o \
     -n "${COBBLER_RHEL_COMPUTE:-}" -o \
     -n "${COBBLER_RHEL_NODES:-}" -o \
     -n "${COBBLER_ALL_NODES}" ]; then
    COBBLER_ENABLED=1

    export ARDANA_ATTACH_ISOS=true
fi

# if RHEL computes or cobbler enabled, need to attach ISOs
# to support RHEL imaging/deployment
if [ -n "${COBBLER_ENABLED:-}" -o \
     -n "${ARDANA_RHEL_COMPUTE:-}" -o \
     -n "${ARDANA_RHEL_COMPUTE_NODES:-}" ]; then
    export ARDANA_ATTACH_ISOS=true
fi

# Only enable RHEL optional repo if deploying RHEL computes and
# not doing a cobbler run, since a cobbler run doesn't actually
# deploy the cloud and therefore doesn't need the optional repo.
if [ -z "${COBBLER_ENABLED:-}" -a \
     \( -n "${ARDANA_RHEL_COMPUTE:-}" -o \
        -n "${ARDANA_RHEL_COMPUTE_NODES:-}" \) ]; then
    # override following flag only when variable is not already set or is blank
    if [ -z "${ARDANA_RHEL_OPTIONAL_REPO_ENABLED}" ]; then
        export ARDANA_RHEL_OPTIONAL_REPO_ENABLED=1
    fi
fi

# Check for any OBS or IBS repos having been specified and set up
# the env vars appropriately.
if (( ${#IBS_REPOS[@]} > 0 )); then
    if (( ${#IBS_REPOS[@]} > 1 )); then
        printf -v ibs_repos_list ",%s" "${IBS_REPOS[@]:1}"
    fi
    export ARDANA_IBS_REPOS="${ARDANA_IBS_REPOS:-}${ARDANA_IBS_REPOS:+,}${IBS_REPOS[0]}${ibs_repos_list:-}"
fi
if (( ${#OBS_REPOS[@]} > 0 )); then
    if (( ${#OBS_REPOS[@]} > 1 )); then
        printf -v obs_repos_list ",%s" "${OBS_REPOS[@]:1}"
    fi
    export ARDANA_OBS_REPOS="${ARDANA_OBS_REPOS:-}${ARDANA_OBS_REPOS:+,}${OBS_REPOS[0]}${obs_repos_list:-}"
fi

# vim:shiftwidth=4:tabstop=4:expandtab
