#!/bin/bash

# put empty config file as placeholder for the real config file
touch /tmp/cloudwatch_logs_empty.conf

# download and install latest version of the cloudwatch logs agent
wget https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
chmod +x ./awslogs-agent-setup.py

# the region parameter is not relevant here but required
./awslogs-agent-setup.py -n -r foo -c