#!/bin/sh -e
#
# Copyright (c) 2010-2012 Patrick Debois
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

aib_logs=/root/ardana_image_build
aib_script=zerodisk
mkdir -p ${aib_logs}
exec 1>> ${aib_logs}/${aib_script}.log
exec 2>> ${aib_logs}/${aib_script}.log

echo "[Drop all caches]"
sync; echo 3 > /proc/sys/vm/drop_caches; sync

# Zero out any empty space in the file system to reduce image size
echo "[Fill free space with zeros]"
dd if=/dev/zero of=/tmp/zero.dat bs=1M oflag=direct conv=fdatasync || true
rm -rf /tmp/zero.dat

echo "[Drop all caches (again)]"
sync; echo 3 > /proc/sys/vm/drop_caches; sync

# trim out the free/unused space to save space in the final image
echo "[Trim out free/unused space]"
fstrim -v / || true
