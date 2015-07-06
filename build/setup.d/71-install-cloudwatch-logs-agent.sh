#!/bin/bash

mkdir /tmp/cw-logs-setup
cd /tmp/cw-logs-setup

# put empty config file as placeholder for the real config file
touch cloudwatch_logs_empty.conf

# download and install latest version of the cloudwatch logs agent
wget https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
chmod +x ./awslogs-agent-setup.py

# the region parameter is not relevant here but required
./awslogs-agent-setup.py -n -r foo -c cloudwatch_logs_empty.conf

# disable autostart since the service is intended to start only if configured in /etc/taupage.yaml
update-rc.d -f awslogs remove

# cleanup
rm -rf /tmp/cw-logs-setup