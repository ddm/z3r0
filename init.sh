#!/usr/bin/env bash

DIR=`dirname $0`

# Expected ~/.ssh/config:
# Host pi
#     Hostname raspberrypi.local
#     Port 22
#     User pi
#     IdentityFile ~/.ssh/pi
#     IdentitiesOnly yes
#     StrictHostKeyChecking no
#     UserKnownHostsFile=/dev/null
PUBLIC_KEY=$(cat $HOME/.ssh/pi.pub)

echo "Waiting for Raspberry Pi..."
while ! ping -c1 raspberrypi.local &>/dev/null; do :; done # Wait for network
sleep 10 # Wait for ssh

echo "Bootstraping..."
ssh pi "mkdir -p ~/.ssh && echo $PUBLIC_KEY > .ssh/authorized_keys"
scp -rp ./home/* pi:
ssh pi "sudo mv ~/locale.gen /etc/locale.gen && sudo mv ~/locale /etc/default/locale && sudo locale-gen"

echo "Installing..."
ssh pi << 'EOF'
  echo "Dependencies..."
  sudo apt-get update
  sudo apt-get install -y git build-essential autoconf automake libtool pkg-config libusb-1.0 libusb-dev libftdi-dev
  sudo apt-get clean
  echo "OpenOCD..."
  git clone --depth 1 git://git.code.sf.net/p/openocd/code /home/pi/openocd
  cd /home/pi/openocd/
  ./bootstrap
  ./configure --enable-sysfsgpio --enable-bcm2835gpio
  make
  sudo make install
  echo "Node.js..."
  export NODE_VERSION="v6.9.1"
  sudo mkdir -p /opt/node/
  sudo chown pi:pi /opt/node/
  export NODE_PACKAGE="node-$NODE_VERSION-linux-armv6l"
  curl -o /opt/node/$NODE_PACKAGE.tar.xz https://nodejs.org/dist/$NODE_VERSION/$NODE_PACKAGE.tar.xz
  cd /opt/node/
  tar xf $NODE_PACKAGE.tar.xz
  rm /opt/node/$NODE_PACKAGE.tar.xz
  ln -s /opt/node/$NODE_PACKAGE /opt/node/latest
  export PATH="$PATH:/opt/node/latest/bin/"
  echo "RadAPI..."
  git clone --depth 1 https://github.com/ddm/radapi /opt/node/radapi
  cd /opt/node/radapi
  npm install
  mkdir -p /opt/node/radapi/data/
EOF

echo "Configuring RadAPI..."
scp $DIR/radapi/public/* pi:/opt/node/radapi/public/
scp $DIR/radapi/data/* pi:/opt/node/radapi/data/
scp $DIR/radapi/index.js pi:/opt/node/radapi/index.js
scp $DIR/radapi/radapi.service pi:
ssh pi << 'EOF'
  sudo chown root:root /home/pi/radapi.service
  sudo mv /home/pi/radapi.service /etc/systemd/system/
  sudo systemctl enable radapi.service
  sudo reboot
EOF
