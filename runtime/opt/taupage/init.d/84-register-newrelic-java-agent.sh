#!/bin/bash
# read /etc/taupage.yaml
# get NewRelic Key and store it in the .yml file for the newrelic java agent

#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

#set more readable variables
ACCOUNTKEY=$config_newrelic_account_key
APPID=$config_application_id
newrelic_yaml=/opt/proprietary/newrelic/newrelic.yml
newrelic_dir=/opt/proprietary/newrelic/
APPVERSION=$config_application_version
AWS_ACCOUNT_ID=$(curl  --silent http://169.254.169.254/latest/meta-data/iam/info | jq -r '.InstanceProfileArn' | cut -d ':' -f5)
NR_HOSTNAME="aws-${AWS_ACCOUNT_ID}-$(hostname)"
EC2_AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"


#if NewRelic account exists in the yaml file. Register the NewRelic Daemon to this Account

    #check if java agent is installed
    if [ -f $newrelic_yaml ];
    then

       echo -n "Configuring newrelic-java-agent ... ";
                #set ApplicationName
                sed -i "1,$ s/APPNAME/\ $APPID/" $newrelic_yaml
                #add labels
                sed -i "/#label_name:/a application_id:$APPID;application_version:$APPVERSION;provider:aws;aws-region:$EC2_REGION;aws-az:$EC2_AZ;host:$NR_HOSTNAME;" $newrelic_yaml
                # create logs dir log file and set permissions
                mkdir -p $newrelic_dir/logs
                touch $newrelic_dir/logs/newrelic_agent.log
                chown -R application $newrelic_dir/logs
    else
       echo -n "ERROR: Newrelic JavaAgent is not installed";
       exit;
    fi
