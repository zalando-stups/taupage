#!/bin/bash

pkgs="
awscli
boto
boto3
botocore
requests
stups-berry
stups-tokens
stups-zign
stups-pierone
"

echo "Installing Python packages..."

pip3 install -U --log-file=install_python_errors.log --log=install_python.log --exists-action i $pkgs
