#!/bin/sh
# read /etc/taupage.yaml
# get NewRelic Key and register the agent

#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /etc/taupage.yaml "config")

#set more readable variables
ACCOUNTKEY=$config_newrelic_account_key
APPID=$config_application_id
APPVERSION=$config_application_version
newrelic_sysmoncfg=/etc/newrelic/nrsysmond.cfg

#if NewRelic account exists in the yaml file. Register the NewRelic Daemon to this Account
if [ -n "$ACCOUNTKEY" ];
then

    echo -n "Configuring newrelic-sysmond ... ";
		nrsysmond-config --set license_key="$ACCOUNTKEY"
    # add labels to newrelic.yaml 
    sed -i "/labels=label_type:/a labels=application_id:$APPID;application_version:$APPVERSION" $newrelic_sysmoncfg
    if [ $? -eq 0 ];
    then
        echo -n "DONE";
        echo "";
	echo -n "Starting newrelic-sysmond ... ";
	 service newrelic-sysmond stop # just in case, TODO: check if this is necessary 
	 service newrelic-sysmond start
	if [ $? -eq 0 ];
	then
	    echo -n "DONE"
	else
	    echo -n "ERROR: Failed to start newrelic-sysmond!";
            exit;
	fi
    else
        echo -n "ERROR: Registration with NewRelic has failed";
        exit;
    fi
else
    echo "INFO: NewRelic is not configured; skipping daemon setup.";
    exit;
fi

