#!/usr/bin/env bash

DIR=`dirname $0`
RASPBIAN_RELEASE="2016-09-28"
RASPBIAN_VERSION="2016-09-23"
if [ ! -f $DIR/$RASPBIAN_VERSION-raspbian-jessie-lite.img ]; then
  if [ ! -f $DIR/$RASPBIAN_VERSION-raspbian-jessie-lite.zip ]; then
    echo "Downloading Raspbian Jessie Lite..."
    wget http://director.downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-$RASPBIAN_RELEASE/$RASPBIAN_VERSION-raspbian-jessie-lite.zip
  fi
  unzip $RASPBIAN_VERSION-raspbian-jessie-lite.zip
fi
RASPBIAN_SIZE=$(stat -x $RASPBIAN_VERSION-raspbian-jessie-lite.img | grep Size | cut -d ":" -f 2 | cut -d " " -f 2)
echo "Image: $RASPBIAN_VERSION-raspbian-jessie-lite.img"
echo "Size: $RASPBIAN_SIZE"

echo "Unmounting SD Card Volume /dev/disk2s1..."
sudo diskutil unmount /dev/disk2s1

echo "Flashing SD Card (/dev/rdisk2)..."
COMMAND="dd if=$DIR/$RASPBIAN_VERSION-raspbian-jessie-lite.img | pv -s $RASPBIAN_SIZE | dd bs=1m of=/dev/rdisk2"
sudo sh -c "$COMMAND"
sleep 5

echo "Configuring RNDIS tethering..."
cp $DIR/boot/*.txt /Volumes/boot/

echo "Ejecting SD Card..."
sudo diskutil eject /dev/disk2
