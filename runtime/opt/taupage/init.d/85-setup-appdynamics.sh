#!/bin/sh

# read global taupage config
eval $(/opt/taupage/bin/parse-yaml.py /etc/taupage.yaml "config")

if [ -z "$config_appdynamics_application" ]; then
	echo "INFO: no AppDynamics application configured; skipping AppDynamics setup"
	exit 0
fi

# node name has to be unique across the whole ecosystem
node="${config_application_id}_${config_application_version}_$(hostname)"

# replace app specific configurations in all appdynamics configs
cat /opt/proprietary/appdynamics-configs | while read conf; do
	echo "INFO: configuring AppDynamics agent $conf for $config_appdynamics_application / $config_application_id / $node"
	sed -i "1,$ s/APPDYNAMICS_APPLICATION/$config_appdynamics_application/" $conf
	sed -i "1,$ s/APPDYNAMICS_TIER/$config_application_id/" $conf
	sed -i "1,$ s/APPDYNAMICS_NODE/$node/" $conf

	# provide unique ID information
	agent_dir=$(dirname $(dirname $conf))
	echo $node > $agent_dir/uniqueHostId
done

# start machine agent
service appdynamics start
