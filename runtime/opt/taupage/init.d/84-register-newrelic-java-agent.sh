#!/bin/sh
# read /etc/taupage.yaml
# get NewRelic Key and store it in the .yml file for the newrelic java agent

#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /etc/taupage.yaml "config")

#set more readable variables
ACCOUNTKEY=$config_newrelic_account_key
APPID=$config_application_id
newrelic_yaml=/opt/proprietary/newrelic/newrelic.yml
newrelic_dir=/opt/proprietary/newrelic/
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
                sed -i "1,$ s/APPNAME/\ $APPID/" $newrelic_yaml
                #add labels
                sed -i "/labels=label_type:/a labels=application_id:$APPID;application_version:$APPVERSION" $newrelic_yaml
                # create logs dir log file and set permissions
                mkdir -p $newrelic_dir/logs
                touch $newrelic_dir/logs/newrelic_agent.log
                chown -R application $newrelic_dir/logs
    else
       echo -n "ERROR: Newrelic JavaAgent is not installed";
       exit;
    fi
else
    echo "INFO: NewRelic is not configured; skipping daemon setup.";
    exit;
fi
