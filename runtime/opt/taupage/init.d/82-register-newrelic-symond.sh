#!/bin/bash
# read /etc/taupage.yaml
# get NewRelic Key and register the agent

#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

#set more readable variables
APPID=$config_application_id
APPVERSION=$config_application_version
newrelic_sysmoncfg=/etc/newrelic/nrsysmond.cfg
newrelic_sysmoncfg_prop=/opt/proprietary/newrelic-sysmond/nrsysmond.cfg
AWS_ACCOUNT_ID=$(curl  --silent http://169.254.169.254/latest/meta-data/iam/info | jq -r '.InstanceProfileArn' | cut -d ':' -f5)
NR_HOSTNAME="aws-${AWS_ACCOUNT_ID}-$(hostname)"
EC2_AZ=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AZ\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

#copy the proprietary agent config to /etc/ the licensekey is already in the config
if [ -f $newrelic_sysmoncfg_prop ]
then
    #copy proprietary file to system
    cp $newrelic_sysmoncfg_prop $newrelic_sysmoncfg
    # add labels to nrsysmond.cfg
    sed -i "/labels=label_type:/a labels=application_id:$APPID;application_version:$APPVERSION;provider:aws;aws-region:$EC2_REGION;aws-az:$EC2_AZ" $newrelic_sysmoncfg
    #set hostname
    sed -i "/hostname=myhost/a hostname=$NR_HOSTNAME" $newrelic_sysmoncfg
        
	echo "";
	echo -n "Starting newrelic-sysmond ... ";
	 service newrelic-sysmond start
	if [ $? -eq 0 ];
	then
	    echo -n "DONE"
	else
	    echo -n "ERROR: Failed to start newrelic-sysmond!";
            exit;
	fi
else 

	echo -n "INFO: No NewRelic sysmond config found - skiping setup";
fi
