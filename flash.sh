#!/usr/bin/env bash

RASPBIAN_DISTRO="raspbian_lite"        # || raspbian
RASPBIAN_FLAVOR="raspbian-jessie-lite" # || raspbian-jessie
RASPBIAN_RELEASE="2017-01-10"
RASPBIAN_VERSION="2017-01-11"

RASPBIAN_URL="http://downloads.raspberrypi.org/${RASPBIAN_DISTRO}/images/${RASPBIAN_DISTRO}-${RASPBIAN_RELEASE}/${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.zip"

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
  unzip ${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.zip
fi
RASPBIAN_SIZE=$(stat -x ${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.img | grep Size | cut -d ':' -f 2 | cut -d ' ' -f 2)
echo "Image: ${RASPBIAN_VERSION}-${RASPBIAN_FLAVOR}.img"
echo "Size: ${RASPBIAN_SIZE}"

echo "Unmounting SD Card Volume /dev/${TARGET}s1..."
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
