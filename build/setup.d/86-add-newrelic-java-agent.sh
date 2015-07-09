#!/bin/bash

newrelic_archive=/data/newrelic.zip
no_newrelic=/data/no_newrelic
newrelic_yaml=/data/newrelic/newrelic.yml

#check if there is a no_newrelic file and exit 
if [ -f $no_newrelic ];
then
	echo "INFO: Newrelic Java Agent disabled.";
	exit; 	
fi

#unzip newrelic agent
if [ -f $newrelic_archive ]
then
	#unzip the archive
	cd /data/
	unzip $newrelic_archive	
else
	echo "ERROR: No NewRelic Java Agent was found!"
	exit; 
fi

############################
# CHANGE DEFAULT YAML FILE #
############################

echo "INFO: change default newrelic.yaml"

#change newrelicToken to default
sed -i "1,$ s/license_key:.*$/license_key:\ LICENSEKEY/" $newrelic_yaml

#set high security
sed -i "1,$ s/high_security:.*$/high_security:\ true/" $newrelic_yaml

#change my application
sed -i "1,$ s/app_name:.*$/app_name:\ APPNAME/" $newrelic_yaml

#TODO maybe change more default settings 


