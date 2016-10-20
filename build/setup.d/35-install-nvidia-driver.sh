#!/bin/bash

# See https://github.com/NVIDIA/nvidia-docker/wiki/Deploy-on-Amazon-EC2

echo "Installing NVIDIA driver"

# Use the CUDA repo instead of the run file.
wget -P /tmp http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64/cuda-repo-ubuntu1404_7.5-18_amd64.deb

REQUIRED_MD5_SUM="e810ded23efe35e3db63d2a92288f922"
ACTUAL_MD5_SUM=$(md5sum /tmp/cuda-repo-ubuntu1404_7.5-18_amd64.deb)
if [ x"$ACTUAL_MD5_SUM" -ne x"$REQUIRED_MD5_SUM" ]; then
	echo "MD5 Mismatch"
	echo "Got $ACTUAL_MD5_SUM (expecting $REQUIRED_MD5_SUM)"
	exit 1
fi

dpkg -i /tmp/cuda-repo-ubuntu1404_7.5-18_amd64.deb

apt-get update

pkgs="
nvidia-352-dev
nvidia-352-uvm
nvidia-352
libcuda1-352
nvidia-modprobe
"
apt-get install -y -q --no-install-recommends -o Dpkg::Options::="--force-confold" $pkgs >>install.log
