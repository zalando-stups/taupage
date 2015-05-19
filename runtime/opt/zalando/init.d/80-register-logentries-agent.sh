#!/bin/sh
# read /etc/taupage.yaml
# get logentries Key and register logentries daemon

#read taupage.yaml file
eval $(/opt/zalando/bin/parse-yaml.py /etc/taupage.yaml "config")

#set more readable variables
ACCOUNTKEY=$config_logentries_account_key
APPID=$config_application_id
APPVERSION=$config_application_version

#check if appname and appversion is provided from the yaml
if [ -z "$APPID" ] && [ -z "$APPVERSION" ];
then
    echo "ERROR: no application_id and application_version are in the yaml files";
    exit
fi

#if logentries account exists in the yaml file. Register the logentries Daemon to this Account
if [ -n "$ACCOUNTKEY" ];
then

    echo -n "register logentries Daemon ... ";
    #register logentries account
    le register --force --account-key=$ACCOUNTKEY
    if [ "$?" = "0" ];
    then
        echo -n "DONE"
    else
        echo -n "ERROR: Register to Logentries account failed";
        exit
    fi

    #add default EC2 followed logfiles and TokenID to le config
    le follow /var/log/syslog
    le follow /var/log/auth.log
    le follow /var/log/audit.log
    le follow /var/log/application.log

echo "
[syslog]
path = /var/log/syslog
destination = $APPID-$APPVERSION/syslog
" >> /etc/le/config

echo "
[auth.log]
path = /var/log/auth.log
destination = $APPID-$APPVERSION/auth.log
" >> /etc/le/config

echo "
[audit-logs]
path = /var/log/audit.log
destination = $APPID-$APPVERSION/audit.log
" >> /etc/le/config

echo "
[$APPID-$APPVERSION]
path = /var/log/application.log
destination = $APPID-$APPVERSION/application.log
" >> /etc/le/config

    #restart daemon
    service logentries restart
else
    echo "ERROR: no logentries AccountKey was specify in the .yaml file";
    exit
fi
