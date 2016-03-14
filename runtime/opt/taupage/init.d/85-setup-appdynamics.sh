#!/bin/sh

# read global taupage config
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

if [ -z "$config_appdynamics_application" ]; then
	echo "INFO: no AppDynamics application configured; skipping AppDynamics setup"
	exit 0
fi

# checking for multi-tenant support.
# All 3 properties (appdynamics_account_name, appdynamics_account_globalname, appdynamics_account_globalname)
# must be set for multi-tenancy in taupage.yaml
if [ -n "$config_appdynamics_account_name" ]; then
    if [ -n "$config_appdynamics_account_access_key" ]; then
        if [ -n "$config_appdynamics_account_globalname" ]; then
            # we have to overwrite the default account settings in the analytics agent props file
            properties_file="/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/analytics-agent.properties"
            sed -i "1,$ s/http.event.accountName.*$/http.event.accountName=$config_appdynamics_account_globalname/" $properties_file
            sed -i "1,$ s/http.event.accessKey.*$/http.event.accessKey=$config_appdynamics_account_access_key/" $properties_file
        else
            echo "ERROR: AppDynamics Multi Tenancy for account $config_appdynamics_account_name was detected \n
                but appdynamics_account_globalname wasn't set. Please provide the proper appdynamics_account_globalname!"
            exit 1
        fi
    else
        echo "ERROR: AppDynamics Multi Tenancy for account $config_appdynamics_account_name was detected \n
            but appdynamics_account_access_key wasn't set. Please provide the proper account_access_key!"
        exit 1
    fi
fi

# node name has to be unique across the whole ecosystem
node="${config_notify_cfn_stack}_$(hostname)_`ec2metadata --availability-zone`"

# replace app specific configurations in all appdynamics configs
cat /opt/proprietary/appdynamics-configs | while read conf; do
	echo "INFO: configuring AppDynamics agent $conf for $config_appdynamics_application / $config_application_id / $node"
	# multi-tenant support:
	# if we got an appdynamics account name provided by taupage.yaml then overwrite the default one
	if [ -n "$config_appdynamics_account_name" ]; then
	    sed -i "1,$ s/<account-name.*$/<account-name>$config_appdynamics_account_name<\/account-name>/" $conf
    fi
    if [ -n "$config_appdynamics_account_access_key" ]; then
	    sed -i "1,$ s/<account-access-key.*$/<account-access-key>$config_appdynamics_account_access_key<\/account-access-key>/" $conf
    fi

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
