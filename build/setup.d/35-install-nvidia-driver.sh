#!/bin/bash

# See https://github.com/NVIDIA/nvidia-docker/wiki/Deploy-on-Amazon-EC2

echo "Installing NVIDIA driver"

# Use the CUDA repo instead of the run file.
wget -P /tmp http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1404/x86_64/cuda-repo-ubuntu1404_7.5-18_amd64.deb
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
