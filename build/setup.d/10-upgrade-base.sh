#!/bin/bash

set -x

echo "Updating system..."

# sudo rm -rf /var/lib/apt/lists/*
apt-get update -y  # -q >>/tmp/build/upgrade.log

echo "nvme" >> /etc/initramfs-tools/modules

# install kernel headers and dkms
apt-get install -y linux-headers-virtual-lts-xenial dkms

function configure_dkms() {
    local PACKAGE_NAME=$1
    local PACKAGE_VERSION=$2
    local MODULE_NAME=$3
    local MODULE_LOCATION=$4

    cat > ${PACKAGE_NAME}-${PACKAGE_VERSION}/dkms.conf << EOF
PACKAGE_NAME="${MODULE_NAME}"
PACKAGE_VERSION="${PACKAGE_VERSION}"
CLEAN="cd ${MODULE_LOCATION}; make clean"
MAKE="cd ${MODULE_LOCATION}; make BUILD_KERNEL=\${kernelver}"
BUILT_MODULE_LOCATION[0]="${MODULE_LOCATION}"
BUILT_MODULE_NAME[0]="${MODULE_NAME}"
DEST_MODULE_LOCATION[0]="/updates"
DEST_MODULE_NAME[0]="${MODULE_NAME}"
AUTOINSTALL="yes"
EOF

    dkms add -m ${PACKAGE_NAME} -v ${PACKAGE_VERSION}
}

pushd /usr/src
# download and configure ixgbevf: https://downloadcenter.intel.com/download/27160/
IXGBEVF_VERSION=4.2.1
IXGBEVF_DOWNLOAD=27160 # If you are changing VERSION, don't forget to update this id and MD5 sum on the line below
IXGBEVF_MD5=1e6bb9804cd475872db82f487e28e45f
curl --fail -s -L https://downloadmirror.intel.com/${IXGBEVF_DOWNLOAD}/eng/ixgbevf-${IXGBEVF_VERSION}.tar.gz > ixgbevf-${IXGBEVF_VERSION}.tar.gz
if [[ $(md5sum ixgbevf-${IXGBEVF_VERSION}.tar.gz | awk '{print $1}') != $IXGBEVF_MD5 ]]; then
    echo "ixgbevf-${IXGBEVF_VERSION}.tar.gz: bad md5 sum"
    exit 1
fi
tar xzf ixgbevf-${IXGBEVF_VERSION}.tar.gz && rm ixgbevf-${IXGBEVF_VERSION}.tar.gz
configure_dkms ixgbevf ${IXGBEVF_VERSION} ixgbevf src/

# download and configure ena
ENA_VERSION=1.2.0
curl --fail -L https://github.com/amzn/amzn-drivers/archive/ena_linux_${ENA_VERSION}.tar.gz | tar xz
# We don't know checksums of archives on github
mv amzn-drivers-ena_linux_${ENA_VERSION} amzn-drivers-${ENA_VERSION}
configure_dkms amzn-drivers ${ENA_VERSION} ena kernel/linux/ena
popd

# install 3.16. LTS kernel and make sure it updates to the last version
# also this step should build ixgbevf and ena kernel modules and put them into initramfs
apt-get install -y linux-image-virtual-lts-xenial

#do not restart services on dist-upgrade, because the way we connect to ec2 via ssh and proxycommand nc get's broken if openssh-server get's updatet (and restartet)
#as of now we do not expect the file to be present. Thus we stop here, if it is.
[ -f /usr/sbin/policy-rc.d ] && exit 1
echo -e '#!/bin/sh\n\nexit 101' >/usr/sbin/policy-rc.d
chmod +x /usr/sbin/policy-rc.d
apt-get dist-upgrade -y
rm /usr/sbin/policy-rc.d
