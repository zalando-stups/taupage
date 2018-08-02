#!/bin/bash
touch /etc/cron.d/log-agent-mem
echo "*/1 * * * * root /opt/taupage/bin/log_agent_mem.sh" > /etc/cron.d/log-agent-mem
chmod 644 /etc/cron.d/log-agent-mem