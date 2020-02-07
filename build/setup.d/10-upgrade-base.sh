#!/bin/bash

set -x

echo "Updating system..."

# sudo rm -rf /var/lib/apt/lists/*
chmod 1777 /tmp
apt-get update -y  # -q >>/tmp/build/upgrade.log

echo "nvme" >> /etc/initramfs-tools/modules

# install kernel headers and dkms
apt-get install -y linux-headers-virtual-lts-xenial dkms

function configure_dkms() {
    local PACKAGE_NAME=$1
    local PACKAGE_VERSION=$2
    local MODULE_NAME=$3
    local MODULE_LOCATION=$4

    cat > "${PACKAGE_NAME}-${PACKAGE_VERSION}/dkms.conf" << EOF
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

    dkms add -m "${PACKAGE_NAME}" -v "${PACKAGE_VERSION}"
}

pushd /usr/src
# download and configure ixgbevf: https://downloadcenter.intel.com/download/27160/
IXGBEVF_VERSION=4.6.3
IXGBEVF_DOWNLOAD=18700 # If you are changing VERSION, don't forget to update this id and MD5 sum on the line below
IXGBEVF_SHA="82e079f1bb05587c9d70f70df2081480bce67a653cd78adceec77a53b401f78326c7e0a9cf1cf33a92bfbdd703c6cd84de890b1f60aef49e9e094f60d1ed356b"
IXGBEVF_FILENAME="ixgbevf-${IXGBEVF_VERSION}.tar.gz"
IXGBEVF_URL="https://downloadmirror.intel.com/${IXGBEVF_DOWNLOAD}/eng/ixgbevf-${IXGBEVF_VERSION}.tar.gz"
curl --fail -s -L $IXGBEVF_URL > "${IXGBEVF_FILENAME}"
if ! (echo "$IXGBEVF_SHA ${IXGBEVF_FILENAME}" | sha512sum -c); then
    echo "${IXGBEVF_FILENAME}: bad shasum"
    exit 1
fi
tar xzf "${IXGBEVF_FILENAME}" && rm "${IXGBEVF_FILENAME}"
configure_dkms ixgbevf ${IXGBEVF_VERSION} ixgbevf src/

# download and configure ena
ENA_VERSION=1.5.3
ENA_SHA="6a0dcd42c28e19dee6759c7aec34a56b72e4187c9652731c0e2b371b92e79a14"
ENA_FILENAME="ena_linux_${ENA_VERSION}.tar.gz"
curl --fail -L "https://github.com/amzn/amzn-drivers/archive/${ENA_FILENAME}" > "${ENA_FILENAME}"
if ! (echo "$ENA_SHA ${ENA_FILENAME}" | sha256sum -c); then
    echo "${ENA_FILENAME}: bad shasum"
    exit 1
fi
tar xzf "${ENA_FILENAME}" && rm "${ENA_FILENAME}"
mv "amzn-drivers-ena_linux_${ENA_VERSION}" "amzn-drivers-${ENA_VERSION}"
configure_dkms amzn-drivers "${ENA_VERSION}" ena kernel/linux/ena
popd

# install 3.16. LTS kernel and make sure it updates to the last version
# also this step should build ixgbevf and ena kernel modules and put them into initramfs
apt-get install -y linux-image-virtual-lts-xenial

apt-mark hold openssh-server
apt-get install -y --only-upgrade libc6 libssl1.0.0
#apt-get dist-upgrade -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y # -q  >>/tmp/build/upgrade.log
#aptitude unhold openssh-server
