#!/usr/bin/env bash

set -e

RASPBIAN_DISTRO="raspbian_lite"        # || raspbian
RASPBIAN_FLAVOR="raspbian-jessie-lite" # || raspbian-jessie
RASPBIAN_RELEASE="2017-04-10"
RASPBIAN_VERSION="2017-04-10"
RASPBIAN_URL="http://vx2-downloads.raspberrypi.org/${RASPBIAN_DISTRO}/images/${RASPBIAN_DISTRO}-${RASPBIAN_RELEASE}/${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.zip"
EXPECTED_SHASUM="c24a4c7dd1a5957f303193fee712d0d2c0c6372d" # SHA1

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

if [ ! -f ${DIR}/${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.img ]; then
  if [ ! -f ${DIR}/${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.zip ]; then
    echo "Downloading image..."
    wget ${RASPBIAN_URL}
  fi
  ACTUAL_SHASUM=$(shasum ${DIR}/${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.zip | cut -d ' ' -f 1)
  if [[ ${ACTUAL_SHASUM} == ${EXPECTED_SHASUM} ]]; then
    echo "Matching SHA1: ${ACTUAL_SHASUM}"
    unzip ${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.zip
  else
    echo "SHA1 mismatch: expected ${EXPECTED_SHASUM} but got ${ACTUAL_SHASUM}"
    exit 1
  fi
fi
RASPBIAN_SIZE=$(stat -x ${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.img | grep Size | cut -d ':' -f 2 | cut -d ' ' -f 2)
echo "Image: ${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.img"
echo "Size: ${RASPBIAN_SIZE}"

echo "Unmounting SD Card Volume /dev/${TARGET}s1..."
# TODO Linux support
sudo diskutil unmount /dev/${TARGET}s1

echo "Flashing SD Card (/dev/r${TARGET})..."
if hash pv 2>/dev/null; then
  COMMAND="dd if=${DIR}/${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.img | pv -s ${RASPBIAN_SIZE} | dd of=/dev/r${TARGET} bs=1m"
else
  COMMAND="dd if=${DIR}/${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.img of=/dev/r${TARGET} bs=1m"
fi

sudo sh -c "${COMMAND}"
sleep 5

echo "Configuring RNDIS tethering, HDMI and ssh..."
cp ${DIR}/boot/* /Volumes/boot/

echo "Ejecting SD Card..."
sudo diskutil eject /dev/${TARGET}
