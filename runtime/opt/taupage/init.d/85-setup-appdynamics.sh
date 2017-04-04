#!/bin/bash

# read global taupage config
eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

#set more readable variables
APPLICATIONNAME=$config_appdynamics_application
ACCOUNT_NAME=$config_appdynamics_account_name
ACCESSKEY=$config_appdynamics_account_access_key
ACCOUNT_GLOBALNAME=$config_appdynamics_account_globalname
STACK_NAME=$config_notify_cfn_stack
ENABLE_LOGGING=$config_appdynamics_enable_logging
SCALYR_KEY=$config_scalyr_account_key

# If KMS encrypted, decrypt KMS and save to ACCOUNTKEY variable
if [[ $ACCESSKEY == "aws:kms:"* ]]; then
	ACCOUNTKEY=${ACCESSKEY##aws:kms:}
	ACCOUNTKEY=`python3 /opt/taupage/bin/decrypt-kms.py $ACCOUNTKEY`
	#overwrite ACCESSKEY with decrypted value
	ACCESSKEY=$ACCOUNTKEY
fi
if [[ $ACCOUNT_GLOBALNAME == "aws:kms:"* ]]; then
	ACCOUNT_GLOBALNAME=${ACCOUNT_GLOBALNAME##aws:kms:}
	ACCOUNT_GLOBALNAME=`python3 /opt/taupage/bin/decrypt-kms.py $ACCOUNT_GLOBALNAME`
fi

if [ -z "$APPLICATIONNAME" ]; then
	echo "INFO: no AppDynamics application configured; skipping AppDynamics setup"
	exit 0
fi

# checking for multi-tenant support.
# All 3 properties (appdynamics_account_name, appdynamics_account_globalname, appdynamics_account_globalname)
# must be set for multi-tenancy in taupage.yaml
if [ -n "$ACCOUNT_NAME" ]; then
    if [ -n "$ACCESSKEY" ]; then
        if [ -n "$ACCOUNT_GLOBALNAME" ]; then
            # we have to overwrite the default account settings in the analytics agent props file
            properties_file="/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/analytics-agent.properties"
            sed -i "s/http.event.accountName.*$/http.event.accountName=$ACCOUNT_GLOBALNAME/" $properties_file
            sed -i "s/http.event.accessKey.*$/http.event.accessKey=$ACCESSKEY/" $properties_file
        else
            echo "ERROR: AppDynamics Multi Tenancy for account $ACCOUNT_NAME was detected \n
                but appdynamics_account_globalname wasn't set. Please provide the proper appdynamics_account_globalname!"
            exit 1
        fi
    else
        echo "ERROR: AppDynamics Multi Tenancy for account $ACCOUNT_NAME was detected \n
            but appdynamics_account_access_key wasn't set. Please provide the proper account_access_key!"
        exit 1
    fi
fi

# node name has to be unique across the whole ecosystem
generated_nodename="${config_notify_cfn_stack}_$(hostname)_$(ec2metadata --availability-zone)_$(ec2metadata --instance-id)"
#truncate the nodename if it has more than 100 chars
node=${generated_nodename:0:99}

# write values in config.js for AppD Node.js agent integration
nodejsSnippet="/opt/proprietary/appdynamics-nodejs/config.json"
# check if node.js snippet exists and add values
if [ -f "$nodejsSnippet" ]; then
	sed -i "s/APPLICATIONNAME/$APPLICATIONNAME/" $nodejsSnippet
	sed -i "s/TIERNAME/$config_application_id/" $nodejsSnippet
	sed -i "s/NODENAME/$node/" $nodejsSnippet
	if [ -n "$ACCOUNT_NAME" ]; then
		sed -i "s/customer1/$ACCOUNT_NAME/" $nodejsSnippet
  fi
	if [ -n "$ACCESSKEY" ]; then
		sed -i "s/accountAccessKey.*$/accountAccessKey:\ \'$ACCESSKEY\'\,/" $nodejsSnippet
	fi
fi


# replace app specific configurations in all appdynamics configs
cat /opt/proprietary/appdynamics-configs | while read conf; do
	echo "INFO: configuring AppDynamics agent $conf for $APPLICATIONNAME / $config_application_id / $node"
	# multi-tenant support:
	# if we got an appdynamics account name provided by taupage.yaml then overwrite the default one
	if [ -n "$ACCOUNT_NAME" ]; then
	    sed -i "s/<account-name.*$/<account-name>$ACCOUNT_NAME<\/account-name>/" $conf
    fi
    if [ -n "$ACCESSKEY" ]; then
	    sed -i "s/<account-access-key.*$/<account-access-key>$ACCESSKEY<\/account-access-key>/" $conf
    fi

	sed -i "s/APPDYNAMICS_APPLICATION/$APPLICATIONNAME/" $conf

	#only add tier and nodename to the app agent not to the machine agent
	if [[ $conf != *"machine"* ]]
	then
		sed -i "s/APPDYNAMICS_TIER/$config_application_id/" $conf
		sed -i "s/APPDYNAMICS_NODE/$node/" $conf
	fi


	# provide unique ID information
	agent_dir=$(dirname $(dirname $conf))
	echo $node > $agent_dir/uniqueHostId
done

# since Scalyr is our new central log shipping provider
# DISABLE Logging if a SCALYR Key is present if there is no SCALYR_KEY enable logging again
if [[ -z $SCALYR_KEY || ( -n $ENABLE_LOGGING && "$ENABLE_LOGGING" ==  "True" ) ]]; then

	# configure application.log & syslog
	# first "hack" this should be configurable over the taupage.yaml file.
	application_log_job="/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/job/application-log.job"
	syslog_job="/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/job/syslog.job"
	appdynamics_machineagent_job="/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/job/appdynamics-machineagent-log.job"
	appdynamics_jvmagent_job="/opt/proprietary/appdynamics-machine/monitors/analytics-agent/conf/job/appdynamics-jvmagent-log.job"

	#enable application.log job
	if [ -f $application_log_job ]; then
	    sed -i "s/enabled.*$/enabled: true/" $application_log_job
	    sed -i "s/APPLICATION_ID/$config_application_id/" $application_log_job
	    sed -i "s/APPLICATION_VERSION/$config_application_version/" $application_log_job
	    sed -i "s/APPDYNAMICS_NODE/$node/" $application_log_job
	    sed -i "s/APPDYNAMICS_STACKNAME/$STACK_NAME/" $application_log_job
	    sed -i "s/APPDYNAMICS_APPLICATION/$APPLICATIONNAME/" $application_log_job
	    sed -i "s/APPDYNAMICS_TIERNAME/$config_application_id/" $application_log_job
	else
	    echo "INFO: application_job file doesn't exists, skipping setup"
	fi

	# enable syslogjob
	if [ -f $syslog_job ]; then
	    sed -i "s/enabled.*$/enabled: true/" $syslog_job
	    sed -i "s/APPLICATION_ID/$config_application_id/" $syslog_job
	    sed -i "s/APPLICATION_VERSION/$config_application_version/" $syslog_job
	    sed -i "s/APPDYNAMICS_NODE/$node/" $syslog_job
	    sed -i "s/APPDYNAMICS_STACKNAME/$STACK_NAME/" $syslog_job
	    sed -i "s/APPDYNAMICS_APPLICATION/$APPLICATIONNAME/" $syslog_job
	    sed -i "s/APPDYNAMICS_TIERNAME/$config_application_id/" $syslog_job
	else
	  echo "INFO: syslog_job file doesn't exists, skipping setup"
	fi

	# enable appdynamics machineagent job
	if [ -f $appdynamics_machineagent_job ]; then
		  # leave it disabled per default
	    #sed -i "1,$ s/enabled.*$/enabled: true/" $appdynamics_machineagent_job
	    sed -i "s/APPLICATION_ID/$config_application_id/" $appdynamics_machineagent_job
	    sed -i "s/APPLICATION_VERSION/$config_application_version/" $appdynamics_machineagent_job
	    sed -i "s/APPDYNAMICS_NODE/$node/" $appdynamics_machineagent_job
	else
	  echo "INFO: appdynamics-machineagent-log job file doesn't exists, skipping setup"
	fi

	# enable appdynamics jvmagent job
	if [ -f $appdynamics_jvmagent_job ]; then
		  # leave it disabled per default
	    #sed -i "1,$ s/enabled.*$/enabled: true/" $appdynamics_jvmagent_job
	    sed -i "s/APPLICATION_ID/$config_application_id/" $appdynamics_jvmagent_job
	    sed -i "s/APPLICATION_VERSION/$config_application_version/" $appdynamics_jvmagent_job
	    sed -i "s/APPDYNAMICS_NODE/$node/" $appdynamics_jvmagent_job
	else
	  echo "INFO: appdynamics-jvmagent-log job file doesn't exists, skipping setup"
	fi
# close enable log IF
fi

#add TIER_NAME to the machine agent if the TIER_NAME was provided over the TAUPAGE_CONFIG
if [ -n "$config_appdynamics_machineagent_tiername" ]; then
	machineagentconf="/opt/proprietary/appdynamics-machine/conf/controller-info.xml"
	sed -i "1,$ s/<tier-name.*$/<tier-name>$config_application_id<\/tier-name>/" $machineagentconf
	sed -i "1,$ s/<node-name.*$/<node-name>$node<\/node-name>/" $machineagentconf
	sed -i "1,$ s/<application-name.*$/<application-name>$config_application_id/<\/application-name>/" $machineagentconf
fi

#include necsessary scala/play/akka classes if this was set in taupage.yaml
if [ "$config_appdynamics_include_scala_classes" == "True" ]; then
	jvmagentconf="/opt/proprietary/appdynamics-jvm/latest_version/conf/app-agent-config.xml"
	sed -i "/scala.concurrent/d" $jvmagentconf
	sed -i "/akka/d" $jvmagentconf
	sed -i "/play.core.server/d" $jvmagentconf
	sed -i "/play.api.libs.concurrent/d" $jvmagentconf
fi
# start machine agent we will move the start after the AppAgent.
# service appdynamics start
