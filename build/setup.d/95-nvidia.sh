#!/bin/bash

# See https://github.com/NVIDIA/nvidia-docker/wiki/Deploy-on-Amazon-EC2
# But we're using the run script to not depend on build tools
set -euo pipefail

DRIVER_ARCH="Linux-x86_64"
DRIVER_VERSION="384.90"
DRIVER_FILENAME="NVIDIA-${DRIVER_ARCH}-${DRIVER_VERSION}.run"
DRIVER_CHECKSUM="0ddf6820f2fcca3ec3021e42a028f8bc08bca123fcea4c0c3f41c8c0ffa5febd"

DOCKER_DRIVER_VERSION="1.0.1"
DOCKER_DRIVER_FILENAME="nvidia-docker_${DOCKER_DRIVER_VERSION}-1_amd64.deb"


apt-get update

pkgs="
build-essential
linux-headers-virtual-lts-xenial
"

# find latest headers
kernelname=$(ls -lah /usr/src/ | tail -n1 | sed 's/.*linux-headers-\([0-9a-z.-]\+\).*/\1/')
apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs >>install.log

echo "Installing NVIDIA driver ver: ${DRIVER_VERSION}"

# Using the run File
wget -P /tmp "http://us.download.nvidia.com/XFree86/${DRIVER_ARCH}/${DRIVER_VERSION}/${DRIVER_FILENAME}"

echo "$DRIVER_CHECKSUM /tmp/$DRIVER_FILENAME" | sha256sum -c

chmod +x "/tmp/${DRIVER_FILENAME}"

/tmp/$DRIVER_FILENAME -e -a -s --kernel-source-path "/usr/src/linux-headers-${kernelname}/" --kernel-name "${kernelname}"

echo "Installing nvidia docker ver: ${DOCKER_DRIVER_VERSION}"
wget -P /tmp "https://github.com/NVIDIA/nvidia-docker/releases/download/v${DOCKER_DRIVER_VERSION}/${DOCKER_DRIVER_FILENAME}"
dpkg -i "/tmp/${DOCKER_DRIVER_FILENAME}"

echo "Removing build packages driver"
apt-get purge -y -q  $pkgs >>install.log
