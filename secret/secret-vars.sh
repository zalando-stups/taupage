# Example "secret-vars.sh"
# this file contains the "private" information
# baked into the AMI

# even SSH access granting service URL
EVEN_URL=https://even.stups.example.org
LOGGLY_TOKEN=NOT_SET
NEWRELIC_LICENSE_KEY=NOT_SET
TOKEN_SERVICE_URL=
INSTANCE_LOGS_URL=

# for appdynamics support uncomment the following lines and modify the values. 
#APPDYNAMICS_CONTROLLER_HOST=CONTROLLERHOSTNAME
#APPDYNAMICS_CONTROLLER_PORT=443
#APPDYNAMICS_CONTROLLER_SSL="true"
#APPDYNAMICS_ACCOUNT_NAME="ACCOUNTNAME"
#APPDYNAMICS_ACCOUNT_KEY="ACCOUNTKEY"
#APPDYNAMICS_ACCOUNT_GLOBALNAME="GLOBALNAME"
