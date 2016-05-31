#!/bin/bash

# These packages will be deleted in order to have a PCI DSS compatible image
pkgs="
build-essential
laptop-detect
"

echo "Installing packages..."

apt-get remove --purge -y -q $pkgs >>remove.log
apt-get clean >>remove.log