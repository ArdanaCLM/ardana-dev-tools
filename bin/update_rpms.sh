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
# function: create RPMs from git repos in current workinf directoy
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

PUBLISHED_RPMS=${PUBLISHED_RPMS:-http://provo-clouddata.cloud.suse.de/repos/x86_64/SUSE-OpenStack-Cloud-8-devel-staging/suse/noarch/}
WORKSPACE=$(cd $(dirname $0)/../.. ; pwd)
echo WORKSPACE $WORKSPACE



IOSC='osc -A https://api.suse.de'
CURRENT_OSC_PROJ=${CURRENT_OSC_PROJ:-Devel:Cloud:8:Staging}

sudo mkdir -p ~/.cache/osc_build_root
export OSC_BUILD_ROOT=$(readlink -e ~/.cache/osc_build_root)

# function fix_ardana_rpms
# input: git repo name
# given a git repo name which is assumed to be a subdirectory in the
# current working directory, use the ocs tools to build an RPM
# with the code contents of that git repo.

function fix_ardana_rpm {
    echo "in fix_ardana_rpm $1"
    HOME_LOC=$(pwd)
    REPO="$1"
    if [[ ${REPO} = "ardana" ]]; then
        return 0
    fi

    BUILD_RPM="$REPO"
    case "$BUILD_RPM" in
        "opsconsole-server")
            BUILD_RPM=python-ardana-opsconsole-serve
            ;;
        "opsconsole-server")
            BUILD_RPM=python-ardana-opsconsole-server
            ;;
        "cinderlm")
            BUILD_RPM=python-cinderlm
            ;;
        ardana*)
            :
            ;;
        *)
            BUILD_RPM=ardana-${REPO/-ansible/}
    esac

    cd $OSC_DIR
    UPDATE_RPM="yes"
    #
    # if the sha1 referenced in the rpm build sources we have, does not match
    # the curently published RPM we need to update the cached copy of the RPM
    # build code.
    #
    if [[ -d ${ARDANA_OSC_PROJ}/$BUILD_RPM ]]; then
        CPOIO_FILE=$(find ${ARDANA_OSC_PROJ}/${BUILD_RPM}/. -name "*git*.obscpio" | grep -v '\.osc/')
        ARCH_PREFIX=$(basename $CPOIO_FILE .obscpio)
        if grep $ARCH_PREFIX $ARDANA_RPM_LIST_PRUNE; then
            UPDATE_RPM="no"
        fi
    fi

    if [[ "$UPDATE_RPM" = "yes" ]]; then
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
    cd ${WORKSPACE}/${REPO}
    rm -rf $RPM_FIX_DIR
    mkdir $RPM_FIX_DIR
    git archive --format=tar --prefix=${ARCH_PREFIX}/ HEAD | tar -C  $RPM_FIX_DIR -xf -
    (cd $RPM_FIX_DIR; find ${ARCH_PREFIX}/. | sudo cpio -o >${ARCH_PREFIX}.obscpio)
    cd $OSC_DIR
    cp  $RPM_FIX_DIR/${ARCH_PREFIX}.obscpio  ${ARDANA_OSC_PROJ}/${BUILD_RPM}/.
    #
    # rebuild the RPM
    #
    (cd ${ARDANA_OSC_PROJ}/${BUILD_RPM};${IOSC} build --trust-all-projects)
    # copy new rpm to new rpm area.
    cp ${OSC_BUILD_ROOT}/home/abuild/rpmbuild/RPMS/noarch/*.rpm $WORKSPACE/NEW_RPMS/.

}

# function update_ardana_rpms
# In the current working dir
# find any cloned repos by looking for .gitreview files.
# if we can determine that that repo  is used to build an rpm,
# call fix_ardana_rpm with the repo directory and create a new
# rpm for testing.

function update_ardana_rpms {

    UPDATE_RPM_TMP_DIR="$(mktemp -d /var/tmp/update_rpm_tmp.XXXXXXXXXX)"
    RPM_FIX_DIR="${UPDATE_RPM_TMP_DIR}/rpm_fix_dir"
    ARDANA_RPM_LIST_PRUNE="${UPDATE_RPM_TMP_DIR}/rpm_list_prune"

    curl $PUBLISHED_RPMS \
        | grep -F git. \
        | grep -v ardana-installer-ui \
        | sed -e "s,[<][^>]*[>],,g" \
        | awk '{print $1}' > $ARDANA_RPM_LIST_PRUNE


    CLONED_REPOS=$(sudo find . -follow -maxdepth 2 -name .gitreview -exec dirname {} \; | grep -v osc_)
    ARDANA_OSC_PROJ=$1

    OSC_DIR=~/.cache/ardana-osc
    mkdir  -p $OSC_DIR

    rm -rf  $WORKSPACE/NEW_RPMS
    mkdir  $WORKSPACE/NEW_RPMS
    (cd ${WORKSPACE}/NEW_RPMS; createrepo --update .)

    for REPO in $CLONED_REPOS; do
        SANDBOX=$(basename $REPO)
        RPM_NAME=${SANDBOX/-ansible/}
        grep ${RPM_NAME}- $ARDANA_RPM_LIST_PRUNE &&
            fix_ardana_rpm "$SANDBOX"
    done

    (cd ${WORKSPACE}/NEW_RPMS; createrepo --update .)
    ls -l ${WORKSPACE}/NEW_RPMS
    rm -rf  $UPDATE_RPM_TMP_DIR
}


start_time=$(date +%s)

cd $WORKSPACE
update_ardana_rpms  $CURRENT_OSC_PROJ
sudo rm -rf $OSC_BUILD_ROOT/home/abuild
end_time=$(date +%s)
echo "update_rpms: lapse time: $(( end_time - start_time ))"

# vim:shiftwidth=4:tabstop=4:expandtab

