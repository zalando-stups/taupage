#!/bin/bash
set -euo pipefail

VERSION="1.1.11"
DOWNLOAD_URL="https://github.com/aws/aws-ec2-instance-connect-config/archive/${VERSION}.tar.gz"
TARFILE="instance-connect.tar.gz"
SHA256SUM="38b373c640b0b1c81443b95e46fb49684e2bb3ef98455ad4967d9e0571cea695"
curl -L -o "${TARFILE}" "${DOWNLOAD_URL}"
echo "${SHA256SUM} ${TARFILE}" | sha256sum --check --status

TEMP_DIR=$(mktemp -d)
tar xzf "${TARFILE}" -C "${TEMP_DIR}"
rm -f ${TARFILE}

for file in "${TEMP_DIR}/aws-ec2-instance-connect-config-${VERSION}/src/bin/eic_"* ; do
    chmod +x "$file"
    mv "$file" /usr/local/bin
done

rm -rf "${TEMP_DIR}"
getent passwd ec2-instance-connect || adduser --system --disabled-login --shell /usr/sbin/nologin --no-create-home --home /nonexistent --quiet ec2-instance-connect
