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
td-agent-gem install fluent-plugin-scalyr \
					 fluent-plugin-prometheus fluent-plugin-s3 \
					 fluent-plugin-remote_syslog