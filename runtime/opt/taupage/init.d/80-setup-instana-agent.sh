#!/bin/bash
# read global taupage config
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")
INSTANA_AGENT_KEY=${config_instana_agent_key}
INSTANA_ZONE=${config_instana_zone}
INSTANA_TAGS=${config_instana_tags}
AGENTMODE=${config_instana_agent_mode}

#Set instana environment variables#
#export INSTANA_AGENT_HOST=$config_instana_agent_host
#export INSTANA_AGENT_PORT=$config_instana_agent_port
# Set INSTANA_AGENT_KEY as ENV variable. If KMS encrypted, decrypt KMS and save to INSTANA_AGENT_KEY variable
# if [ "$INSTANA_AGENT_KEY" ] ; then
#   if [[ $INSTANA_AGENT_KEY == "aws:kms:"* ]]; then
#   	ACCOUNTKEY=${INSTANA_AGENT_KEY##aws:kms:}
#   	ACCOUNTKEY=`python3 /opt/taupage/bin/decrypt-kms.py $ACCOUNTKEY`
#   	#overwrite INSTANA_AGENT_KEY with decrypted value
#   	INSTANA_AGENT_KEY=$ACCOUNTKEY
#   fi
#   export INSTANA_AGENT_KEY=$INSTANA_AGENT_KEY
#   echo "INSTANA_AGENT_KEY=$INSTANA_AGENT_KEY" >> /etc/environment
# else
#   echo "INFO: Instana access key is missing. Skipping Instana setup."
#   exit 0
# fi

#Set instana zone for application -- e.g. AWS account alias in configurationYaml=/opt/instana/agent/etc/instana/configuration.yaml
configurationYaml=/opt/instana/agent/etc/instana/configuration.yaml
if [ "$INSTANA_ZONE" ] ; then
  export INSTANA_ZONE=$INSTANA_ZONE
  echo "INSTANA_ZONE=$INSTANA_ZONE" >> /etc/environment
  sed -i -e "1, $ s/#com.instana.plugin.generic.hardware.*/com.instana.plugin.generic.hardware:/" $configurationYaml
  sed -i -e "1, $ s/#  enabled: true.*/  enabled: true/" $configurationYaml
  sed -i -e "1, $ s/#  availability-zone.*/  availability-zone: '$INSTANA_ZONE'/" $configurationYaml
else
  echo "INFO: Instana zone configuration is missing. Skipping Instana setup."
  exit 0
fi

#Set instana tags in /opt/instana/agent/etc/instana/configuration.yaml
if [ "$INSTANA_TAGS" ]; then
  export INSTANA_TAGS="$config_instana_tags,stack_name=$config_notify_cfn_stack,application_id=$config_application_id,aplication_version=$config_application_version"
  echo "INSTANA_TAGS=$config_instana_tags,stack_name=$config_notify_cfn_stack,application_id=$config_application_id,aplication_version=$config_application_version" >> /etc/environment

  tags="tags:"
  customTags=$config_instana_tags
  splitTags=$(echo $customTags | tr "," "\n")
  for tag in $splitTags
    do
    tags="$tags\\
     - '$tag'"
    done
  tags="$tags\\
     - 'stack_name=$config_notify_cfn_stack'\\
     - 'application_id=$config_application_id'\\
     - 'aplication_version=$config_application_version'"
else
  tags="tags:\\
     - 'stack_name=$config_notify_cfn_stack'\\
     - 'application_id=$config_application_id'\\
     - 'aplication_version=$config_application_version'"

  export INSTANA_TAGS="stack_name=$config_notify_cfn_stack,application_id=$config_application_id,aplication_version=$config_application_version"
  echo "INSTANA_TAGS=stack_name=$config_notify_cfn_stack,application_id=$config_application_id,aplication_version=$config_application_version" >> /etc/environment
fi
sed -i -e "1, $ s/#com.instana.plugin.host.*/com.instana.plugin.host:/" $configurationYaml
sed -i -e "1, $ s/#  tags:.*/  $tags/" $configurationYaml

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
