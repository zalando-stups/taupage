#!/bin/bash

set -x

echo "Updating system..."

# sudo rm -rf /var/lib/apt/lists/*
apt-get update -y  # -q >>/tmp/build/upgrade.log

# install kernel headers and dkms
apt-get install -y linux-headers-generic-lts-utopic dkms

# download and configure ixgbevf
IXGBEVF_VERSION=3.4.3
curl -L https://downloadmirror.intel.com/26572/eng/ixgbevf-${IXGBEVF_VERSION}.tar.gz | tar -C /usr/src -xz
cat > /usr/src/ixgbevf-${IXGBEVF_VERSION}/dkms.conf << EOF
PACKAGE_NAME="ixgbevf"
PACKAGE_VERSION="${IXGBEVF_VERSION}"
CLEAN="cd src/; make clean"
MAKE="cd src/; make BUILD_KERNEL=\${kernelver}"
BUILT_MODULE_LOCATION[0]="src/"
BUILT_MODULE_NAME[0]="ixgbevf"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="ixgbevf"
AUTOINSTALL="yes"
EOF

dkms add -m ixgbevf -v ${IXGBEVF_VERSION}

# install 3.16. LTS kernel and make sure it updates to the last version
# also this step should build ixgbevf kernel module and put it into initramfs
apt-get install -y linux-image-virtual-lts-utopic

# uninstall kernel headers and dkms
apt-get purge -y linux-headers-generic-lts-utopic dkms

apt-mark hold openssh-server
apt-get install -y --only-upgrade libc6 libssl1.0.0
#apt-get dist-upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y # -q  >>/tmp/build/upgrade.log
#aptitude unhold openssh-server
