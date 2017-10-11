#!/bin/bash

#check if INSTANA_AGENT_KEY exists, if not cancel the installation process.
if [ -z "${INSTANA_AGENT_KEY}" ] || [ -z "${INSTANA_AGENT_HOST}" ] || [ -z "${INSTANA_AGENT_PORT}" ]; then
  echo "ERROR: Instana host/port/key missing. Check your secrets configuration."
  exit 1
fi

#add instana repo to debian sources
echo "deb [arch=amd64] https://_:${INSTANA_AGENT_KEY}@packages.instana.io/agent generic main" > /etc/apt/sources.list.d/instana.list

#add the Instana GPG-Key to environment
wget -O - https://packages.instana.io/Instana.gpg | apt-key add -

#update repos
apt-get update

#install Instana static Agent
apt-get install -y -q instana-agent-static

# Set the AUTO-UPDATE mode in file - instana-agent/etc/instana/com.instana.agent.main.config.UpdateManager.cfg
instanaUpdateConfig="/opt/instana/agent/etc/instana/com.instana.agent.main.config.UpdateManager.cfg";
if [ -z "${INSTANA_AGENT_AUTO_UPDATE}" ]; then
  echo "WARN: Instana agent auto update mode not specified. Falling back to OFF"
  sed -i -e "1, $ s/mode.*/mode = OFF/" $instanaUpdateConfig
else
  echo "INFO: Setting Instana agent auto update mode to ${INSTANA_AGENT_AUTO_UPDATE}."
  sed -i -e "1, $ s/mode.*/mode = ${INSTANA_AGENT_AUTO_UPDATE}/" $instanaUpdateConfig
fi

# Set the host, port and protocol in file - /opt/instana/agent/etc/instana/com.instana.agent.main.sender.Backend.cfg
backendConfig=/opt/instana/agent/etc/instana/com.instana.agent.main.sender.Backend.cfg
echo "host=${INSTANA_AGENT_HOST}" >> $backendConfig
echo "port=${INSTANA_AGENT_PORT}" >> $backendConfig
echo "protocol=HTTP/2" >> $backendConfig
echo "key=${INSTANA_AGENT_KEY}" >> $backendConfig
