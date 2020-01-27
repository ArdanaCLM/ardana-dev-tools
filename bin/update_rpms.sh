#!/bin/bash -x
#
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

# script: update_rpms.sh
# function: create RPMs from git repos in current working directoy
# Invocation: ./bin/update_rpms.sh
# the general assumption is that the script will be invoked as
# ./ardana-dev-tools/bin/update-rpms.sh without any explict arguments
# but can by invoked from any location.
# inputs explicit: None
# inputs inplicit: Current Working Directory
#                  git repos are located at SCRIPTLOCATIO/../..
# env var inputs:
#     PUBLISHED_RPMS URL loctation of published RPMs
#     CURRENT_OSC_PROJ: PIBS project to get RPM  build specs from
#
# Assumptions: ocs bits have been install and configured, ~/.oscrc has been created

eval "$($(dirname "$(readlink -e "${BASH_SOURCE[0]}")")/ardana-env)"

ARDANA_CLOUD_VERSION=${ARDANA_CLOUD_VERSION:-9}
declare -A ardana_branches
ardana_branches[8]=stable/pike
ardana_branches[9]=master
ARDANA_CLOUD_BRANCH="${ARDANA_CLOUD_BRANCH:-${ardana_branches[${ARDANA_CLOUD_VERSION}]}}"

REPO_NAME="SUSE-OpenStack-Cloud-${ARDANA_CLOUD_VERSION}-${ARDANA_CLOUD_SOURCE:-devel-staging}"

PUBLISHED_RPMS="${PUBLISHED_RPMS:-http://provo-clouddata.cloud.suse.de/repos/x86_64/${REPO_NAME}/suse/noarch/}"
WORKSPACE=$(cd $(dirname $0)/../.. ; pwd)
echo WORKSPACE $WORKSPACE
ARDANA_OVERRIDE_RPMS="${ARDANA_OVERRIDE_RPMS:-${WORKSPACE}/C${ARDANA_CLOUD_VERSION}_NEW_RPMS}"

IOSC='osc -A https://api.suse.de'

case "${ARDANA_CLOUD_SOURCE:-devel-staging}" in
(devel-staging)
    _osc_proj="Devel:Cloud:${ARDANA_CLOUD_VERSION}:Staging"
    ;;
(devel|Updates-test|Updates|Pool)
    # Default to using the Devel version for all other cloud sources
    _osc_proj="Devel:Cloud:${ARDANA_CLOUD_VERSION}"
    ;;
(*)
    echo "ERROR: unsupported cloud source '${ARDANA_CLOUD_VERSION}'."
    exit 1
    ;;
esac
CURRENT_OSC_PROJ="${CURRENT_OSC_PROJ:-${_osc_proj}}"

sudo mkdir -p ~/.cache/osc_build_root
export OSC_BUILD_ROOT=$(readlink -e ~/.cache/osc_build_root)

