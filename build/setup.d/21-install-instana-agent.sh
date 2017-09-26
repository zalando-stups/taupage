#!/bin/bash

#check if INSTANA_AGENT_KEY exists, if not cancel the installation process.
if [-z "${INSTANA_AGENT_KEY}"]; then
  echo "ERROR: Instana access key is missing. Check your secrets configuration."
  exit 1
fi

#add instana repo to debian sources
echo "deb [arch=amd64] https://_:${INSTANA_AGENT_KEY}@packages.instana.io/agent generic main" > /etc/apt/sources.list.d/instana.list

#add the Instana GPG-Key to environment
wget -O - https://packages.instana.io/Instana.gpg | apt-key add -

#update repos
apt-get update

#install Instana static Agent
apt-get install instana-agent-static

# Set the AUTO-UPDATE mode in file - instana-agent/etc/instana/com.instana.agent.main.config.UpdateManager.cfg
instanaUpdateConfig = "instana-agent/etc/instana/com.instana.agent.main.config.UpdateManager.cfg";
if [-z "${INSTANA_AGENT_AUTO_UPDATE}"]; then
  echo "WARN: Instana agent auto update mode not specified. Falling back to OFF"
  sed -i "1, $ s/mode.*/mode = OFF/" $instanaUpdateConfig
else
  echo "INFO: Setting Instana agent auto update mode to ${INSTANA_AGENT_AUTO_UPDATE}."
  sed -i "1, $ s/mode.*/mode = ${INSTANA_AGENT_AUTO_UPDATE}/" $instanaUpdateConfig
fi
