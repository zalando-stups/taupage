#!/bin/bash
#make script fail on error
set -e 

# Ensure that /etc/init.d/td-agent is removed
rm /etc/init.d/td-agent

# Ensure that directories are writable
mkdir -p -m0755 /var/run/td-agent

# Get SSL certificate chain for Scalyr plugin
wget https://curl.haxx.se/ca/cacert.pem -O /etc/ssl/certs/scalyr-ca-bundle.crt

# Install Fluentd plugins
td-agent-gem install fluent-plugin-scalyr:0.8.4 \
					 fluent-plugin-prometheus:1.1.0 \
					 fluent-plugin-s3:1.1.6 \
					 fluent-plugin-remote_syslog:1.0.0