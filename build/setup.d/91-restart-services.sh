#!/bin/bash

#restart rsyslog because we upload new config file in our setup process
service rsyslog restart

#TODO First check if this is really necessary 
#restart newrelic and docker because we add the user Newrelic to the "application" group
#service docker restart
#service newrelic-sysmond restart
