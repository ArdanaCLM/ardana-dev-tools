#!/bin/bash
#
# (c) Copyright 2019 SUSE LLC
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

#
# Utility functions for managing service component enablement/disablement.
#
# The shell library provides the following functions:
#
# * setup_services_groups(cloud_version, svc_groups_to_enable,
#                         svc_groups_to_disable)
#   + cloud_version:
#     - either '8' or '9'
#   + svc_groups_to_enable:
#     - name of bash array variable holding list of service group
#       aliases for service component groups that should be enabled.
#   + svc_groups_to_disable:
#     - name of bash array variable holding list of service group
#       aliases for service component groups that should be disabled.
#
# * generate_disabled_services_entries(args_array_name)
#   + args_array_name:
#     - name of bash array variable to which will be appended argument
#       pairs of the format (--disable-services <svc_component_name>)
#       for each service component group entry that is disabled.
#
# Potential service group aliases are found below as the names of arrays
# ending in '_services'

# List of input model service components that can be enabled/disabled.
declare -A services_enabled
services_enabled=(

    # foundation services
    ["ntp-client"]=false
    ["ntp-server"]=false
    ["mysql"]=false
    ["rabbitmq"]=false
    ["ip-cluster"]=false

    # minimal openstack service
    ["memcached"]=false
    ["keystone-api"]=false
    ["horizon"]=false
    ["ops-console-web"]=false
    ["tempest"]=false

    # basic services, swift through barbican
    ["swift-ring-builder"]=false
    ["swift-account"]=false
    ["swift-container"]=false
    ["swift-object"]=false
    ["swift-proxy"]=false

    ["glance-api"]=false
    ["glance-registry"]=false

    ["cinder-api"]=false
    ["cinder-backup"]=false
    ["cinder-scheduler"]=false
    ["cinder-volume"]=false

    ["neutron-dhcp-agent"]=false
    ["neutron-lbaasv2-agent"]=false
    ["neutron-l3-agent"]=false
    ["neutron-metadata-agent"]=false
    ["neutron-ml2-plugin"]=false
    ["neutron-openvswitch-agent"]=false
    ["neutron-server"]=false
    ["neutron-vpn-agent"]=false

    ["nova-api"]=false
    ["nova-compute-kvm"]=false
    ["nova-compute"]=false
    ["nova-conductor"]=false
    ["nova-console-auth"]=false
    ["nova-novncproxy"]=false
    ["nova-placement-api"]=false
    ["nova-scheduler"]=false

    ["barbican-api"]=false
    ["barbican-worker"]=false

    # advanced services (everything else except MML)
    ["bind"]=false
    ["designate-api"]=false
    ["designate-central"]=false
    ["designate-mdns"]=false
    ["designate-pool-manager"]=false
    ["designate-producer"]=false
    ["designate-worker"]=false
    ["designate-zone-manager"]=false

    ["heat-api-cfn"]=false
    ["heat-api-cloudwatch"]=false
    ["heat-api"]=false
    ["heat-engine"]=false

    ["magnum-api"]=false
    ["magnum-conductor"]=false

    ["manila-api"]=false
    ["manila-share"]=false

    ["octavia-api"]=false
    ["octavia-health-manager"]=false

    # Metering, Monitoring & Logging
    ["ceilometer-agent-notification"]=false
    ["ceilometer-api"]=false
    ["ceilometer-common"]=false
    ["ceilometer-polling"]=false

    ["logging-producer"]=false
    ["logging-rotate"]=false
    ["logging-server"]=false
    ["kafka"]=false

    ["freezer-agent"]=false
    ["freezer-api"]=false

    ["monasca-agent"]=false
    ["monasca-api"]=false
    ["monasca-notifier"]=false
    ["monasca-persister"]=false
    ["monasca-threshold"]=false
    ["monasca-transform"]=false

    ["cassandra"]=false

    ["spark"]=false
    ["storm"]=false

    # Used by designate as well as MML
    ["zookeeper"]=false
)


#
# Service component group definitions
#
# The alias for a service component group is derived by stripping off
# the '_services' suffix.
#

foundation_services=(
    ntp-client
    ntp-server
    mysql
    rabbitmq
    ip-cluster
)

min_services=(
    "${foundation_services[@]}"
    memcached
    keystone-api
    horizon
    ops-console-web
    tempest
)

swift_services=(
    swift-ring-builder
    swift-account
    swift-container
    swift-object
    swift-proxy
)

glance_services=(
    glance-api
    glance-registry
)

cinder_services=(
    cinder-api
    cinder-backup
    cinder-scheduler
    cinder-volume
)

