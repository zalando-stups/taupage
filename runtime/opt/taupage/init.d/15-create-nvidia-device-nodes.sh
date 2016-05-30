#!/bin/bash

# This script creates the NVIDIA device nodes.
# Its contents have adapted from the CUDA Linux installation guide at:
# http://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#runfile-verifications
#
# The relevant section is listed under "Device Node Verification".
#
# One way to ensure that this is executed at startup, is to add the file to
# /etc/init.d/ and create a symlink to this file in /etc/rc2.d/
#

/sbin/modprobe nvidia
if [ "$?" -eq 0 ]; then
  # Count the number of NVIDIA controllers found.
  NVDEVS=`lspci | grep -i NVIDIA`
  N3D=`echo "$NVDEVS" | grep "3D controller" | wc -l`
  NVGA=`echo "$NVDEVS" | grep "VGA compatible controller" | wc -l`

  N=`expr $N3D + $NVGA - 1`
  for i in `seq 0 $N`; do
    if [ ! -e "/dev/nvidia$i" ]; then
      mknod -m 666 "/dev/nvidia$i" c 195 $i
    fi
  done

  if [ ! -e /dev/nvidiactl ]; then
    mknod -m 666 /dev/nvidiactl c 195 255
  fi

else
  exit 1
fi

/sbin/modprobe nvidia-uvm

if [ "$?" -eq 0 ]; then
  # Find out the major device number used by the nvidia-uvm driver
  D=`grep nvidia-uvm /proc/devices | awk '{print $1}'`

  if [ ! -e /dev/nvidia-uvm ]; then
    mknod -m 666 /dev/nvidia-uvm c $D 0
  fi
else
  exit 1
fi
