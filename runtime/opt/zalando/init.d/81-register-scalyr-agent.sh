#!/bin/sh
# read /etc/taupage.yaml
# get scalyr Key and register the agent

#read taupage.yaml file
eval $(/opt/zalando/bin/parse-yaml.py /etc/taupage.yaml "config")

#set more readable variables
ACCOUNTKEY=$config_scalyr_account_key
APPID=$config_application_id
APPVERSION=$config_application_version
SOURCE=$config_source
STACK=$config_stack
IMAGE=$(echo "$SOURCE" | awk -F \: '{ print $1 }')

#check if appname and appversion is provided from the yaml
if [ -z "$APPID" ] && [ -z "$APPVERSION" ];
then
    echo "ERROR: no application_id and application_version are in the yaml files";
    exit;
fi

#if logentries account exists in the yaml file. Register the logentries Daemon to this Account
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

#set serverhost to appname and version
echo -n "set app name and version ...";
sed -i "1,$ s/\/\/\ serverHost:\ \"REPLACE THIS\"/serverHost:\ \"$APPID\"/g" $scalyr_config

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

#follow audit.log
echo "";
echo -n "insert audit to follow ... ";
sed -i "/logs\:\ \[/a { path: \"/var/log/audit.log\", attributes: {parser: \"systemLog\"} } " $scalyr_config
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
sed -i "/logs\:\ \[/a { path: \"/var/log/application.log\", attributes: {parser: \"slf4j\", application_id: \"$APPID\", application_version: \"$APPVERSION\", stack: \"$STACKNAME\", source: \"$SOURCE\", image:\"$IMAGE\"} } " $scalyr_config
if [ $? -eq 0 ];
then
    echo -n "DONE";
    echo "";
else
    echo -n "ERROR";
    exit
fi

echo -n "Starting scalyr daemon ... ";
/usr/sbin/scalyr-agent-2 start
if [ $? -eq 0 ];
then
    echo -n "DONE"
else
    echo -n "ERROR: Failed to start scalyr daemon!";
    exit;
fi

