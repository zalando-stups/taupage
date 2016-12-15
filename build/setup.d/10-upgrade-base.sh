#!/bin/bash

set -x

echo "Updating system..."

# sudo rm -rf /var/lib/apt/lists/*
apt-get update -y  # -q >>/tmp/build/upgrade.log

# install 3.16. LTS kernel and make sure it updates to the last version
apt-get install -y linux-image-virtual-lts-utopic

apt-mark hold openssh-server
apt-get install -y --only-upgrade libc6 libssl1.0.0
#apt-get dist-upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y # -q  >>/tmp/build/upgrade.log
#aptitude unhold openssh-server
