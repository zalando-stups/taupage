#!/bin/sh
# read /meta/taupage.yaml
# get scalyr Key and register the agent

#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

#set more readable variables
ACCOUNTKEY=$config_scalyr_account_key
APPID=$config_application_id
APPVERSION=$config_application_version
SOURCE=$config_source
STACK=$config_notify_cfn_stack
IMAGE=$(echo "$SOURCE" | awk -F \: '{ print $1 }')
LOGPARSER=${config_scalyr_application_log_parser:-slf4j}

#check if appname and appversion is provided from the yaml
if [ -z "$APPID" ] && [ -z "$APPVERSION" ];
then
    echo "ERROR: no application_id and application_version are in the yaml files";
    exit;
fi

# If KMS decrypted, decrypt KMS and save to ACCOUNTKEY variable
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
sed -i "1,$ s/\/\/\ serverHost:\ \"REPLACE THIS\"/serverHost:\ \"$APPID\"/g" $scalyr_config

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
sed -i "/api_key\:/a\ \ implicit_metric_monitor: false, implicit_agent_process_metrics_monitor: false, " $scalyr_config
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
sed -i "/logs\:\ \[/a { path: \"/var/log/syslog\", attributes: {parser: \"systemLog\", application_id: \"$APPID\", application_version: \"$APPVERSION\", stack: \"$STACKNAME\", source: \"$SOURCE\", image:\"$IMAGE\"} } " $scalyr_config
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
sed -i "/logs\:\ \[/a { path: \"/var/log/auth.log\", attributes: {parser: \"systemLog\"} } " $scalyr_config
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
sed -i "/logs\:\ \[/a { path: \"/var/log/application.log\", attributes: {parser: \"$LOGPARSER\", application_id: \"$APPID\", application_version: \"$APPVERSION\", stack: \"$STACKNAME\", source: \"$SOURCE\", image:\"$IMAGE\"} } " $scalyr_config
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
