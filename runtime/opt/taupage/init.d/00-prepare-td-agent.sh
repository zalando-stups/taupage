#!/bin/bash

# Ensure that directories are writable
chmod -R 1777 /tmp/
mkdir -p -m0755 /var/run/td-agent

# Ensure that td-agent can read logs from /var/log/application.log
chmod 644 /var/log/application.log

service td-agent start