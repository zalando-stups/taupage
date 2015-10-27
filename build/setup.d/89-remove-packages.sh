#!/bin/bash

# These packages will be deleted in order to have a PCI DSS compatible image
pkgs="
build-essential
g++
g++-4.8
gcc
gcc-4.8
laptop-detect
"

echo "Installing packages..."

apt-get remove --purge -y -q $pkgs >>remove.log
