# (c) Copyright 2016 Hewlett Packard Enterprise Development LP
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

aib_logs=/root/ardana_image_build
aib_script=ardana
mkdir -p ${aib_logs}
exec 1>> ${aib_logs}/${aib_script}.log
exec 2>> ${aib_logs}/${aib_script}.log

# determine build date
ardana_date="$(date --utc)"

# equivalent to the vagrant idea, but tailored to be acceptable externally
echo "[Saving ardana image build timestamp]"
echo "${ardana_date}" > /etc/ardana_image_build_time

# Customize the message of the day
echo "[Setting up /etc/motd]"
echo "Welcome to your Ardana virtual machine." >> /etc/motd
echo "Build date: ${ardana_date}" >> /etc/motd
