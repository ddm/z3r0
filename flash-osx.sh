#!/usr/bin/env bash

set -e

RASPBIAN_DISTRO="raspbian"
RASPBIAN_FLAVOR="raspbian-stretch"
RASPBIAN_RELEASE="2017-09-08"
RASPBIAN_VERSION="2017-09-07"
RASPBIAN_IMG="${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}"
RASPBIAN_URL="http://vx2-downloads.raspberrypi.org/${RASPBIAN_DISTRO}/images/${RASPBIAN_DISTRO}-${RASPBIAN_RELEASE}/${RASPBIAN_IMG}.zip"
EXPECTED_SHASUM="c35688583510fc93c5deac637976b7a5c9c55689" # SHA1
PARTUUID="020c3677-02"

pushd `dirname $0` > /dev/null
DIR=`pwd -P`
popd > /dev/null

if (( $# < 1 )) ; then
    echo "Usage: $0 [disk]"
    echo "  e.g. $0 disk2"
    echo "Found:"
    find /dev -name disk[0-9] 2> /dev/null | grep -v directory | cut -d '/' -f 3
    exit 1
fi
TARGET=$1

if [ ! -f ${DIR}/${RASPBIAN_IMG}.img ]; then
  if [ ! -f ${DIR}/${RASPBIAN_IMG}.zip ]; then
    echo "Downloading image..."
    wget ${RASPBIAN_URL}
  fi
  ACTUAL_SHASUM=$(shasum ${DIR}/${RASPBIAN_IMG}.zip | cut -d ' ' -f 1)
  if [[ ${ACTUAL_SHASUM} == ${EXPECTED_SHASUM} ]]; then
    echo "Matching SHA1: ${ACTUAL_SHASUM}"
    unzip ${RASPBIAN_IMG}.zip
  else
    echo "SHA1 mismatch: expected ${EXPECTED_SHASUM} but got ${ACTUAL_SHASUM}"
    exit 1
  fi
fi
RASPBIAN_SIZE=$(stat -x ${RASPBIAN_IMG}.img | grep Size | cut -d ':' -f 2 | cut -d ' ' -f 2)

echo "Image: ${RASPBIAN_IMG}.img"
echo "Size: ${RASPBIAN_SIZE}"

echo "Unmounting SD Card Volume /dev/${TARGET}s1..."
sudo diskutil unmount /dev/${TARGET}s1

echo "Flashing SD Card (/dev/r${TARGET})..."
if hash pv 2>/dev/null; then
  COMMAND="dd if=${DIR}/${RASPBIAN_IMG}.img | pv -s ${RASPBIAN_SIZE} | dd of=/dev/r${TARGET} bs=1m"
else
  COMMAND="dd if=${DIR}/${RASPBIAN_IMG}.img of=/dev/r${TARGET} bs=1m"
fi
sudo sh -c "${COMMAND}"

echo "Configuring ssh..."
sleep 5
touch /Volumes/boot/ssh
echo "dwc_otg.lpm_enable=0 console=tty1 root=PARTUUID=$PARTUUID rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait modules-load=dwc2,g_ether quiet init=/usr/lib/raspi-config/init_resize.sh splash plymouth.ignore-serial-consoles" > /Volume/boot/cmdline.txt
cp boot/config.txt /Volume/boot/config.txt

echo "Ejecting SD Card..."
sleep 5
sudo diskutil eject /dev/${TARGET}
