#!/bin/sh
# read /etc/zalando.yaml
# get logentries Key and register logentries daemon

#parse yaml function
parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}


#read zalando.yaml file
eval $(parse_yaml /etc/zalando.yaml "config_")

#set more readable variables 
ACCOUNTKEY=$config_logentries_account_key
TOKENID=$config_logentries_token_id
APPID=$config_application_id
APPVERSION=$config_application_version

#remove "'" from Version number
APPVERSION="${APPVERSION%\'}"
APPVERSION="${APPVERSION#\'}"

#check if appname and appversion is provided from the yaml
if [ -z "$APPID" ] && [ -z "$APPVERSION" ]; 
then
	echo "ERROR: no application_id and application_version are in the yaml files";
	exit
fi

#if logentries account exists in the yaml file. Register the logentries Daemon to this Account
if [ -n "$ACCOUNTKEY" ];
then

        echo -n "register logentries Daemon ... ";
        #register logentries account
        le register --force --account-key=$ACCOUNTKEY
	if [ "$?" = "0" ];
	then
		echo -n "DONE"
	else
		echo -n "ERROR: Register to Logentries account failed";
		exit
	fi	
        
	#add default EC2 followed logfiles and TokenID to le config 
        le follow /var/log/syslog
        le follow /var/log/auth.log
        le follow /var/log/audit.log
        le follow /var/log/application.log

	if [ -n "$TOKENID" ];
	then
echo "
[$APPID-$APPVERSION-syslog]
path = /var/log/syslog
token = $TOKENID
" >> /etc/le/config

echo "
[$APPID-$APPVERSION-auth]
path = /var/log/auth.log
token = $TOKENID
" >> /etc/le/config

echo "
[$APPID-$APPVERSION-audit]
path = /var/log/audit.log
token = $TOKENID
" >> /etc/le/config

echo "
[$APPID-$APPVERSION-application]
path = /var/log/application.log
token = $TOKENID
" >> /etc/le/config

	else
		echo "ERROR: no TokenID in .yaml file";
		exit
	fi
		
        #restart daemon
        service logentries restart
else 
	echo "ERROR: no logentries AccountKey was specify in the .yaml file";
	exit
fi
