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
  sleep 5

echo "Bootstraping..."
  sleep 5
  ssh pi "mkdir -p ~/.ssh && echo $PUBLIC_KEY > .ssh/authorized_keys"
  scp $DIR/home/{.bash_aliases,.bashrc} pi:
  scp $DIR/etc/locale.gen pi: && ssh pi "sudo mv /home/pi/locale.gen /etc/locale.gen"
  scp $DIR/etc/default/locale pi: && ssh pi "sudo mv /home/pi/locale /etc/default/locale && sudo locale-gen"
  scp $DIR/etc/ssh/sshd_config pi: && ssh pi "sudo mv /home/pi/sshd_config /etc/ssh/sshd_config" && ssh pi "sudo systemctl restart ssh"

echo "Waiting for ssh..."
  while ! ping -c1 raspberrypi.local &>/dev/null; do :; done
  sleep 15

echo "Installing..."
ssh pi << 'EOF'
  echo "Dependencies..."
    sudo apt-get update
    sudo apt-get -y dist-upgrade
    sudo apt-get -y install \
      ca-certificates \
      git \
      vim \
      htop \
      iotop
    sudo apt-get autoremove -y --purge
    sudo apt-get -y clean
    wget https://bootstrap.pypa.io/get-pip.py
    sudo python get-pip.py
    rm get-pip.py
    curl -fsSL get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker pi
    rm get-docker.sh
EOF
ssh pi "sudo pip install docker-compose"
