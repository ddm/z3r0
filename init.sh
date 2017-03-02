#!/usr/bin/env bash

pushd `dirname $0` > /dev/null
DIR=`pwd -P`
popd > /dev/null

# Expected ~/.ssh/config:
# Host pi
#     Hostname raspberrypi.local
#     Port 22
#     User pi
#     IdentityFile ~/.ssh/pi
#     IdentitiesOnly yes
#     StrictHostKeyChecking no
#     UserKnownHostsFile=/dev/null
if [ ! -f $HOME/.ssh/pi.pub ]; then
  echo "Expected $HOME/.ssh/pi.pub public key."
  exit 1
fi
PUBLIC_KEY=$(cat $HOME/.ssh/pi.pub)

echo "Waiting..."
  while ! ping -c1 raspberrypi.local &>/dev/null; do :; done # Wait for network
  sleep 15 # Wait for ssh

echo "Bootstraping..."
  ssh pi "mkdir -p ~/.ssh && echo $PUBLIC_KEY > .ssh/authorized_keys"
  scp ./home/* pi:
  scp ./home/.* pi:
  ssh pi "sudo mv ~/locale.gen /etc/locale.gen && sudo mv ~/locale /etc/default/locale && sudo locale-gen"

echo "Installing..."
ssh pi << 'EOF'
  echo "Dependencies..."
    sudo apt-get update
    sudo apt-get -y --force-yes dist-upgrade
    sudo apt-get -y --force-yes install git build-essential autoconf automake libtool pkg-config libusb-dev libftdi-dev libffi-dev libssl-dev python-dev libxslt1-dev libxml2-dev python3-dev picocom vim tmux
    sudo apt-get autoremove -y --purge
    sudo apt-get -y clean
    rm get-pip.*
    wget https://bootstrap.pypa.io/get-pip.py
    sudo python get-pip.py
    PYTHON2_VERSION=$(python --version 2>&1 | egrep -o '2\.[0-9]+')
    PYTHON2_PACKAGES_DIR="/usr/local/lib/python$PYTHON2_VERSION/dist-packages"

  echo "┌───────────┐"
  echo "│ Butterfly │"
  echo "└───────────┘"
    sudo pip install -U butterfly
    # suppress warnings on close
    EVENT_REPLACE="s/beforeunload\"/beforeunload_disabled\"/g"
    JS_ASSEST_DIR="$PYTHON2_PACKAGES_DIR/butterfly/static"
    sudo sed -i "$EVENT_REPLACE" $JS_ASSEST_DIR/ext.min.js
    sudo sed -i "$EVENT_REPLACE" $JS_ASSEST_DIR/main.min.js

  echo "┌─────────┐"
  echo "│ Node.js │"
  echo "└─────────┘"
    NODE_VERSION="v7.7.1"
    sudo mkdir -p /opt/node/ && sudo chown pi:pi /opt/node/
    NODE_PACKAGE="node-$NODE_VERSION-linux-armv6l"
    curl -o /opt/node/$NODE_PACKAGE.tar.xz https://nodejs.org/dist/$NODE_VERSION/$NODE_PACKAGE.tar.xz
    cd /opt/node/
    rm -rf /opt/node/$NODE_PACKAGE
    tar xf $NODE_PACKAGE.tar.xz
    rm /opt/node/$NODE_PACKAGE.tar.xz
    rm /opt/node/latest
    ln -s /opt/node/$NODE_PACKAGE /opt/node/latest
    echo "$PATH" | grep -q 'node' || export PATH="/opt/node/latest/bin/:$PATH"

  echo "┌────────┐"
  echo "│ RadAPI │"
  echo "└────────┘"
    if [ ! -d /opt/node/radapi ]; then
      git clone --depth 1 https://github.com/ddm/radapi /opt/node/radapi
      cd /opt/node/radapi
    else
      cd /opt/node/radapi
      git pull origin master
    fi
    mkdir -p /opt/node/radapi/data/
    npm install express node-red node-red-node-swagger underscore async
    npm install -g bower
    bower install

  echo "┌─────────┐"
  echo "│ Jupyter │"
  echo "└─────────┘"
    sudo pip install -U requests skidl notebook
    mkdir -p $HOME/notebooks/
    # enable in iframes
    sudo sed -i "s/\"frame-ancestors 'self'\",//g" $PYTHON2_PACKAGES_DIR/notebook/base/handlers.py

  echo "┌───────────────────────┐"
  echo "│ KiCad Library (skidl) │"
  echo "└───────────────────────┘"
    sudo mkdir -p /opt/pcb/ && sudo chown pi:pi /opt/pcb/
    if [ ! -d /opt/pcb/kicad-library ]; then
      git clone --depth 1 https://github.com/KiCad/kicad-library.git /opt/pcb/kicad-library
      cd /opt/pcb/kicad-library
    else
      cd /opt/pcb/kicad-library
      git pull origin master
    fi

  echo "┌─────────┐"
  echo "│ PCBmodE │"
  echo "└─────────┘"
    sudo mkdir -p /opt/pcb/ && sudo chown pi:pi /opt/pcb/
    if [ ! -d /opt/pcb/pcbmode ]; then
      git clone --depth 1 https://github.com/boldport/pcbmode.git /opt/pcb/pcbmode
      cd /opt/pcb/pcbmode
    else
      cd /opt/pcb/pcbmode
      git pull origin master
    fi
    sudo python setup.py install

  echo "┌──────────────┐"
  echo "│ ice40 Viewer │"
  echo "└──────────────┘"
    sudo mkdir -p /opt/fpga/ && sudo chown pi:pi /opt/fpga/
    if [ ! -d /opt/fpga/ice40_viewer ]; then
      git clone --depth 1 https://github.com/knielsen/ice40_viewer.git /opt/fpga/ice40_viewer
    else
      cd /opt/fpga/ice40_viewer
      git pull origin master
    fi

  echo "┌──────────┐"
  echo "│ icetools │"
  echo "└──────────┘"
    if [ ! -d /opt/fpga/icetools ]; then
      git clone --depth 1 https://github.com/ddm/icetools.git /opt/fpga/icetools
      cd /opt/fpga/icetools
    else
      cd /opt/fpga/icetools
      git pull origin master
    fi
    ./icetools.sh

  echo "┌─────────┐"
  echo "│ OpenOCD │"
  echo "└─────────┘"
    rm -rf /home/pi/openocd
    git clone --depth 1 git://git.code.sf.net/p/openocd/code /home/pi/openocd
    cd /home/pi/openocd/
    ./bootstrap
    ./configure --enable-sysfsgpio --enable-bcm2835gpio
    make
    sudo make install
EOF

echo "Configuring..."
  scp $DIR/radapi/data/*   pi:/opt/node/radapi/data/
  scp $DIR/radapi/public/* pi:/opt/node/radapi/public/
  scp $DIR/radapi/index.js pi:/opt/node/radapi/index.js
  scp $DIR/radapi/radapi.service pi:
  scp $DIR/notebook/*.ipynb pi:/home/pi/notebooks/
  scp $DIR/notebook/notebook.service pi:
  scp $DIR/butterfly/butterfly.service pi:
ssh pi << 'EOF'
  sudo mv /home/pi/radapi.service /etc/systemd/system/
  sudo mv /home/pi/notebook.service /etc/systemd/system/
  sudo mv /home/pi/butterfly.service /etc/systemd/system/
  sudo systemctl enable radapi.service
  sudo systemctl enable notebook.service
  sudo systemctl enable butterfly.service
  sudo reboot
EOF
