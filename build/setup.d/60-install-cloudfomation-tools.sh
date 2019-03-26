#!/bin/bash

# download newest version
wget https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz >>cfn.log

# install
mkdir -p /opt/aws-cfn
tar xfz aws-cfn-bootstrap-latest.tar.gz -C /opt/aws-cfn >>cfn.log
pip2 install /opt/aws-cfn/aws-cfn-bootstrap-*
