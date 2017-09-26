#!/bin/bash

# read global taupage config
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

#Set instana environment variables#
#export INSTANA_AGENT_HOST=$config_instana_agent_host
#export INSTANA_AGENT_PORT=$config_instana_agent_port
# Set INSTANA_AGENT_KEY as ENV variable. If KMS encrypted, decrypt KMS and save to INSTANA_AGENT_KEY variable
if [! -z "${config_instana_agent_key}"] ; then
  INSTANA_AGENT_KEY=${config_instana_agent_key}
  if [[ $INSTANA_AGENT_KEY == "aws:kms:"* ]]; then
  	ACCOUNTKEY=${INSTANA_AGENT_KEY##aws:kms:}
  	ACCOUNTKEY=`python3 /opt/taupage/bin/decrypt-kms.py $ACCOUNTKEY`
  	#overwrite INSTANA_AGENT_KEY with decrypted value
  	INSTANA_AGENT_KEY=$ACCOUNTKEY
  fi
  export INSTANA_AGENT_KEY=$INSTANA_AGENT_KEY
else
  echo "INFO: Instana access key is missing. Skipping Instana setup."
  exit 1
fi

#Set instana zone for application -- e.g. AWS account alias
if [! -z "${config_instana_zone}"] ; then
  export INSTANA_ZONE=${config_instana_zone}
else
  echo "INFO: Instana zone configuration is missing. Skipping Instana setup."
  exit 1

#Set instana tags -- If not specified use the stack name from senza
if [! -z "$config_instana_tags"]; then
  export INSTANA_TAGS="$config_instana_tags,stack_name=$config_notify_cfn_stack,application_id=$config_application_id,aplication_version=$config_application_version"
else
  export INSTANA_TAGS="stack_name=$config_notify_cfn_stack,application_id=$config_application_id,aplication_version=$config_application_version"

# GET the INFRA/APM mode from environment variable
if [! -z "${config_instana_agent_mode}"]; then
    shopt -s nocasematch
  if [[${config_instana_agent_mode} =~ "APM"]]; then
    AGENTMODE="APM"
  elif [[${config_instana_agent_mode} =~ "OFF" ]]; then
    AGENTMODE="OFF"
  else
    echo "INFO: Setting instana agent mode to INFRASTRUCTURE."
    AGENTMODE="INFRASTRUCTURE"
  fi
else
  AGENTMODE="INFRASTRUCTURE"
  echo "WARN: Instana agent mode not specified in Senza. Falling back to Instana infrastructure monitoring."
fi
# Set the INFRA/APM mode in file -- instana-agent/etc/instana/com.instana.agent.main.config.Agent.cfg
agentConfig = /opt/instana/agent/etc/instana/com.instana.agent.main.config.Agent.cfg
echo "mode = $AGENTMODE" >> $agentConfig
