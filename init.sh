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

echo "Waiting for raspberrypi.local..."
  while ! ping -c1 raspberrypi.local &>/dev/null; do :; done
  sleep 15

echo "Bootstraping..."
  ssh pi "mkdir -p ~/.ssh && echo $PUBLIC_KEY > .ssh/authorized_keys"
  scp $DIR/home/* pi:
  scp $DIR/home/.* pi:
  scp $DIR/apt/sources.list pi:
  ssh pi "sudo mv ~/*.list /etc/apt/sources.list.d/"
  ssh pi "sudo mv ~/locale.gen /etc/locale.gen && sudo mv ~/locale /etc/default/locale && sudo locale-gen"
  ssh pi "sudo apt-get update"
  scp $DIR/ssh/sshd_config pi:
  ssh pi "sudo mv /home/pi/sshd_config /etc/ssh/sshd_config"
  ssh pi "sudo systemctl restart ssh"

echo "Waiting for ssh..."
  while ! ping -c1 raspberrypi.local &>/dev/null; do :; done
  sleep 15

echo "Installing..."
ssh pi << 'EOF'
  echo "Dependencies..."
    sudo apt update
    sudo apt -y --force-yes full-upgrade
    sudo apt -y --force-yes install \
      ca-certificates \
      git \
      vim \
      htop \
      iotop
    sudo apt-get autoremove -y --purge
    sudo apt-get -y clean
    wget https://bootstrap.pypa.io/get-pip.py
    sudo python get-pip.py
    PYTHON2_VERSION=$(python --version 2>&1 | egrep -o '2\.[0-9]+')
    PYTHON2_PACKAGES_DIR="/usr/local/lib/python$PYTHON2_VERSION/dist-packages"
    git config --global user.name  ddm
    git config --global user.email ddm@0x01.be
    rm get-pip.py
    curl -fsSL get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker pi
    rm get-docker.sh
EOF
