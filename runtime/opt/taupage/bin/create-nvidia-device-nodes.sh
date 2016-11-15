#!/bin/sh
# This script creates the NVIDIA device nodes.
# Its contents have adapted from the CUDA Linux installation guide at:
# http://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#runfile-verifications
#
# The relevant section is listed under "Device Node Verification".
#
# One way to ensure that this is executed at startup, is to add the file to
# /etc/init.d/ and create a symlink to this file in /etc/rc2.d/
#

echo "Loading NVIDIA drivers" 2>&1 | logger -t create-nvidia-device-nodes -s 2>/dev/console

NV_MODPROBE=$(which nvidia-modprobe)
if [ "$?" -ne 0 ]; then
  echo "nvidia-modprobe not installed"  2>&1 | logger -t create-nvidia-device-nodes -s 2>/dev/console
  exit 0
fi


# Load the nvidia kernel module
# /sbin/modprobe nvidia 2>&1 | logger -t create-nvidia-device-nodes -s 2>/dev/console
nvidia-modprobe 2>&1 | logger -t create-nvidia-device-nodes -s 2>/dev/console

if [ "$?" -eq 0 ]; then
  # Count the number of NVIDIA controllers found.
  NVDEVS=`lspci | grep -i NVIDIA`
  N3D=`echo "$NVDEVS" | grep "3D controller" | wc -l`
  NVGA=`echo "$NVDEVS" | grep "VGA compatible controller" | wc -l`

  N=`expr $N3D + $NVGA - 1`
  Np1=`expr $N + 1`
  echo "Found $Np1 NVIDIA device(s)" | logger -t create-nvidia-device-nodes -s 2>/dev/console
  for i in `seq 0 $N`; do
    NODENAME="/dev/nvidia$i"
    if [ ! -e $NODENAME ]; then
      echo "Creating $NODENAME" | logger -t create-nvidia-device-nodes -s 2>/dev/console
      mknod -m 666 $NODENAME c 195 $i
    else
      echo "$NODENAME already exists" | logger -t create-nvidia-device-nodes -s 2>/dev/console
    fi
  done

  NODENAME="/dev/nvidiactl"
  if [ ! -e $NODENAME ]; then
    echo "Creating $NODENAME" | logger -t create-nvidia-device-nodes -s 2>/dev/console
    mknod -m 666 $NODENAME c 195 255
  else
    echo "$NODENAME already exists" | logger -t create-nvidia-device-nodes -s 2>/dev/console
  fi

else
  echo "Could not load NVIDIA module" | logger -t create-nvidia-device-nodes -s 2>/dev/console
  exit 1
fi

# Load the UVM module
# /sbin/modprobe nvidia-uvm 2>&1 | logger -t create-nvidia-device-nodes -s 2>/dev/console
nvidia-modprobe -u 2>&1 | logger -t create-nvidia-device-nodes -s 2>/dev/console

if [ "$?" -eq 0 ]; then
  # Find out the major device number used by the nvidia-uvm driver
  D=`grep nvidia-uvm /proc/devices | awk '{print $1}'`

  NODENAME="/dev/nvidia-uvm"
  if [ ! -e $NODENAME ]; then
    echo "Creating $NODENAME" | logger -t create-nvidia-device-nodes -s 2>/dev/console
    mknod -m 666 $NODENAME c $D 0
  else
    echo "$NODENAME already exists" | logger -t create-nvidia-device-nodes -s 2>/dev/console
  fi

else
  echo "Could not load NVIDIA UVM module" | logger -t create-nvidia-device-nodes -s 2>/dev/console
  exit 2
fi

exit 0
