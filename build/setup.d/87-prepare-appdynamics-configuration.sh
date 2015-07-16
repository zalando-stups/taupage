#!/bin/bash

set -x

# check if directory exists

if [ ! -d /opt/proprietary/appdynamics-machine ]; then
	echo "INFO: no AppDynamics agent found, skip configuration"
	exit
fi

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
	sed -i "1,$ s/<tier-name.*$/<tier-name>APPDYNAMICS_TIER<\/tier-name>/" $conf
	sed -i "1,$ s/<node-name.*$/<node-name>APPDYNAMICS_NODE<\/node-name>/" $conf

	# register config for runtime
	echo $conf >> /opt/proprietary/appdynamics-configs
done

# make sure they are writeable by docker users
for agent in $appdynamics_agents; do
	chown -R root:root $agent
	find $agent -type d -exec chmod 0777 '{}' ';'
done
