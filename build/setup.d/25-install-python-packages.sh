#!/bin/bash

pkgs="
boto
boto3
botocore
requests
"

echo "Installing Python packages..."

pip3 install -U --log-file=install_python_errors.log --log=install_python.log --exists-action i $pkgs
