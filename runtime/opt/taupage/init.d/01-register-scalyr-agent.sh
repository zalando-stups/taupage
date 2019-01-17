#!/bin/bash
# read /meta/taupage.yaml
# get scalyr Key and register the agent
#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")
#set more readable variables
APPID=$config_application_id
APPVERSION=$config_application_version
SOURCE=$config_source
STACK=$config_notify_cfn_stack
IMAGE=$(echo "$SOURCE" | awk -F \: '{ print $1 }')
AWS_ACCOUNT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq --raw-output .accountId)
AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq --raw-output .region)
AWS_EC2_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AWS_EC2_HOSTNAME=$(curl -s http://169.254.169.254/latest/meta-data/hostname)
CUSTOMLOG=$config_mount_custom_log
#set Scalyr Variables
if [ $(set -o posix;set|grep -c config_logging_) -eq 0 ];
then
  ACCOUNTKEY=$config_scalyr_account_key
  SCALYR_REGION=$config_scalyr_region
  LOGPARSER=${config_scalyr_application_log_parser:-slf4j}
  CUSTOMPARSER=${config_scalyr_custom_log_parser:-slf4j}
else
  FLUENTD_ENABLED=$config_logging_fluentd_enabled
  ACCOUNTKEY=$config_logging_scalyr_account_key
  SCALYR_REGION=$config_logging_scalyr_region
  SCALYR_AGENT_ENABLED=$config_logging_scalyr_agent_enabled
  LOGPARSER=${config_logging_scalyr_application_log_parser:-slf4j}
  CUSTOMPARSER=${config_logging_scalyr_custom_log_parser:-slf4j}
fi

if [ "$FLUENTD_ENABLED" = "True" ];
then
   USE_SCALYR_AGENT_ALL=${config_logging_use_scalyr_agent_all:-False}
else
   USE_SCALYR_AGENT_ALL=${config_logging_use_scalyr_agent_all:-True}
fi

USE_SCALYR_AGENT_APPLOG=${config_logging_use_scalyr_agent_applog:-${USE_SCALYR_AGENT_ALL}}
USE_SCALYR_AGENT_SYSLOG=${config_logging_use_scalyr_agent_syslog:-${USE_SCALYR_AGENT_ALL}}
USE_SCALYR_AGENT_AUTHLOG=${config_logging_use_scalyr_agent_authlog:-${USE_SCALYR_AGENT_ALL}}
USE_SCALYR_AGENT_CUSTOMLOG=${config_logging_use_scalyr_agent_customlog:-${USE_SCALYR_AGENT_ALL}}

STANDARD_SAMPLING="[{ match_expression: \".\", sampling_rate: 1 }]"

SCALYR_AGENT_APPLOG_SAMPLING=${config_logging_scalyr_agent_applog_sampling:-${STANDARD_SAMPLING}}
SCALYR_AGENT_SYSLOG_SAMPLING=${config_logging_scalyr_agent_syslog_sampling:-${STANDARD_SAMPLING}}
SCALYR_AGENT_AUTHLOG_SAMPLING=${config_logging_scalyr_agent_authlog_sampling:-${STANDARD_SAMPLING}}
SCALYR_AGENT_CUSTOMLOG_SAMPLING=${config_logging_scalyr_agent_customlog_sampling:-${STANDARD_SAMPLING}}

# Skip Scalyr Agent setup if Scalyr Agent was disabled.
if [ "$SCALYR_AGENT_ENABLED" = "False" ];
then
  echo "Scalyr Agent disabled: Skipping Scalyr Agent setup"
  exit
fi

# Skip Scalyr Agent setup if Fluentd was enabled && Scalyr agent was not enabled
if [ "$FLUENTD_ENABLED" = "True" ];
then
  if [ -z "$SCALYR_AGENT_ENABLED" ];
  then
    echo "Fluentd enabled and Scalyr Agent not enabled: Skipping Scalyr Agent setup"
    exit
  fi
fi

if [ "$USE_SCALYR_AGENT_SYSLOG" = "False" ] && \
   [ "$USE_SCALYR_AGENT_APPLOG" = "False" ] && \
   [ "$USE_SCALYR_AGENT_AUTHLOG" = "False" ] && \
   [ "$USE_SCALYR_AGENT_CUSTOMLOG" = "False" ]
then
  echo "No file for Scalyr to follow: Skipping Scalyr Agent setup"
  exit
fi

SYSLOGPARSER="systemLog"

if [ -n "$config_rsyslog_aws_metadata" ];
then
    SYSLOGPARSER="systemLogMetadata"
fi

#check if appname and appversion is provided from the yaml
if [ -z "$APPID" ] && [ -z "$APPVERSION" ];
then
    echo "ERROR: no application_id and application_version are in the yaml files";
    exit;
fi

# If KMS encrypted, decrypt KMS and save to ACCOUNTKEY variable
if [[ $ACCOUNTKEY == "aws:kms:"* ]]; then
  ACCOUNTKEY=${ACCOUNTKEY##aws:kms:}
  ACCOUNTKEY=`python3 /opt/taupage/bin/decrypt-kms.py $ACCOUNTKEY`
fi

#If Scalyr account exists in the yaml file. Register the Scalyr Daemon to this Account
if [ -n "$ACCOUNTKEY" ];
then
    echo -n "Configuring scalyr daemon... ";
    /usr/sbin/scalyr-agent-2-config --set-key "$ACCOUNTKEY"
    if [ $? -eq 0 ];
    then
        echo "DONE"
    else
        echo "ERROR: Register to Scalyr account failed";
        exit;
    fi
else
    echo "INFO: scalyr not configured; skipping daemon setup.";
    exit;
fi

#default path to scalyr config
scalyr_config=/etc/scalyr-agent-2/agent.json

#set serverhost to application_id
echo -n "set app name and version... ";
sed -i "/\/\/ serverHost: \"REPLACE THIS\"/s@.*@  serverHost:\ \"$APPID\", application_id: \"$APPID\", application_version: \"$APPVERSION\", stack: \"$STACK\", source: \"$SOURCE\", image:\"$IMAGE\", aws_account:\"$AWS_ACCOUNT\", aws_region:\"$AWS_REGION\", aws_ec2_instance_id:\"$AWS_EC2_INSTANCE_ID\", aws_ec2_hostname:\"$AWS_EC2_HOSTNAME\"@" $scalyr_config
if [ $? -eq 0 ];
then
    echo "DONE"
else
    echo "ERROR"
    exit
fi

#disable system metric
echo -n "disable system metrics... ";
sed -i "/api_key\:/a\ \ implicit_metric_monitor: false," $scalyr_config
sed -i "/api_key\:/a\ \ implicit_agent_process_metrics_monitor: false, " $scalyr_config
if [ $? -eq 0 ];
then
    echo "DONE"
else
    echo "ERROR"
    exit
fi

#follow syslog
if [ "$USE_SCALYR_AGENT_SYSLOG" = "True" ]
then
  echo -n "insert syslog to follow... ";
  sed -i "/logs\:\ \[/a { path: \"/var/log/syslog\", \"copy_from_start\": true, attributes: {parser: \"$SYSLOGPARSER\"}, \
  sampling_rules: $SCALYR_AGENT_SYSLOG_SAMPLING } " $scalyr_config

  if [ $? -eq 0 ];
  then
      echo "DONE"
  else
      echo "ERROR"
      exit
  fi
fi

#follow auth.log
if [ "$USE_SCALYR_AGENT_AUTHLOG" = "True" ]
then
  echo -n "insert authlog to follow... ";
  sed -i "/logs\:\ \[/a { path: \"/var/log/auth.log\", \"copy_from_start\": true, attributes: {parser: \"$SYSLOGPARSER\"}, \
  sampling_rules: $SCALYR_AGENT_AUTHLOG_SAMPLING } " $scalyr_config
  if [ $? -eq 0 ];
  then
      echo "DONE"
  else
      echo "ERROR"
      exit
  fi
fi

#follow application.log
if [ "$USE_SCALYR_AGENT_APPLOG" = "True" ]
then
  echo -n "insert application to follow... ";
  sed -i "/logs\:\ \[/a { path: \"/var/log/application.log\", \"copy_from_start\": true, attributes: {parser: \"$LOGPARSER\"}, \
  sampling_rules: $SCALYR_AGENT_APPLOG_SAMPLING } " $scalyr_config
  if [ $? -eq 0 ];
  then
      echo "DONE"
  else
      echo -n "ERROR"
      exit
  fi
fi

#follow custom logs if it's enabled in senza.yaml
if [ -n "$CUSTOMLOG" ] && [ "$USE_SCALYR_AGENT_CUSTOMLOG" = "True" ];
then
  echo "insert custom log directory to follow... ";
  sed -i "/logs\:\ \[/a { path: \"/var/log-custom/*.log\", \"copy_from_start\": true, attributes: {parser: \"$CUSTOMPARSER\"}, \
  sampling_rules: $SCALYR_AGENT_CUSTOMLOG_SAMPLING } " $scalyr_config
  if [ $? -eq 0 ];
  then
      echo "DONE"
  else
      echo "ERROR"
      exit
  fi
fi

#add max_log_offset_size
echo -n "adding max_log_offset_size... ";
sed -i '/api_key/a \  \max_log_offset_size: 30000000,' $scalyr_config
if [ $? -eq 0 ];
then
    echo "DONE"
else
    echo "ERROR"
    exit
fi

#add max_log_offset_size
echo -n "setting debug_init to true... ";
sed -i '/api_key/a \  \debug_init: true,' $scalyr_config
if [ $? -eq 0 ];
then
    echo "DONE"
else
    echo "ERROR"
    exit
fi

#add compressionType
echo -n "setting compressionType to bz2... ";
sed -i '/api_key/a \  compressionType: "bz2",' $scalyr_config
if [ $? -eq 0 ];
then
    echo "DONE"
else
    echo "ERROR"
    exit
fi

# setting Scalyr region to europe
echo -n "Configuring Scalyr region to eu.scalyr.com ... ";
sed -i '/api_key/a \  \scalyr_server: "https://upload.eu.scalyr.com",' $scalyr_config
if [ $? -eq 0 ];
then
    echo "DONE"
else
    echo "ERROR: Setting custom Scalyr region failed";
    exit;
fi

echo -n "restarting scalyr daemon ... ";
/usr/sbin/scalyr-agent-2 stop # just in case
/usr/sbin/scalyr-agent-2 start
if [ $? -eq 0 ];
then
    echo "DONE"
else
    echo "ERROR: Failed to start scalyr daemon!";
    exit;
fi
