#!/bin/bash
#
# (c) Copyright 2015-2016 Hewlett Packard Enterprise Development LP
# (c) Copyright 2017 SUSE LLC
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

# Don't set -e as a node could be down and cause the playbooks
# to fail. The playbooks can handle this but exit with non-zero status
set -ux
set -o pipefail

# Setup the deployer so it can access API endpoints.

pushd "${HOME}/scratch/ansible/next/ardana/ansible"

export PYTHONUNBUFFERED=1

sostimeout=900
sosarchives="/tmp/sosreport-report-archives"

mkdir -p $sosarchives
timeout "${sostimeout}s" ansible-playbook -i hosts/verb_hosts sosreport-run.yml \
    -e timeout=$sostimeout \
    -e sosreport_deployer_archives=$sosarchives > ${sosarchives}/sosreport-run.log
results=$?
if [ $results -ge 124 ]; then
    echo "*** SOSREPORT TIMEOUT ***" >&2

    cat ${sosarchives}/sosreport-run.log
elif [ $results -ne 0 ] ; then
    # Otherwise the sosreport playbook just failed.
    cat ${sosarchives}/sosreport-run.log
fi

sudo chmod 0644 /opt/stack/tempest/configs/tempest_*.conf
# successful exit this script - don't return the status of the last command
exit 0