# function get_cloned_ardana_repos
# input: optional branch name, defaulting to master
# find all the ardana repos under the workspace that are
# checked out on the appropriate branch
function get_cloned_ardana_repos {
    local req_br="${1:-master}"
    local gr_files gr clone gr_prj gr_br

    gr_files=( $( sudo find ${WORKSPACE} -follow -maxdepth 2 -name .gitreview) )

    for gr in "${gr_files[@]}"
    do
        clone="$(basename "$(dirname "${gr}")")"
        gr_prj="$(git config --file "${gr}" gerrit.project)"
        gr_br="$(git config --file "${gr}" gerrit.defaultbranch || echo master)"

        # skip non-Ardana projects
        case "${gr_prj}" in
        (ardana/ardana-dev-tools*)
            echo "Skipping ardana-dev-tools - no associated RPM" 1>&2
            continue
            ;;
        (ardana/ardana)
            # Cloud 8 & 9 ardana-ansible RPMs no longer need ardana respo cloned
            echo "Skipping ardana - no associated RPM" 1>&2
            continue
            ;;
        (ardana/*)
            ;;
        (*)
            echo "Skipping non-Ardana '${clone}' clone for project '${gr_prj}'" 1>&2
            continue
            ;;
        esac

        # skip if clone not based on required branch
        if [[ "${gr_br}" != "${req_br}" ]]; then
            echo "Skipping '${clone}' clone for project '${gr_prj}' because it is based on branch '${gr_br}' not '${req_br}'" 1>&2
            continue
        fi

        echo "${clone}"
    done
}

# function fix_ardana_rpms
# input: git repo name
# input: determined RPM name
# given a git repo name which is assumed to be a subdirectory in the
# current working directory, use the ocs tools to build an RPM
# with the code contents of that git repo.

function fix_ardana_rpm {
    echo "in fix_ardana_rpm $1 $2"
    HOME_LOC=$(pwd)
    REPO="$1"
    # just reurn if no repo passed in
    if [[ -z "$2" ]]; then
        return
    fi
    BUILD_RPM="${2}"

    pushd $OSC_DIR
    UPDATE_OSC="yes"

    #
    # if the sha1 referenced in the rpm build sources we have, does not match
    # the curently published RPM we need to update the cached copy of the RPM
    # build code.
    #
    if [[ -d ${ARDANA_OSC_PROJ}/$BUILD_RPM ]]; then
        (cd ${ARDANA_OSC_PROJ}/${BUILD_RPM}; $IOSC update; $IOSC clean)
        CPOIO_FILE=$(find ${ARDANA_OSC_PROJ}/${BUILD_RPM}/. -name "*git*.obscpio" | grep -v '\.osc/')
        ARCH_PREFIX=$(basename $CPOIO_FILE .obscpio)
        if grep $ARCH_PREFIX $ARDANA_RPM_LIST_PRUNE; then
            UPDATE_OSC="no"
        fi
    fi

    # for now refresh OSC base in all cases
    UPDATE_OSC="yes"
    if [[ "$UPDATE_OSC" = "yes" ]]; then
        rm -rf ${ARDANA_OSC_PROJ}/$BUILD_RPM
        [[ $($IOSC co ${ARDANA_OSC_PROJ}/$BUILD_RPM) ]] || return 1
        CPOIO_FILE=$(find ${ARDANA_OSC_PROJ}/${BUILD_RPM}/. -name "*git*.obscpio" | grep -v '\.osc/')
        ARCH_PREFIX=$(basename $CPOIO_FILE .obscpio)
    fi

    # If the rpm includes ardana-init.bash. update it. There is no sha1 tracking on that
    # file/repo.
    if [[ -e ./${ARDANA_OSC_PROJ}/${BUILD_RPM}/ardana-init.bash ]]; then
        cp ${WORKSPACE}/ardana/ardana-init.bash ./${ARDANA_OSC_PROJ}/ardana-ansible/.
    fi

    #
    # Update the cpio archive used to build the RPM with the contents of the
    # sources in the repo
    #
    pushd ${WORKSPACE}/${REPO}
    rm -rf $RPM_FIX_DIR
    mkdir $RPM_FIX_DIR
    git archive --format=tar --prefix=${ARCH_PREFIX}/ HEAD | tar -C  $RPM_FIX_DIR -xf -
    (cd $RPM_FIX_DIR; find ${ARCH_PREFIX}/. | sudo cpio -o >${ARCH_PREFIX}.obscpio)
    popd
    cp  $RPM_FIX_DIR/${ARCH_PREFIX}.obscpio  ${ARDANA_OSC_PROJ}/${BUILD_RPM}/.
    #
    # rebuild the RPM publishing to the override RPMs area
    #
    (cd ${ARDANA_OSC_PROJ}/${BUILD_RPM};${IOSC} build --trust-all-projects --download-api -k ${ARDANA_OVERRIDE_RPMS}/)

    popd
}

# function update_ardana_rpms
# In the current working dir
# find any cloned repos by looking for .gitreview files.
# if we can determine that that repo  is used to build an rpm,
# call fix_ardana_rpm with the repo directory and create a new
# rpm for testing.

function update_ardana_rpms {

    # Initialise override RPMs area
    rm -rf  ${ARDANA_OVERRIDE_RPMS}
    mkdir  ${ARDANA_OVERRIDE_RPMS}
    (cd ${ARDANA_OVERRIDE_RPMS}; createrepo --update . 1>/dev/null 2>&1)

    # determine which repos we need to potentially build packages for
    CLONED_REPOS=$(get_cloned_ardana_repos "${ARDANA_CLOUD_BRANCH}") || exit 1

    if [[ -z "${CLONED_REPOS}" ]]; then
        echo "Found no repos cloned under ${WORKSPACE} for which we should build updated RPMS."
        return
    fi

    echo "Found these clones to be rebuilt as RPMs: ${CLONED_REPOS}"

    UPDATE_RPM_TMP_DIR="$(mktemp -d /var/tmp/update_rpm_tmp.XXXXXXXXXX)"
    RPM_FIX_DIR="${UPDATE_RPM_TMP_DIR}/rpm_fix_dir"
    ARDANA_RPM_LIST_PRUNE="${UPDATE_RPM_TMP_DIR}/rpm_list_prune"

    curl $PUBLISHED_RPMS \
        | grep -F git. \
        | grep -v ardana-installer-ui \
        | sed -e "s,[<][^>]*[>],,g" \
        | awk '{print $1}' > $ARDANA_RPM_LIST_PRUNE


    ARDANA_OSC_PROJ=$1

    OSC_DIR=~/.cache/ardana-osc
    mkdir  -p $OSC_DIR

    for REPO in $CLONED_REPOS; do
        # need special handling for some repos as the associated
        # rpm name does not follow the general rule as for the
        # other repos.
        case "${REPO}" in
        (ardana-configuration-processor)
            RPM_NAME=python-ardana-configurationprocessor
            ;;
        (opsconsole-server)
            BUILD_RPM=python-ardana-opsconsole-server
            ;;
        (swiftlm|cinderlm)
            RPM_NAME=python-${REPO}
            ;;
        (ardana-ansible|ardana-input-model)
            RPM_NAME=${REPO}
            ;;
        (ardana)
            echo "Skipping build of RPM for '${REPO}' clone as it is consumed by 'ardana-ansible' RPM"
            continue
            ;;
        (*-ansible)
            RPM_NAME=ardana-${REPO%-ansible}
            ;;
        (*)
            # if we didn't identify a REPO ==> RPM_NAME mapping, skip to next repo
            echo "Skipping build of RPM for '${REPO}' clone as no associated RPM could be identified"
            continue
            ;;
        esac

        # sanity check - skip building if corresponding RPM not
        # part of "product"
        if ! grep -e "${RPM_NAME}-" $ARDANA_RPM_LIST_PRUNE; then
            echo "RPM '${RPM_NAME}' for clone '${REPO}' not in product RPMs list"
            continue
        fi

        fix_ardana_rpm "${REPO}" "${RPM_NAME}"
    done

    (cd ${ARDANA_OVERRIDE_RPMS}; createrepo --update .)
    ls -l ${ARDANA_OVERRIDE_RPMS}
    rm -rf  $UPDATE_RPM_TMP_DIR
}


start_time=$(date +%s)

cd $WORKSPACE
update_ardana_rpms  $CURRENT_OSC_PROJ
sudo rm -rf $OSC_BUILD_ROOT/home/abuild
end_time=$(date +%s)
echo "update_rpms: lapse time: $(( end_time - start_time ))"

# vim:shiftwidth=4:tabstop=4:expandtab
