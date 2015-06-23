#!/bin/sh
# read /etc/taupage.yaml
# get NewRelic Key and register the agent

#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /etc/taupage.yaml "config")

#set more readable variables
ACCOUNTKEY=$config_newrelic_license_key

#if NewRelic account exists in the yaml file. Register the NewRelic Daemon to this Account
if [ -n "$ACCOUNTKEY" ];
then

    echo -n "Configuring newrelic-sysmond ... ";
		nrsysmond-config --set license_key="$ACCOUNTKEY"
    if [ $? -eq 0 ];
    then
        echo -n "DONE";
        echo "";
	echo -n "Starting newrelic-sysmond ... ";
	 service newrelic-sysmond stop # just in case
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

