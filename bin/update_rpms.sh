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

PUBLISHED_RPMS=${PUBLISHED_RPMS:-http://provo-clouddata.cloud.suse.de/repos/x86_64/SUSE-OpenStack-Cloud-9-devel-staging/suse/noarch/}
WORKSPACE=$(cd $(dirname $0)/../.. ; pwd)
echo WORKSPACE $WORKSPACE

CONFIG_PROC_SPEC='#
# spec file for package python-ardana-configurationprocessor
#
# Copyright (c) 2017 SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An Open Source License is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/


%{?!python_module:%define python_module() python-%{**} python3-%{**}}
Name:           python-ardana-configurationprocessor
Version:        0.4.0
Release:        0
License:        Apache-2.0
Summary:        Configuration Processor for Ardana CLM
Url:            https://github.com/ArdanaCLM
Group:          Development/Languages/Python
Source:         https://files.pythonhosted.org/packages/source/a/ardana-configurationprocessor/ardana-configurationprocessor-%{version}.tar.gz
BuildRequires:  python-rpm-macros
BuildRequires:  %{python_module devel}
BuildRequires:  %{python_module setuptools}
BuildRequires:  fdupes
Requires:       python-cryptography
Requires:       python-html
Requires:       python-jsonschema
Requires:       python-netaddr
Requires:       python-pycryptodome
Requires:       python-PyYAML
Requires:       python-sh
Requires:       python-simplejson
Requires:       python-six
Requires:       python-stevedore
Requires(post): update-alternatives
Requires(postun): update-alternatives
BuildArch:      noarch

%python_subpackages

%description
Ardana Lifecycle Management Configuration Processor

%prep
%setup -q -n ardana-configurationprocessor-%{version}

%build
%python_build

%install
%python_install
%python_clone -a %{buildroot}%{_bindir}/ardana-cp
%python_clone -a %{buildroot}%{_bindir}/ardana-cp-decrypt
%python_clone -a %{buildroot}%{_bindir}/ardana-cp-passwordchecker
%python_clone -a %{buildroot}%{_bindir}/ardana-dv.py
%python_clone -a %{buildroot}%{_bindir}/ardana-pc.py
%python_expand %fdupes %{buildroot}%{$python_sitelib}

%post
%python_install_alternative ardana-cp
%python_install_alternative ardana-cp-decrypt
%python_install_alternative ardana-cp-passwordchecker
%python_install_alternative ardana-dv.py
%python_install_alternative ardana-pc.py

%postun
%python_uninstall_alternative ardana-cp
%python_uninstall_alternative ardana-cp-decrypt
%python_uninstall_alternative ardana-cp-passwordchecker
%python_uninstall_alternative ardana-dv.py
%python_uninstall_alternative ardana-pc.py


%files %{python_files}
%defattr(-,root,root,-)
%doc README.txt
%python_alternative %{_bindir}/ardana-cp
%python_alternative %{_bindir}/ardana-cp-decrypt
%python_alternative %{_bindir}/ardana-cp-passwordchecker
%python_alternative %{_bindir}/ardana-dv.py
%python_alternative %{_bindir}/ardana-pc.py
%{python_sitelib}/*

%changelog
'

IOSC='osc -A https://api.suse.de'
CURRENT_OSC_PROJ=${CURRENT_OSC_PROJ:-Devel:Cloud:9:Staging}
C8_CURRENT_OSC_PROJ=${C8_CURRENT_OSC_PROJ:-Devel:Cloud:9:Staging}

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
            BUILD_RPM=python-ardana-opsconsole-server
            ;;
        "cinderlm")
            BUILD_RPM=python-cinderlm
            ;;
        "ardana-configuration-processor")
            BUILD_RPM=python-ardana-configurationprocessor
            ;;
        ardana*)
            ;;
        *)
            BUILD_RPM=ardana-${REPO/-ansible/}
    esac

    cd $OSC_DIR
    UPDATE_OSC="yes"

    #
    # ardana-configuration-processo is just a special case,
    # it does not follow any of the normal rules
    #
    if [[ ${REPO} = "ardana-configuration-processor" ]]; then
        rm -rf ${C8_CURRENT_OSC_PROJ}/$BUILD_RPM
        [[ $($IOSC co ${C8_CURRENT_OSC_PROJ}/$BUILD_RPM) ]] || return 1
        (cd ${WORKSPACE}/${REPO}; python setup.py sdist)
        cp ${WORKSPACE}/${REPO}/dist/ardana-configurationprocessor-0.4.0.tar.gz ./${C8_CURRENT_OSC_PROJ}/${BUILD_RPM}/.
        echo "$CONFIG_PROC_SPEC" > ./${C8_CURRENT_OSC_PROJ}/${BUILD_RPM}/python-ardana-configurationprocessor.spec
        (cd ${C8_CURRENT_OSC_PROJ}/${BUILD_RPM};${IOSC} build --trust-all-projects --download-api -k $WORKSPACE/NEW_RPMS)
        return 0
    fi

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
    (cd ${ARDANA_OSC_PROJ}/${BUILD_RPM};${IOSC} build --trust-all-projects --download-api)
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

    #
    # need to handle ardana-configuration-processor
    # special, the rpm name does not follow the same
    # rules as the other rpms
    #
    if [[ -d ardana-configuration-processor ]]; then
        fix_ardana_rpm ardana-configuration-processor
    fi

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

