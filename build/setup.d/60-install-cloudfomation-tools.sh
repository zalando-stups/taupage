#!/bin/bash

# download newest version
wget https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz >>cfn.log

# install
mkdir -p /opt/aws-cfn
tar xfz aws-cfn-bootstrap-latest.tar.gz -C /opt/aws-cfn >>cfn.log
easy_install-2.7 /opt/aws-cfn >>cfn.log
