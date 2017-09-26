#!/bin/bash

set -eux
set -o pipefail

TMP_IMAGE_DIR=$(mktemp -d /tmp/create_iso.XXXX)
SCRIPTNAME=`basename $0`

function v_print() {
    echo "$*"
}

function err_print() {
    echo "$*" >&2
}

# Parse command line options
ARGS=`getopt -o "o:i:k:I:" -l "output,initrd,kernel,ISO:" \
      -n "$SCRIPTNAME" -- "$@"`
if [ $? -ne 0 ];
then
        exit 1
fi

eval set -- "$ARGS"

while true ; do
    case "$1" in
        -o) OUTPUT_FILENAME=$2; shift 2 ;;
        -i) INITRD=$2; shift 2 ;;
        -I) ISO=$2; shift 2 ;;
        -k) KERNEL=$2; shift 2 ;;
        # *)  show_options ; exit 1 ;;
        --) shift; break ;;
    esac
done

# Verify whether kernel, initrd, and the image file is present
if [ -z "$OUTPUT_FILENAME" ]; then
    err_print "Output filename not provided."
    exit 1
fi

if [ -z "$INITRD" ]; then
    err_print "Initrd not provided."
    exit 1
fi

if [ -z "$KERNEL" ]; then
    err_print "Kernel not provided."
    exit 1
fi

if [ -z "$ISO" ]; then
    err_print "ISO not provided."
    exit 1
fi

mkdir -p $TMP_IMAGE_DIR/isolinux/
ISO_MOUNT=$(mktemp -d /tmp/create_iso.mount.XXXX)
EFI_MOUNT=$(mktemp -d /tmp/create_efi.mount.XXXX)
sudo mount -o loop $ISO $ISO_MOUNT
pushd $ISO_MOUNT
cp -avf isolinux.bin ldlinux.c32 $TMP_IMAGE_DIR/isolinux/
mkdir -p $TMP_IMAGE_DIR/boot/grub
cp -avf boot/grub/efi.img $TMP_IMAGE_DIR/boot/grub/
cp -aRvf efi $TMP_IMAGE_DIR/
cp -aRvf .disk $TMP_IMAGE_DIR/.disk
popd
sudo umount $ISO_MOUNT

sudo dd if=/dev/zero of=efi.img bs=1K count=2880
sudo apt-get -y install dosfstools
sudo mkdosfs -F 12 efi.img
sudo mount -oloop efi.img $ISO_MOUNT
sudo mount -oloop $TMP_IMAGE_DIR/boot/grub/efi.img $EFI_MOUNT
if [ -e $EFI_MOUNT/efi/boot/MokManager.efi ] ; then
    sudo rm -Rf $EFI_MOUNT/efi/boot/MokManager.efi
fi
sudo cp -aRvf $EFI_MOUNT/. $ISO_MOUNT/
sudo umount efi.img $TMP_IMAGE_DIR/boot/grub/efi.img
sudo mv efi.img $TMP_IMAGE_DIR/boot/grub/efi.img
sudo cp -f $TMP_IMAGE_DIR/boot/grub/efi.img $TMP_IMAGE_DIR/efi/boot/efi.img
rmdir $ISO_MOUNT $EFI_MOUNT

# Copy initrd, kernel
v_print "Copying kernel to $TMP_IMAGE_DIR/vmlinuz"
cp $KERNEL "$TMP_IMAGE_DIR/vmlinuz"
if [ $? -ne 0 ]; then
    err_print "Failed to copy $KERNEL to $TMP_IMAGE_DIR"
    exit 1
fi

v_print "Copying initrd to $TMP_IMAGE_DIR/initrd"
cp $INITRD "$TMP_IMAGE_DIR/initrd"
if [ $? -ne 0 ]; then
    err_print "Failed to copy $INITRD to $TMP_IMAGE_DIR"
    exit 1
fi

#echo "VMEDIA_BOOT_ISO" > $TMP_IMAGE_DIR/.disk/info

# Create isolinux configuration
cat << EOF >> $TMP_IMAGE_DIR/isolinux/isolinux.cfg
default deploy
TIMEOUT 5
PROMPT 0

LABEL deploy
  menu label "Deploy Image"
  kernel /vmlinuz
  append initrd=/initrd boot_method=vmedia --
EOF

cat > "$TMP_IMAGE_DIR/boot/grub/grub.cfg" << END_CONFIG
insmod efi_gop
insmod efi_uga
insmod video_bochs
insmod video_cirrus
insmod font
insmod gfxterm
set gfxmode=800x600
set gfxpayload=text
terminal_output gfxterm

set default="0"
set timeout="5"
set hidden_timeout_quiet=false

menuentry "deploy" {
    search --set=root --label VMEDIA_BOOT_ISO
    echo 'Loading Kernel...'
    linux /vmlinuz vga=normal boot_method=vmedia -- quiet
    echo 'Loading Initial ramdisk...'
    initrd /initrd
}
END_CONFIG

# Generate ISO Image
sudo xorriso -as mkisofs -b isolinux/isolinux.bin -c boot.cat -V VMEDIA_BOOT_ISO -r -J -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot --efi-boot boot/grub/efi.img -isohybrid-gpt-basdat -isohybrid-apm-hfsplus -o $OUTPUT_FILENAME $TMP_IMAGE_DIR

sudo rm -Rf $TMP_IMAGE_DIR
