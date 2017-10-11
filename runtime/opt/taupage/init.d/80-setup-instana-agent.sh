#!/bin/bash

# read global taupage config
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")
#INSTANA_AGENT_KEY=${config_instana_agent_key}
#INSTANA_ZONE=${config_instana_zone}
#INSTANA_TAGS=${config_instana_tags}
#AGENTMODE=${config_instana_agent_mode}

#TODO:Hardcoding instana parameters for Instana POC
INSTANA_AGENT_KEY="mD52HcuI5kdQFdsixwmLbW"
INSTANA_ZONE="stups-test"
INSTANA_TAGS="cluster_alias=cassandra_zmon_stups-test"
AGENTMODE="APM"

#Set instana environment variables#
#export INSTANA_AGENT_HOST=$config_instana_agent_host
#export INSTANA_AGENT_PORT=$config_instana_agent_port
# Set INSTANA_AGENT_KEY as ENV variable. If KMS encrypted, decrypt KMS and save to INSTANA_AGENT_KEY variable
if [ "$INSTANA_AGENT_KEY" ] ; then
  if [[ $INSTANA_AGENT_KEY == "aws:kms:"* ]]; then
  	ACCOUNTKEY=${INSTANA_AGENT_KEY##aws:kms:}
  	ACCOUNTKEY=`python3 /opt/taupage/bin/decrypt-kms.py $ACCOUNTKEY`
  	#overwrite INSTANA_AGENT_KEY with decrypted value
  	INSTANA_AGENT_KEY=$ACCOUNTKEY
  fi
  export INSTANA_AGENT_KEY=$INSTANA_AGENT_KEY
else
  echo "INFO: Instana access key is missing. Skipping Instana setup."
  exit 0
fi

#Set instana zone for application -- e.g. AWS account alias
if [ "$INSTANA_ZONE" ] ; then
  export INSTANA_ZONE=$INSTANA_ZONE
else
  echo "INFO: Instana zone configuration is missing. Skipping Instana setup."
  exit 0
fi

#Set instana tags -- If not specified use the stack name from senza
if [ "$INSTANA_TAGS" ]; then
  #TODO:Hardcoding instana parameters for Instana POC
  #export INSTANA_TAGS="${config_instana_tags},stack_name=${config_notify_cfn_stack},application_id=${config_application_id},aplication_version=${config_application_version}"
  export INSTANA_TAGS="$INSTANA_TAGS,stack_name=${config_notify_cfn_stack},application_id=${config_application_id},aplication_version=${config_application_version}"
else
  export INSTANA_TAGS="stack_name=${config_notify_cfn_stack},application_id=${config_application_id},aplication_version=${config_application_version}"
fi

# GET the INFRA/APM mode from environment variable
if [ "$AGENTMODE" ]; then
    shopt -s nocasematch
  if [[ $AGENTMODE =~ "APM" ]]; then
    AGENTMODE="APM"
  elif [[ $AGENTMODE =~ "OFF" ]]; then
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
agentConfig=/opt/instana/agent/etc/instana/com.instana.agent.main.config.Agent.cfg
echo "mode = $AGENTMODE" >> $agentConfig
