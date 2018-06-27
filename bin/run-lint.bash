#!/bin/bash
#
# (c) Copyright 2015-2016 Hewlett Packard Enterprise Development LP
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
# Called by CI
#

set -eux
set -o pipefail

eval "$($(dirname "$(readlink -e "${BASH_SOURCE[0]}")")/ardana-env)"

SCRIPT_DIR=$(readlink -e $(dirname $0))
source ${SCRIPT_DIR}/libci.sh

# Verify that we can actually download from the git server.
wget --spider -v -t3 $GOZER_GIT_MIRROR

VENV=$DEVTOOLS/tools/venvs/ansible

# Setup dev install
if [ ! -e $VENV ]; then
  mkdir -p $VENV
  virtualenv --python=python2 --no-site-packages $VENV
  $VENV/bin/pip install -U pip
  $VENV/bin/pip install -r ${DEVTOOLS}/requirements.txt
fi

# Setup slave
pushd $DEVTOOLS/ansible
$VENV/bin/ansible -e dev_env_default_git_server=${GOZER_GIT_MIRROR} --version

# enable extended globbing in bash
shopt -s extglob
# Ignore from the syntax check the existing playbooks that have syntax issues
# Note: this should eventually be an empty list as they are fixed.
# See: https://suse-jira.dyndns.org/browse/BUG-3057
GLOBIGNORE="ardana_version.yml:percona-post-upgrade.yml:percona-pre-upgrade.yml"
# run a syntax-check passing in dumb values for variables that are prompted
$VENV/bin/ansible-playbook -i hosts/localhost --syntax-check *.yml -e \
  "old_deployer_hostname=dumb ardanauser_password=dumb encrypt=dumb rekey=dumb"
$VENV/bin/ansible-playbook -e dev_env_default_git_server=${GOZER_GIT_MIRROR} -i hosts/localhost lint-run.yml
