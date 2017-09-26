#!/bin/bash
# (c) Copyright 2016 Hewlett Packard Enterprise Development LP
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
intf=`ip addr | grep -v inet6 | awk '/scope global/ { print $NF }'`
cidr=`ip addr | grep -v inet6 | awk '/scope global/ {print $2}'`
gateway=`ip route | awk '/default/ {print $3}'`
echo source "/etc/network/interfaces.d/*" > /etc/network/interfaces
echo auto lo >> /etc/network/interfaces
echo iface lo inet loopback >> /etc/network/interfaces
echo auto ${intf}  > /etc/network/interfaces.d/${intf}
echo iface ${intf} inet static >>  /etc/network/interfaces.d/${intf}
echo address ${cidr} >>  /etc/network/interfaces.d/${intf}
if [ ! -z ${gateway} ]
then
    echo gateway ${gateway} >> /etc/network/interfaces.d/${intf}
fi

