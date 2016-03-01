#!/bin/bash

set -x

echo "Updating system..."

# sudo rm -rf /var/lib/apt/lists/*
apt-get update -y  # -q >>/tmp/build/upgrade.log
apt-mark hold openssh-server
apt-get install --only-upgrade libc6 libssl1.0.0
#apt-get dist-upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y # -q  >>/tmp/build/upgrade.log
#aptitude unhold openssh-server
