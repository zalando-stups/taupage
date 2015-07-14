#!/bin/bash

adddynamic_archive=/data/AppdynamicAgent.zip
no_appdynamic=/data/no_appdynamic
appdynamic_xml=/data/appdynamics/conf/controller-info.xml


#check if there is a no_appdynamics file and exit
if [ -f $no_appdynamic ];
then
        echo "INFO: AppDynamics Java Agent disabled.";
        exit;
fi

#unzip appdynmaic agent
if [ -f $appdynamic_archive ]
then
        #unzip the archive
        cd /data/
        unzip $appdynamic_archive -d appdynamics
else
        echo "ERROR: No AppDynamics Java Agent was found!"
        exit;
fi

############################
# CHANGE DEFAULT XML  FILE #
############################

echo "INFO: change default controller-info.xml"

#set controller_host variable
sed -i "1,$ s/controller-host.*$/<controller-host>CONTROLLERHOST</controller-host>/" $appdynamic_xml

#set controller_port variable
sed -i "1,$ s/controller-port.*$/<controller-port>443</controller-port>/" $appdynamic_xml

#set application_name variable
sed -i "1,$ s/application-name.*$/<application-name>APPLICATIONNAME</application-name>/" $appdynamic_xml

#set tier-name variable
sed -i "1,$ s/tier-name.*$/<tier-name>TIERNAME</tier-name>/" $appdynamic_xml

#set controller ssl true
sed -i "1,$ s/controller-ssl-enabled.*$/<controller-ssl-enabled>true</controller-ssl-enabled>/" $appdynamic_xml

#set node-name variable
sed -i "1,$ s/node-name.*$/<node-name>NODENAME</node-name>/" $appdynamic_xml