neutron_services=(
    neutron-dhcp-agent
    neutron-lbaasv2-agent
    neutron-l3-agent
    neutron-metadata-agent
    neutron-ml2-plugin
    neutron-openvswitch-agent
    neutron-server
    neutron-vpn-agent
)

nova_services=(
    nova-api
    nova-compute-kvm
    nova-compute
    nova-conductor
    nova-console-auth
    nova-novncproxy
    nova-placement-api
    nova-scheduler
)

barbican_services=(
    barbican-api
    barbican-worker
)

octavia_services=(
    octavia-api
    octavia-health-manager
)

designate_services=(
    bind
    designate-api
    designate-central
    designate-mdns
    designate-pool-manager
    designate-producer
    designate-worker
    designate-zone-manager
    zookeeper
)

heat_services=(
    heat-api-cfn
    heat-api-cloudwatch
    heat-api
    heat-engine
)

magnum_services=(
    magnum-api
    magnum-conductor
)

manila_services=(
    manila-api
    manila-share
)

logging_services=(
    kafka
    logging-producer
    logging-rotate
    logging-server
)

mml_services=(
    "${logging_services[@]}"

    freezer-agent
    freezer-api

    ceilometer-agent-notification
    ceilometer-api
    ceilometer-common
    ceilometer-polling

    monasca-agent
    monasca-api
    monasca-notifier
    monasca-persister
    monasca-threshold
    monasca-transform

    cassandra

    spark
    storm

    zookeeper
)

basic_services=(
    "${min_services[@]}"
    "${swift_services[@]}"
    "${glance_services[@]}"
    "${cinder_services[@]}"
    "${neutron_services[@]}"
    "${nova_services[@]}"
    "${barbican_services[@]}"
)

adv_services=(
    "${basic_services[@]}"
    "${designate_services[@]}"
    "${heat_services[@]}"
    "${octavia_services[@]}"
    "${magnum_services[@]}"
    "${manila_services[@]}"
)

all_services=(
    "${adv_services[@]}"
    "${mml_services[@]}"
)


#
# Cloud version specific service component lists
#
cloud8_disabled=(
)

cloud9_disabled=(
    freezer-agent
    freezer-api
    glance-registry
    heat-api-cloudwatch
    neutron-lbaasv2-agent
    nova-console-auth
)

#
# Service component state management utility routines
#

set_service_state()
{
    services_enabled[${1}]=${2}
}

is_service_enabled()
{
    [[ "${services_enabled[${1}]}" == "true" ]]
}

enable_services_group_entries()
{
    local -n svcs="${1}"
    local svc

    for svc in "${svcs[@]}"
    do
        set_service_state ${svc} true
    done
}

enable_services_groups()
{
    local svc_group

    for svc_group in "${@}"
    do
        enable_services_group_entries "${svc_group}_services"
    done
}

disable_services_group_entries()
{
    local -n svcs="${1}"
    local svc

    for svc in "${svcs[@]}"
    do
        set_service_state ${svc} false
    done
}

disable_services_groups()
{
    local svc_group

    for svc_group in "${@}"
    do
        disable_services_group_entries "${svc_group}_services"
    done
}

finalise_services_groups()
{
    # Ensure foundation services are enabled
    enable_services_groups foundation

    # Ensure zookeeper enabled if designate enabled, even if
    # mml services have been disabled
    if is_service_enabled designate-api
    then
        set_service_state zookeeper true
    fi
}


#
# Exposed utility functions
#

setup_services_groups()
{
    local cloud_version="${1}"
    local -n enabled_groups="${2}" disabled_groups="${3}"

    # enable named groups first
    if (( ${#enabled_groups[@]} > 0 ))
    then
        enable_services_groups "${enabled_groups[@]}"
    fi

    # then disable named service groups
    if (( ${#disabled_groups[@]} > 0 ))
    then
        disable_services_groups "${disabled_groups[@]}"
    fi

    # Now disable any services not valid for this cloud_version
    disable_services_group_entries "cloud${cloud_version}_disabled"

    # Ensure required services are enabled including applying any
    # special dependency logic to ensure that the set of enabled
    # services is viable.
    finalise_services_groups
}

generate_disabled_services_entries()
{
    local -n astack_args="${1}"
    local svc

    for svc in "${!services_enabled[@]}"
    do
        if [[ "${services_enabled[${svc}]}" == false ]]
        then
            astack_args+=( --disable-services "${svc}" )
        fi
    done
}

# vim:shiftwidth=4:tabstop=4:expandtab
