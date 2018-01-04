#!/bin/bash
#
# (c) Copyright 2015-2017 Hewlett Packard Enterprise Development LP
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

# create_iso.sh -d <deployer tarball> <path or url to iso> [<artifact> ...]
#
# Adding general support for artifact bundling, but keeping the -d switch for
# the deployer tarball for backwards compat.
# The -d switch can be removed once all use of it has been stopped.

set -eu
set -o pipefail

usage() {
    set +x
    echo "$0 -d TARBALL -o OUTPUT_ISO SRC_ISO ARTIFACTS..."
}

artifacts_root=ardana

TEMP=$(getopt -o h,v:,d:,b:,o: -l help,tarball:,output: -n $0 -- "$@")

DEPLOYER_TARBALL=
OUTPUT_ISO=

while true ; do
    case "$1" in
        -h|--help) usage ; exit 0 ;;
        -d|--tarball) DEPLOYER_TARBALL=$2 ; shift 2 ;;
        -o|--output) OUTPUT_ISO=$2 ; shift 2 ;;
        --) shift ; break;;
        *) break ;;
    esac
done

ISO_SRC=${1:-}
shift
if [[ -z "$ISO_SRC" ]]; then
    echo "Missing ISO source" >&2
    exit 1
fi

if [ -z "$DEPLOYER_TARBALL" -o -z "$OUTPUT_ISO" ]; then
    usage >&2
    exit 1
fi

INCLUDE_ARTIFACTS=("$@" $DEPLOYER_TARBALL)
if [[ ${#INCLUDE_ARTIFACTS[@]} != 0 ]]; then
    artifact_missing=
    for artifact in "${INCLUDE_ARTIFACTS[@]}"; do
        if [[ ! -e $artifact ]]; then
            echo "ERROR: Artifact '$artifact' does not exist." >&2
            artifact_missing=1
        fi
    done
    [[ -n $artifact_missing ]] && exit 1
fi

# Use the directory containing this script as a
# workspace directory.
ISOGEN=$(dirname $(readlink -f $0))
SCRATCH=$ISOGEN/scratch
SCRATCH_INITRD=$ISOGEN/scratch_initrd
OUTPUT=$ISOGEN/output
PRESEED_DIR=$ISOGEN/saved_preseed
SCRIPT_DIR=$ISOGEN/scripts
FILES_DIR=$ISOGEN/files
SLES_FILES_DIR=$ISOGEN/sles

# A git SHA1 of the ardana/ardana-dev-tools repo (which contains this script)
# is required, to provide a 'munge id' for the generated iso image.
# N.B. not checking that the repo contains no local modifications - that's for
# the user to ensure.
if ! git -C $ISOGEN rev-parse -q HEAD; then
    echo "ERROR: You must run this script from a git clone." >&2
    exit 1
fi

# Precleansing
sudo rm -rf $SCRATCH_INITRD $SCRATCH

mkdir -p $SCRATCH
mkdir -p $OUTPUT
mkdir -p $SCRATCH_INITRD

if [[ $ISO_SRC = *://* ]]; then
    # Fetch url.
    # Todo: Cache the iso  (under $HOME/.cache/ardana/... ?)
    HLINUX_ISO=$ISOGEN/$(basename $ISO_SRC)
    echo "Fetching $ISO_SRC to $HLINUX_ISO..."
    wget -O$HLINUX_ISO $ISO_SRC
else
    HLINUX_ISO=$ISO_SRC
fi

cd $ISOGEN

ISO_MOUNT=$(mktemp -d /tmp/create_iso.mount.XXXX)
sudo mount -o loop $HLINUX_ISO $ISO_MOUNT
pushd $ISO_MOUNT
tar cf - $(ls -1 -A) | ( cd $SCRATCH; tar xfp -)
popd
sudo umount $ISO_MOUNT
rmdir $ISO_MOUNT

if [ -f $SCRATCH/initrd.gz ]; then
    # Hlinux ISO
    cp $SCRATCH/initrd.gz $SCRATCH_INITRD
    pushd $SCRATCH_INITRD
    gunzip initrd.gz
    mkdir -p extracted
    cd extracted
    sudo cpio -id < ../initrd

    sudo cp ./preseed.cfg $PRESEED_DIR/preseed.orig
    sudo cp $PRESEED_DIR/preseed.cfg .
    sudo cp $SCRIPT_DIR/configure_network.sh ./sbin
    sudo cp $SCRIPT_DIR/configure_partitioning ./sbin
    sudo cp $SCRIPT_DIR/configure_kdump ./sbin
    sudo cp $SCRIPT_DIR/update_fcoe_udev.py ./sbin
    sudo cp $SCRIPT_DIR/configure_fcoe_udev ./sbin
    sudo mkdir -p ./files
    sudo cp $FILES_DIR/* files

    sudo find . | cpio --create --format='newc' > ../newinitrd
    cd ..
    gzip newinitrd
    sudo cp newinitrd.gz $SCRATCH/initrd.gz

    ls -l $SCRATCH/initrd.gz

    popd
elif [ -f $SCRATCH/boot/x86_64/loader/isolinux.bin ]; then
    sudo cp -f $SLES_FILES_DIR/isolinux.cfg $SCRATCH/boot/x86_64/loader/
    sudo cp -f $SLES_FILES_DIR/sles12sp3-autoyast.xml $SCRATCH/
    sudo cp -f $SLES_FILES_DIR/add_nic.xslt $SCRATCH/
    sudo perl -p -i.orig -e 's#^  linuxefi /boot/x86_64/loader/linux splash=silent$#  linuxefi /boot/x86_64/loader/linux splash=silent autoyast=file:///sles12sp3-autoyast.xml#' $SCRATCH/EFI/BOOT/grub.cfg
else
    echo "ERROR: isolinux.bin not found on source ISO"
    exit 1
fi

if [[ ${#INCLUDE_ARTIFACTS[@]} != 0 ]]; then
    mkdir $SCRATCH/$artifacts_root
    for artifact in "${INCLUDE_ARTIFACTS[@]}"; do
        cp $artifact $SCRATCH/$artifacts_root
    done
fi

$ISOGEN/write_iso.sh $OUTPUT_ISO $SCRATCH
