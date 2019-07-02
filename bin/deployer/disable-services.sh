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

set -eux
set -o pipefail

SERVICES="${@}"

pushd ~/openstack/my_cloud/definition

control_plane_files=( $(grep -Ilr -e "^[[:space:]]*control-planes:") )
network_group_files=( $(grep -Ilr -e "^[[:space:]]*network-groups:") )

cp_entry_is_none()
{
	local cp_file="${1}" cp_entry="${2}"

	python -c "import sys, yaml; cpf = yaml.load(file('${cp_file}')); sys.exit(int(not any([cp['${cp_entry}'] is None for cp in cpf['control-planes']])))"
}

for service in $SERVICES
do
	sed -i -e "/- ${service}/ s/^\( *\)#*/\1#/" ${control_plane_files[@]}

	case "${service}" in
	(glance-api)
		for param in ha_mode glance_stores glance_default_store
		do
			sed -i -e "/  *${param}:/ s/^\( *\)#*/\1#/" ${control_plane_files[@]}
		done
		;;
	(designate-api|octavia-api|neutron-server|nova-api|swift-ring-builder)
		conf_base="${service%%-*}"
		for conf in ${conf_base^^}-CONFIG
		do
			sed -i -e "/-  *${conf}/ s/^\( *\)#*/\1#/" ${control_plane_files[@]}
		done
		for net in ${conf_base^^}-MGMT-NET
		do
			sed -i -e "/-  *${net}/ s/^\( *\)#*/\1#/" ${network_group_files[@]}
		done
		;;
	esac
done

# Handle empty configuration-data list
for cpf in ${control_plane_files[@]}
do
	if cp_entry_is_none "${cpf}" "configuration-data"
	then
		sed -i -e "/ *configuration-data: *$/ s/ *$/ []/" "${cpf}"
	fi
done

git add -A
git commit --allow-empty -m "Disabling these services: $SERVICES"
