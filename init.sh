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
    DEBIAN_FRONTEND=noninteractive sudo apt-get -y --force-yes dist-upgrade
    DEBIAN_FRONTEND=noninteractive sudo apt-get -y --force-yes install \
      ca-certificates \
      git \
      build-essential \
      autoconf \
      automake \
      libtool \
      pkg-config \
      libusb-1.0-0-dev\
      libftdi-dev \
      libffi-dev \
      libssl-dev \
      python-dev \
      libxslt1-dev \
      libxml2-dev \
      python3-dev \
      picocom \
      vim \
      tmux
    sudo apt-get autoremove -y --purge
    sudo apt-get -y clean
    wget https://bootstrap.pypa.io/get-pip.py
    sudo python get-pip.py
    PYTHON2_VERSION=$(python --version 2>&1 | egrep -o '2\.[0-9]+')
    PYTHON2_PACKAGES_DIR="/usr/local/lib/python$PYTHON2_VERSION/dist-packages"
    rm get-pip.py

  echo "┌───────────┐"
  echo "│ Butterfly │"
  echo "└───────────┘"
    sudo pip install -U butterfly==2.0.2
    # suppress warnings on close
    EVENT_REPLACE="s/beforeunload\"/beforeunload_disabled\"/g"
    JS_ASSEST_DIR="$PYTHON2_PACKAGES_DIR/butterfly/static"
    sudo sed -i "$EVENT_REPLACE" $JS_ASSEST_DIR/ext.min.js
    sudo sed -i "$EVENT_REPLACE" $JS_ASSEST_DIR/main.min.js

  echo "┌─────────┐"
  echo "│ Node.js │"
  echo "└─────────┘"
    NODE_VERSION="v6.10.2"
    NODE_PACKAGE="node-$NODE_VERSION-linux-armv6l"
    rm -rf /tmp/node
    mkdir -p /tmp/node
    curl -o /tmp/node/$NODE_PACKAGE.tar.xz https://nodejs.org/dist/$NODE_VERSION/$NODE_PACKAGE.tar.xz
    cd /tmp/node
    rm /tmp/node/$NODE_PACKAGE
    tar xvf $NODE_PACKAGE.tar.xz
    sudo rm -rf /opt/node
    sudo mv /tmp/node/$NODE_PACKAGE /opt/node
    sudo ln -sf /opt/node/bin/node /usr/local/bin/node
    sudo ln -sf /opt/node/bin/npm /usr/local/bin/npm
    rm -rf /tmp/node
    npm install -g bower
    sudo ln -sf /opt/node/bin/bower /usr/local/bin/bower

  echo "┌────────┐"
  echo "│ Cloud9 │"
  echo "└────────┘"
    rm -rf /home/pi/.c9/node_modules
    if [ ! -d /home/pi/.c9 ]; then
      git clone --depth 1 --branch docker https://github.com/ddm/core.git /home/pi/.c9
      cd /home/pi/.c9
    else
      cd /home/pi/.c9
      git reset HEAD --hard && git pull origin docker
    fi
    find -path node_modules -prune -type d -print0 | xargs -t -I {} cd {} && npm install
    cd /home/pi/.c9
    npm install https://github.com/ddm/pty.js.git
    npm install
    sudo pip install -U ikpdb

  echo "┌────────┐"
  echo "│ RadAPI │"
  echo "└────────┘"
    if [ ! -d /home/pi/radapi ]; then
      git clone --depth 1 https://github.com/ddm/radapi /home/pi/radapi
      cd /home/pi/radapi
    else
      cd /home/pi/radapi
      git reset HEAD --hard && git pull origin master
    fi
    mkdir -p /home/pi/radapi/data
    npm install \
      express \
      node-red \
      node-red-node-swagger \
      underscore \
      async
    bower install

  echo "┌─────────┐"
  echo "│ Jupyter │"
  echo "└─────────┘"
    sudo pip install -U requests skidl notebook
    mkdir -p $HOME/notebooks
    # enable in iframes
    sudo sed -i "s/\"frame-ancestors 'self'\",//g" $PYTHON2_PACKAGES_DIR/notebook/base/handlers.py

  echo "┌───────────────────────┐"
  echo "│ KiCad Library (skidl) │"
  echo "└───────────────────────┘"
    if [ ! -d /home/pi/kicad-library ]; then
      git clone --depth 1 https://github.com/KiCad/kicad-library.git /home/pi/kicad-library
    else
      cd /home/pi/kicad-library
      git reset HEAD --hard && git pull origin master
    fi

  echo "┌─────────┐"
  echo "│ PCBmodE │"
  echo "└─────────┘"
    if [ ! -d /home/pi/pcbmode ]; then
      git clone --depth 1 https://github.com/boldport/pcbmode.git /home/pi/pcbmode
      cd /home/pi/pcbmode
    else
      cd /home/pi/pcbmode
      git reset HEAD --hard && git pull origin master
    fi
    sudo python setup.py install

  echo "┌──────────────┐"
  echo "│ ice40 Viewer │"
  echo "└──────────────┘"
    if [ ! -d /home/pi/ice40_viewer ]; then
      git clone --depth 1 https://github.com/knielsen/ice40_viewer.git /home/pi/ice40_viewer
    else
      cd /home/pi/ice40_viewer
      git reset HEAD --hard && git pull origin master
    fi

  echo "┌──────────┐"
  echo "│ icetools │"
  echo "└──────────┘"
    if [ ! -d /home/pi/icetools ]; then
      git clone --depth 1 https://github.com/ddm/icetools.git /home/pi/icetools
      cd /home/pi/icetools
    else
      cd /home/pi/icetools
      git reset HEAD --hard && git pull origin master
    fi
    ./icetools.sh

  echo "┌─────────┐"
  echo "│ OpenOCD │"
  echo "└─────────┘"
    if [ ! -d /home/pi/openocd ]; then
      git clone --depth 1 git://git.code.sf.net/p/openocd/code /home/pi/openocd
      cd /home/pi/openocd
    else
      cd /home/pi/openocd
      git reset HEAD --hard && git pull origin master
    fi
    ./bootstrap
    ./configure --enable-sysfsgpio --enable-bcm2835gpio
    make
    sudo make install
EOF

echo "Configuring..."
  scp $DIR/radapi/data/*   pi:/home/pi/radapi/data/
  scp $DIR/radapi/public/* pi:/home/pi/radapi/public/
  scp $DIR/radapi/index.js pi:/home/pi/radapi/index.js
  scp $DIR/radapi/radapi.service pi:
  scp $DIR/notebook/*.ipynb pi:/home/pi/notebooks/
  scp $DIR/notebook/notebook.service pi:
  scp $DIR/butterfly/butterfly.service pi:
  scp $DIR/c9/c9.service pi:
ssh pi << 'EOF'
  sudo mv /home/pi/radapi.service /etc/systemd/system/
  sudo mv /home/pi/notebook.service /etc/systemd/system/
  sudo mv /home/pi/butterfly.service /etc/systemd/system/
  sudo mv /home/pi/c9.service /etc/systemd/system/
  sudo systemctl enable radapi.service
  sudo systemctl enable notebook.service
  sudo systemctl enable butterfly.service
  sudo systemctl enable c9.service
  sudo reboot
EOF
