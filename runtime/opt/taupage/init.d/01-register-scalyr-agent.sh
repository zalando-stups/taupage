#!/bin/bash
# read /meta/taupage.yaml
# get scalyr Key and register the agent
#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")
#set more readable variables
ACCOUNTKEY=$config_scalyr_account_key
APPID=$config_application_id
APPVERSION=$config_application_version
SCALYR_REGION=$config_scalyr_region
SOURCE=$config_source
STACK=$config_notify_cfn_stack
IMAGE=$(echo "$SOURCE" | awk -F \: '{ print $1 }')
LOGPARSER=${config_scalyr_application_log_parser:-slf4j}
CUSTOMLOG=$config_mount_custom_log
CUSTOMPARSER=${config_scalyr_custom_log_parser:-slf4j}
AWS_ACCOUNT=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq --raw-output .accountId)
AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq --raw-output .region)

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
    echo -n "Configuring scalyr daemon ... ";
    /usr/sbin/scalyr-agent-2-config --set-key "$ACCOUNTKEY"
    if [ $? -eq 0 ];
    then
        echo -n "DONE"
    else
        echo -n "ERROR: Register to Scalyr account failed";
        exit;
    fi
else
    echo "INFO: scalyr not configured; skipping daemon setup.";
    exit;
fi
#default path to scalyr config
scalyr_config=/etc/scalyr-agent-2/agent.json
#set serverhost to application_id
echo -n "set app name and version ...";
sed -i "/\/\/ serverHost: \"REPLACE THIS\"/s@.*@  serverHost:\ \"$APPID\", application_id: \"$APPID\", application_version: \"$APPVERSION\", stack: \"$STACK\", source: \"$SOURCE\", image:\"$IMAGE\", aws_account:\"$AWS_ACCOUNT\", aws_region:\"$AWS_REGION\"@" $scalyr_config
if [ $? -eq 0 ];
then
    echo -n "DONE";
else
    echo -n "ERROR";
    exit
fi
#disable system metric
echo "";
echo -n "disable system metrics ... ";
sed -i "/api_key\:/a\ \ implicit_metric_monitor: false," $scalyr_config
sed -i "/api_key\:/a\ \ implicit_agent_process_metrics_monitor: false, " $scalyr_config
if [ $? -eq 0 ];
then
    echo -n "DONE";
else
    echo -n "ERROR";
    exit
fi
#follow syslog
echo "";
echo -n "insert syslog to follow ... ";
sed -i "/logs\:\ \[/a { path: \"/var/log/syslog\", \"copy_from_start\": true, attributes: {parser: \"$SYSLOGPARSER\"} } " $scalyr_config

if [ $? -eq 0 ];
then
    echo -n "DONE";
else
    echo -n "ERROR";
    exit
fi
#follow auth.log
echo "";
echo -n "insert authlog to follow ... ";
sed -i "/logs\:\ \[/a { path: \"/var/log/auth.log\", \"copy_from_start\": true, attributes: {parser: \"$SYSLOGPARSER\"} } " $scalyr_config
if [ $? -eq 0 ];
then
    echo -n "DONE";
    echo "";
else
    echo -n "ERROR";
    exit
fi
#follow application.log
echo "";
echo -n "insert application to follow ... ";
sed -i "/logs\:\ \[/a { path: \"/var/log/application.log\", \"copy_from_start\": true, attributes: {parser: \"$LOGPARSER\"} } " $scalyr_config
if [ $? -eq 0 ];
then
    echo -n "DONE";
    echo "";
else
    echo -n "ERROR";
    exit
fi
#follow custom logs if it's enabled in senza.yaml
if [ -n "$CUSTOMLOG" ];
then
  echo "";
  echo -n "insert custom log directory to follow ... ";
  sed -i "/logs\:\ \[/a { path: \"/var/log-custom/*.log\", \"copy_from_start\": true, attributes: {parser: \"$CUSTOMPARSER\"} } " $scalyr_config
  if [ $? -eq 0 ];
  then
      echo -n "DONE";
      echo "";
  else
      echo -n "ERROR";
      exit
  fi
fi
#add max_log_offset_size
echo "";
echo -n "adding max_log_offset_size... ";
sed -i '/api_key/a \  \max_log_offset_size: 30000000,' $scalyr_config
if [ $? -eq 0 ];
then
    echo -n "DONE";
    echo "";
else
    echo -n "ERROR";
    exit
fi
#add max_log_offset_size
echo "";
echo -n "setting debug_init to true... ";
sed -i '/api_key/a \  \debug_init: true,' $scalyr_config
if [ $? -eq 0 ];
then
    echo -n "DONE";
    echo "";
else
    echo -n "ERROR";
    exit
fi
#add compressionType
echo "";
echo -n "setting compressionType to bz2... ";
sed -i '/api_key/a \  compressionType: "bz2",' $scalyr_config
if [ $? -eq 0 ];
then
    echo -n "DONE";
    echo "";
else
    echo -n "ERROR";
    exit
fi
# Allow custom Scalyr region
if [[ "$SCALYR_REGION" == "eu" ]] || [[ "$SCALYR_REGION" == "EU" ]];
then
    echo -n "Configuring Scalyr region to eu.scalyr.com ... ";
    sed -i '/api_key/a \  \scalyr_server: "https://upload.eu.scalyr.com",' $scalyr_config
    if [ $? -eq 0 ];
    then
        echo -n "DONE"
    else
        echo -n "ERROR: Setting custom Scalyr region failed";
        exit;
    fi
else
    echo "INFO: Scalyr region config not set; skipping region setup.";
    exit;
fi
echo -n "restarting scalyr daemon ... ";
/usr/sbin/scalyr-agent-2 stop # just in case
/usr/sbin/scalyr-agent-2 start
if [ $? -eq 0 ];
then
    echo -n "DONE"
else
    echo -n "ERROR: Failed to start scalyr daemon!";
    exit;
fi
