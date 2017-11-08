#!/bin/bash
#
# (c) Copyright 2016-2017 Hewlett Packard Enterprise Development LP
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

OUTPUT_ISO=$1
SCRATCH=$2

if [ -f $SCRATCH/isolinux.bin ]; then
    # HLinux
    sudo xorriso -as mkisofs -b isolinux.bin -c boot.cat -r -J -no-emul-boot \
        -boot-load-size 4 -boot-info-table -eltorito-alt-boot \
        --efi-boot boot/grub/efi.img \
        -isohybrid-gpt-basdat \
        -isohybrid-apm-hfsplus \
        -o $OUTPUT_ISO $SCRATCH
elif [ -f $SCRATCH/boot/x86_64/loader/isolinux.bin ]; then
    # SLES
    sudo xorriso -as mkisofs -b boot/x86_64/loader/isolinux.bin -r -J -no-emul-boot \
        -boot-load-size 4 -boot-info-table -eltorito-alt-boot \
        --efi-boot boot/x86_64/efi \
        -isohybrid-gpt-basdat \
        -isohybrid-apm-hfsplus \
        -o $OUTPUT_ISO $SCRATCH
else
    echo "ERROR: isolinux.bin not found on source ISO"
    exit 1
fi
