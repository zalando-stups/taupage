#!/bin/bash

if [-z "${INSTANA_AGENT_KEY}"]; then
  echo "ERROR: Instana access key is missing. Check your secrets configuration."
  exit 1
fi

deb [arch=amd64] https://_:${INSTANA_AGENT_KEY}@packages.instana.io/agent generic main

apt-get install instana-agent-static

# Set the AUTO-UPDATE mode in file - instana-agent/etc/instana/com.instana.agent.main.config.UpdateManager.cfg
