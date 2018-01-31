#!/bin/bash
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
# The last thing this script does is export the ARDANA_DISABLE_SERVICES script. This
# is sourced by astack.sh to figure out what services to disable.
#

set -eux
set -o pipefail

SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})

usage() {
    set +x
    echo "$SCRIPT_NAME [--ci] [--project]"
    echo
    echo "Script can be sourced, this will export the ARDANA_DISABLE_SERVICES"
    echo "variable to restrict where services run."
}

OPTIONS=help,ci,project:
TEMP=$(getopt -o -h -l $OPTIONS -n $SCRIPT_NAME -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

ARDANA_DISABLE_SERVICES=${ARDANA_DISABLE_SERVICES:-}

while true ; do
    case "$1" in
        -h | --help) usage ; exit 0 ;;
        --project) ZUUL_PROJECT=$2 ; shift 2 ;;
        --) shift ; break;;
        *) break ;;
    esac
done

set -x

# Based on the project we are changing. If none, can stop now
# or if we are running the canary job. Canary jobs are a
# special case.
if [ -z "${ZUUL_PROJECT:-}" -o "${ZUUL_PIPELINE:-}" = "ardana-canary" ]; then
    # If we source this scirpt, return otherwise exit
    if [ ${#BASH_SOURCE[@]} -gt 1 ]; then
        return 0
    else
        exit 0
    fi
fi

declare -A restrict_services

# TODO(BUG-3720) - Calculate this else where, and make this the responsibility
# of the service teams to maintain.

# All the services that we restrict depend on monsca so we should run
# all of them against the monasca repos also
monasca_repos="ardana/monasca-ansible \
    openstack/monasca-agent"

tempest_repos="ardana/tempest-ansible \
    openstack/designate-tempest-plugin \
    openstack/tempest \
    openstack/tempest-lib \
    openstack/tempest-monasca"

ardana_qa_repos="ardana/ardana-qa-ansible \
    ardana/ardana-qa-tests"
# Set of repositories where we run everything
common="ardana/ardana-dev-tools \
    ardana/ardana-ansible \
    ardana/ardana-input-model \
    ardana/ardana-configuration-processor \
    ardana/ardana-build-config \
    openstack/requirements \
    ardana/logging-ansible \
    $tempest_repos \
    $monasca_repos \
    $ardana_qa_repos"
for project in $common ; do
    if [ "$project" = "$ZUUL_PROJECT" ]; then
        # If we source this scirpt, return otherwise exit
        if [ ${#BASH_SOURCE[@]} -gt 1 ]; then
            return 0
        else
            exit 0
        fi
    fi
done

# Ok, what is all this restrict_services stuff about?
#
# We are defining which (if any) services are removed
# from the control plane definition when testing against
# specific git repos.
#
# The general pattern is this:
# restrict_services["regex"]="repo1 repo2"
# This means the following:
# During the gate run, for all git repositories except
# "repo1" and "repo2", remove lines containing
# the regular expression "regex" from the control
# plane definition(s).
# In other words, regex will typically be something
# like "swift", and the net result will be that swift
# will be enabled for "repo1" and "repo2", but will
# have been dynamically removed from other repos.
#
# Note: All the "common" repos listed above (ardana-dev-tools
# etc) leave the control plane definitions untouched.
#
# Sometimes we redefine things like this:
# restrict_services["swift"]="${restrict_services['cinder-backup']}"
# This is so that we can keep things modular. We initially define
# the repos that swift should run against. We then redefine
# it to express that cinder-backup requires swift.

declare -A restrict_services_aliases

# Alias for the service name so that we can expand it out
# and be more restrictive about what services we restrict.
# This is so we don't restrict logging-rotate
restrict_services_aliases["logging"]="logging-producer \
    logging-server"

# BUG-3721
logging="ardana/logging-ansible \
    openstack/monasca-log-api \
    openstack/monasca-common \
    ardana/cluster-ansible \
    ardana/keystone-ansible \
    ardana/ardana-qa-tests \
    ardana/ardana-qa-ansible"

restrict_services["logging"]=$logging

# BUG-3729 - restrict freezer but freezer depends on logging
restrict_services["freezer"]="ardana/freezer-ansible \
    openstack/freezer \
    openstack/freezer-api \
    openstack/freezer-web-ui \
    $logging"
restrict_services["logging"]="ardana/freezer-ansible \
    openstack/freezer \
    openstack/freezer-api \
    openstack/freezer-web-ui \
    ${restrict_services['logging']}"

# BUG-3793 - restrict ops bug ops depends on logging
restrict_services["ops-console"]="ardana/opsconsole-ansible $logging"
restrict_services["logging"]="ardana/opsconsole-ansible \
    ${restrict_services['logging']}"

# BUG-3731
# Adding neutron, glance and swift client for their
# respective ceilometer polling which uses client.
# monasca is the backend for ceilometer and need that too
restrict_services["ceilometer"]="ardana/ceilometer-ansible \
    openstack/ceilometer \
    openstack/monasca-api \
    openstack/monasca-common \
    openstack/python-designateclient \
    openstack/python-glanceclient \
    openstack/python-monascaclient \
    openstack/python-novaclient \
    openstack/python-neutronclient \
    openstack/python-swiftclient \
    openstack/python-keystoneclient \
    openstack/keystonemiddleware \
    ardana/keystone-ansible \
    ardana/ardana-qa-tests \
    ardana/ardana-qa-ansible"

# BUG-3794
restrict_services["designate"]="ardana/designate-ansible \
    openstack/designate \
    openstack/python-designateclient \
    openstack/designate_dashboard \
    openstack/python-keystoneclient \
    openstack/python-neutronclient \
    openstack/keystonemiddleware \
    openstack/designate-tempest-plugin \
    ardana/db-ansible \
    ardana/mq-ansible \
    ardana/keystone-ansible \
    ardana/memcached-ansible"
restrict_services["powerdns"]="${restrict_services['designate']}"

# BUG-3795
restrict_services["octavia"]="ardana/octavia-ansible \
    openstack/octavia \
    openstack/python-keystoneclient \
    openstack/python-neutronclient \
    openstack/python-novaclient \
    openstack/python-barbicanclient \
    openstack/keystonemiddleware"

# BUG-3728
restrict_services["horizon"]="ardana/horizon-ansible \
    openstack/horizon \
    ardana/cluster-ansible \
    ardana/keystone-ansible \
    openstack/python-keystoneclient \
    openstack/python-ceilometerclient \
    openstack/python-cinderclient \
    openstack/python-designateclient \
    openstack/designate-dashboard \
    openstack/django_openstack_auth \
    openstack/python-glanceclient \
    openstack/python-neutronclient \
    openstack/python-novaclient \
    openstack/python-swiftclient \
    openstack/python-heatclient \
    openstack/python-ironicclient \
    openstack/freezer \
    openstack/freezer-web-ui \
    openstack/python-barbicanclient \
    openstack/neutron-lbaas-dashboard"

# BUG-3744
restrict_services["swift"]="ardana/swift-ansible \
    openstack/python-monascaclient \
    openstack/swift \
    ardana/swiftlm \
    openstack/python-swiftclient \
    openstack/oslo.messaging \
    openstack/python-keystoneclient \
    openstack/python-neutronclient \
    openstack/keystonemiddleware \
    ardana/ardana-qa-tests \
    ardana/ardana-qa-ansible \
    openstack/tempest \
    ardana/tempest-ansible"

# BUG-3744 - cinder-back depends on swift
restrict_services["cinder-backup"]="ardana/cinder-ansible \
    ardana/cinderlm \
    openstack/cinder \
    ${restrict_services['swift']}"
restrict_services["swift"]="${restrict_services['cinder-backup']}"

# BUG-4142
restrict_services["barbican"]="ardana/barbican-ansible \
    openstack/barbican \
    openstack/python-barbicanclient \
    openstack/python-magnumclient \
    ardana/certifi \
    openstack/oslo.messaging \
    vklochan/python-logstash \
    openstack/python-keystoneclient \
    openstack/keystonemiddleware \
    ardana/magnum-ansible \
    openstack/magnum"

# BUG-4318
restrict_services["heat"]="ardana/heat-ansible \
    openstack/heat \
    openstack/oslo.messaging \
    vklochan/python-logstash \
    openstack/python-keystoneclient \
    openstack/python-barbicanclient \
    openstack/python-swiftclient \
    openstack/python-glanceclient \
    openstack/python-cinderclient \
    openstack/python-neutronclient \
    openstack/python-novaclient \
    openstack/python-ceilometerclient \
    openstack/python-designateclient \
    openstack/python-openstackclient \
    openstack/python-heatclient \
    openstack/python-monascaclient \
    openstack/python-magnumclient \
    openstack/keystonemiddleware \
    openstack/tempest \
    ardana/tempest-ansible \
    ardana/magnum-ansible \
    openstack/magnum"

# BUG-4473
restrict_services["monasca-transform"]="ardana/monasca-transform-ansible \
    ardana/spark-ansible \
    openstack/monasca-transform"

restrict_services["spark"]="ardana/monasca-transform-ansible \
    ardana/spark-ansible \
    openstack/monasca-transform"

restrict_services["magnum"]="ardana/magnum-ansible \
    openstack/magnum \
    openstack/python-magnumclient"

# We bunch up ironic because we need
# to make the regex's more specific (to avoid
# ironic-compute resource name).
ironic_common="
    openstack/ironic \
    openstack/python-ironicclient \
    openstack/python-keystoneclient \
    openstack/keystonemiddleware \
    ardana/keystone-ansible \
    ${restrict_services['swift']} \
    ${restrict_services['designate']}"

# We make sure ironic-api, ironic-conductor, nova-scheduler-ironic & nova-compute-ironic
# is enabled on these repos.
restrict_services["ironic-api"]="$ironic_common"
restrict_services["ironic-conductor"]="$ironic_common"
restrict_services["nova-scheduler-ironic"]="$ironic_common"
restrict_services["nova-compute-ironic"]="$ironic_common"

# And update the set of repos which swift must be
# enabled for, since Ironic requires it
restrict_services["swift"]="$ironic_common"

for service in ${!restrict_services[@]} ; do
    for project in ${restrict_services[$service]} ; do
        if [ "$project" = "$ZUUL_PROJECT" ]; then
            # Break out of this loop continue within the outer loop
            # Bypassing the disabling of services below.
            continue 2
        fi
    done

    if [ -n "${restrict_services_aliases[$service]:-}" ]; then
        for service_alias in ${restrict_services_aliases[$service]} ; do
            ARDANA_DISABLE_SERVICES="$ARDANA_DISABLE_SERVICES $service_alias"
        done
    else
        ARDANA_DISABLE_SERVICES="$ARDANA_DISABLE_SERVICES $service"
    fi
done

echo "Disabling services: $ARDANA_DISABLE_SERVICES"

export ARDANA_DISABLE_SERVICES
