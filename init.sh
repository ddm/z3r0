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
PUBLIC_KEY=$(cat $HOME/.ssh/pi.pub)

echo "Waiting for Raspberry Pi..."
while ! ping -c1 raspberrypi.local &>/dev/null; do :; done # Wait for network
sleep 10 # Wait for ssh

echo "Bootstraping..."
ssh pi "mkdir -p ~/.ssh && echo $PUBLIC_KEY > .ssh/authorized_keys"
scp ./home/* pi:
scp ./home/.* pi:
ssh pi "sudo mv ~/locale.gen /etc/locale.gen && sudo mv ~/locale /etc/default/locale && sudo locale-gen"

echo "Installing..."
ssh pi << 'EOF'
  echo "Dependencies..."
    sudo apt-get update
    sudo apt-get dist-upgrade -y
    sudo apt-get install -y git build-essential autoconf automake libtool pkg-config libusb-1.0 libusb-dev libftdi-dev libffi-dev libssl-dev python-dev picocom vim tmux
    sudo apt-get autoremove --purge
    sudo apt-get clean
    wget https://bootstrap.pypa.io/get-pip.py
    sudo python get-pip.py
  echo "Node.js..."
    export NODE_VERSION="v7.5.0"
    sudo mkdir -p /opt/node/
    sudo chown pi:pi /opt/node/
    export NODE_PACKAGE="node-$NODE_VERSION-linux-armv6l"
    curl -o /opt/node/$NODE_PACKAGE.tar.xz https://nodejs.org/dist/$NODE_VERSION/$NODE_PACKAGE.tar.xz
    cd /opt/node/
    tar xf $NODE_PACKAGE.tar.xz
    rm /opt/node/$NODE_PACKAGE.tar.xz
    ln -s /opt/node/$NODE_PACKAGE /opt/node/latest
    export PATH="/opt/node/latest/bin/:$PATH"
  echo "RadAPI..."
    git clone --depth 1 https://github.com/ddm/radapi /opt/node/radapi
    mkdir -p /opt/node/radapi/data/
    cd /opt/node/radapi
    npm install || echo ""
    sudo chown -R pi:pi /opt/node/radapi
  echo "Jupyter..."
    sudo pip install requests notebook
    mkdir -p $HOME/notebooks/
    # enable in iframes
    sudo sed -i "s/\"frame-ancestors 'self'\",//g" /usr/local/lib/python$(python --version 2>&1 | egrep -o '2\.[0-9]+')/dist-packages/notebook/base/handlers.py
  echo "Butterfy..."
    sudo pip install butterfly
    # suppress warnings on close
    sudo sed -i "s/beforeunload/beforeunload_disabled/g" /usr/local/lib/python$(python --version 2>&1 | egrep -o '2\.[0-9]+')/dist-packages/butterfly/static/ext.min.js
    sudo sed -i "s/beforeunload/beforeunload_disabled/g" /usr/local/lib/python$(python --version 2>&1 | egrep -o '2\.[0-9]+')/dist-packages/butterfly/static/main.min.js
  echo "OpenOCD..."
    git clone --depth 1 git://git.code.sf.net/p/openocd/code /home/pi/openocd
    cd /home/pi/openocd/
    ./bootstrap
    ./configure --enable-sysfsgpio --enable-bcm2835gpio
    make
    sudo make install
EOF

echo "Configuring RadAPI..."
scp $DIR/radapi/data/*   pi:/opt/node/radapi/data/
scp $DIR/radapi/public/* pi:/opt/node/radapi/public/
scp $DIR/radapi/index.js pi:/opt/node/radapi/index.js
scp $DIR/radapi/radapi.service pi:
ssh pi << 'EOF'
  sudo chown root:root /home/pi/radapi.service
  sudo mv /home/pi/radapi.service /etc/systemd/system/
  sudo systemctl enable radapi.service
EOF

echo "Configuring Jupyter..."
scp $DIR/notebook/*.ipynb pi:/home/pi/notebooks/
scp $DIR/notebook/notebook.service pi:
ssh pi << 'EOF'
  sudo chown root:root /home/pi/notebook.service
  sudo mv /home/pi/notebook.service /etc/systemd/system/
  sudo systemctl enable notebook.service
EOF

echo "Configuring Butterfly..."
scp $DIR/butterfly/butterfly.service pi:
ssh pi << 'EOF'
  sudo chown root:root /home/pi/butterfly.service
  sudo mv /home/pi/butterfly.service /etc/systemd/system/
  sudo systemctl enable butterfly.service
  sudo reboot
EOF
