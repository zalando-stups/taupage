#!/bin/bash
# read /etc/taupage.yaml
# get NewRelic Key and register the agent

#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

#set more readable variables
ACCOUNTKEY=$config_newrelic_account_key
newrelic_config=/etc/newrelic-infra.yml

#if NewRelic account exists in the yaml file. Register the NewRelic Daemon to this Account
if [ -n "$ACCOUNTKEY" ];
then
    echo "license_key: $ACCOUNTKEY" > $newrelic_config
    echo -n "Starting newrelic-infra ... ";
    service newrelic-infra stop || true
    service newrelic-infra start
    if [ $? -eq 0 ];
    then
        echo -n "DONE"
    else
        echo -n "ERROR: Failed to start newrelic-infra!";
        exit;
    fi
else
    echo "INFO: NewRelic is not configured; skipping daemon setup.";
    exit;
fi
