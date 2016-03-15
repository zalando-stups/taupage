#!/bin/bash

set -x

# check if directory exists
if [ ! -d /opt/proprietary/appdynamics-machine ]; then
	echo "INFO: no AppDynamics agent found, skip configuration"
else

	# standard config files
	appdynamics_agents="
	/opt/proprietary/appdynamics-jvm
	/opt/proprietary/appdynamics-machine
	"

	appdynamics_config=
	for agent in $appdynamics_agents; do
		for conf in $(find $agent -name 'controller-info.xml'); do
			appdynamics_configs="$appdynamics_configs $conf"
		done
	done

	# setup all configs
	for conf in $appdynamics_configs; do
		if [ -z "$APPDYNAMICS_CONTROLLER_HOST" ] || [ -z "$APPDYNAMICS_ACCOUNT_KEY" ]; then
			echo "ERROR: AppDynamics agent found but configuration missing; check your secrets configuration."
			exit 1
		fi

		echo "INFO: preparing AppDynamics config $conf"

		# controller config
		sed -i "1,$ s/<controller-host.*$/<controller-host>$APPDYNAMICS_CONTROLLER_HOST<\/controller-host>/" $conf
		sed -i "1,$ s/<controller-port.*$/<controller-port>$APPDYNAMICS_CONTROLLER_PORT<\/controller-port>/" $conf
		sed -i "1,$ s/<controller-ssl-enabled.*$/<controller-ssl-enabled>$APPDYNAMICS_CONTROLLER_SSL<\/controller-ssl-enabled>/" $conf

		# access config
		sed -i "1,$ s/<account-name.*$/<account-name>$APPDYNAMICS_ACCOUNT_NAME<\/account-name>/" $conf
		sed -i "1,$ s/<account-access-key.*$/<account-access-key>$APPDYNAMICS_ACCOUNT_KEY<\/account-access-key>/" $conf

		# runtime config
		sed -i "1,$ s/<application-name.*$/<application-name>APPDYNAMICS_APPLICATION<\/application-name>/" $conf

		#only add tier and nodename to the app agent not to the machine agent
		if [[ $conf != *"machine"* ]]
		then
			sed -i "1,$ s/<tier-name.*$/<tier-name>APPDYNAMICS_TIER<\/tier-name>/" $conf
			sed -i "1,$ s/<node-name.*$/<node-name>APPDYNAMICS_NODE<\/node-name>/" $conf
		fi
		# add overlay configs if available
		if [ -d /opt/proprietary/appdynamics-conf ]; then
			cp /opt/proprietary/appdynamics-conf/* $(dirname $conf)
		fi

		# register config for runtime
		echo $conf >> /opt/proprietary/appdynamics-configs
	done

  # setup analytics Agent
	# check if GLOBAL ID is set in secret_vars
	if [ -z "$APPDYNAMICS_ACCOUNT_GLOBALNAME" ]; then

	   echo "INFO: no GLOBAL Appdynamics Accountname is configured; skipping AppDynamics Analyse Agent setup"
	   exit 0
	else
	   # enable analytics Agent
	   monitor_xml="/opt/proprietary/appdynamics-machine/monitors/analytics-agent/monitor.xml"
	   sed -i "1,$ s/<enabled.*$/<enabled>true<\/enabled>/" $monitor_xml

           # check if there is a custom properties_file if not then setup analytics properties file
           properties_file="/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/analytics-agent.properties"
           if [ -f /opt/proprietary/appdynamics-conf/analytics-agent.properties ]; then
              # copy file to machine agent
              cp /opt/proprietary/appdynamics-conf/analytics-agent.properties $properties_file
           else
             echo "ERROR: property file doesn't exist"
             exit 1
           fi
	fi

	# make sure they are writeable by docker users
	for agent in $appdynamics_agents; do
		chown -R root:root $agent
		find $agent -type d -exec chmod 0777 '{}' ';'
	done
fi
