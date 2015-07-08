#!/bin/sh
# read /etc/taupage.yaml
# get NewRelic Key and store it in the .yml file for the newrelic java agent

#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /etc/taupage.yaml "config")

#set more readable variables
ACCOUNTKEY=$config_newrelic_account_key
APPID=$config_application_id
newrelic_yaml=/data/newrelic/newrelic.yml
APPVERSION=$config_application_version

#if NewRelic account exists in the yaml file. Register the NewRelic Daemon to this Account
if [ -n "$ACCOUNTKEY" ];
then

    #check if java agent is installed
    if [ -f $newrelic_yaml ];
    then 
    
       echo -n "Configuring newrelic-java-agent ... ";
                #insert newrelic Key 
  		sed -i "1,$ s/LICENSEKEY/\ $ACCOUNTKEY/" $newrelic_yaml
                #set ApplicationName
                sed -i "1,$ s/APPNAME/\ $APPID-$APPVERSION/" $newrelic_yaml
    else
       echo -n "ERROR: Newrelic JavaAgent is not installed";
       exit;
    fi
else
    echo "INFO: NewRelic is not configured; skipping daemon setup.";
    exit;
fi

