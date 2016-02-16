#!/bin/sh

# read global taupage config
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

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

   # configure application.log & syslog
   # first "hack" this should be configurable over the taupage.yaml file.
   application_log_job="/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/job/application-log.job"
   syslog_job="/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/job/syslog.job"

   #enable application.log job
   if [ -f $application_log_job ]; then
      sed -i "1,$ s/enabled.*$/enabled: true/" $application_log_job
      sed -i "1,$ s/APPLICATION_ID/$config_application_id/" $application_log_job
      sed -i "1,$ s/APPLICATION_VERSION/$config_application_version/" $application_log_job
      sed -i "1,$ s/APPDYNAMICS_NODE/$node/" $application_log_job
   else
      echo "INFO: application_job file doesn't exists, skipping setup"
   fi

   # enable syslogjob
   if [ -f $syslog_job ]; then
      sed -i "1,$ s/enabled.*$/enabled: true/" $syslog_job
      sed -i "1,$ s/APPLICATION_ID/$config_application_id/" $syslog_job
      sed -i "1,$ s/APPLICATION_VERSION/$config_application_version/" $syslog_job
      sed -i "1,$ s/APPDYNAMICS_NODE/$node/" $syslog_job

   else
      echo "INFO: syslog_job file doesn't exists, skipping setup"
   fi


# start machine agent
service appdynamics start
