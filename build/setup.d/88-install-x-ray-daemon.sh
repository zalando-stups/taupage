#!/bin/bash

mkdir /tmp/x-ray-setup
cd /tmp/x-ray-setup

# download and install latest version of the cloudwatch logs agent
wget https://s3.dualstack.eu-central-1.amazonaws.com/aws-xray-assets.eu-central-1/xray-daemon/aws-xray-daemon-2.x.deb
dpkg -i aws-xray-daemon-2.x.deb

# cleanup
rm -rf /tmp/x-ray-setup
