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

# limit upstart respawn to 3 tries

CONF="/etc/init/td-agent.conf"

rm ${CONF}

echo "description     \"TD Agent\"" >> ${CONF}
echo "stop on shutdown" >> ${CONF}
echo "respawn limit 3 5" >> ${CONF}
echo "pre-start script" >> ${CONF}
echo "    mkdir -p -m0755 /var/run/td-agent" >> ${CONF}
echo "end script" >> ${CONF}
echo "exec /opt/td-agent/embedded/bin/ruby \
      -Eascii-8bit:ascii-8bit /usr/sbin/td-agent \
	  --log /var/log/td-agent/td-agent.log \
	  --daemon /var/run/td-agent/td-agent.pid \
	  --no-supervisor" >> ${CONF}