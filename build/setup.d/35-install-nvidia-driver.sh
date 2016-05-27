#!/bin/bash

# See https://github.com/NVIDIA/nvidia-docker/wiki/Deploy-on-Amazon-EC2

echo "Installing NVIDIA driver"

# The following packages are required for the driver to install
pkgs="
gcc
make
libc-dev
"
apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs >>install.log

# Download the driver package.
wget -P /tmp http://us.download.nvidia.com/XFree86/Linux-x86_64/361.42/NVIDIA-Linux-x86_64-361.42.run

# Run the driver installation
sh /tmp/NVIDIA-Linux-x86_64-361.42.run --no-questions --accept-license --ui=none

# Load the UVM module
nvidia-modprobe nvidia-uvm
if [ "$?" -eq 0 ]; then
  # Find out the major device number used by the nvidia-uvm driver
  D=`grep nvidia-uvm /proc/devices | awk '{print $1}'`
  mknod -m 666 /dev/nvidia-uvm c $D 0
fi
