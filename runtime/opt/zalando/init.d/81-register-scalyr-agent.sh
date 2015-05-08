#!/bin/sh
# read /etc/taupage.yaml
# get scalyr Key and register the agent

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


#read taupage.yaml file
eval $(parse_yaml /etc/taupage.yaml "config_")

#set more readable variables
ACCOUNTKEY=$config_scalyr_account_key
APPID=$config_application_id
APPVERSION=$config_application_version

#remove "'" from Version number
APPVERSION="${APPVERSION%\'}"
APPVERSION="${APPVERSION#\'}"


#check if appname and appversion is provided from the yaml
if [ -z "$APPID" ] && [ -z "$APPVERSION" ];
then
	echo "ERROR: no application_id and application_version are in the yaml files";
	exit;
fi

#if logentries account exists in the yaml file. Register the logentries Daemon to this Account
if [ -n "$ACCOUNTKEY" ];
then

        echo -n "register scalyr Daemon ... ";
        #register scalyr account
	wget -q https://www.scalyr.com/scalyr-repo/stable/latest/install-scalyr-agent-2.sh && bash ./install-scalyr-agent-2.sh --set-api-key "$ACCOUNTKEY" --start-agent
	if [ $? -eq 0 ];
	then
		echo -n "DONE"
	else
		echo -n "ERROR: Register to Scalyr account failed";
		exit;
	fi
else
	echo "ERROR: no scalyr AccountKey was specify in the .yaml file";
	exit;
fi

#default path to scalyr config
scalyr_config=/etc/scalyr-agent-2/agent.json

#set serverhost to appname and version
echo -n "set app name and version ...";
sed -i "1,$ s/\/\/\ serverHost:\ \"REPLACE THIS\"/serverHost:\ \"$APPID\-$APPVERSION\"/g" $scalyr_config

if [ $? -eq 0 ];
then
	echo -n "DONE";
else
	echo -n "ERROR";
	exit
fi

#follow syslog
echo "";
echo -n "insert syslog to follow ... ";
sed -i "/logs\:\ \[/a { path: \"/var/log/syslog\", attributes: {parser: \"systemLog\", appname: \"$APPID\", appversion: \"$APPVERSION\"} } " $scalyr_config
if [ $? -eq 0 ];
then
	echo -n "DONE";
else
        echo -n "ERROR";
        exit
fi


#follow auth.log
echo "";
echo -n "insert authlog to follow ... ";
sed -i "/logs\:\ \[/a { path: \"/var/log/auth.log\", attributes: {parser: \"systemLog\"} } " $scalyr_config
if [ $? -eq 0 ];
then
	echo -n "DONE";
	echo "";
else
	echo -n "ERROR";
        exit
fi

#follow audit.log
echo "";
echo -n "insert audit to follow ... ";
sed -i "/logs\:\ \[/a { path: \"/var/log/audit.log\", attributes: {parser: \"systemLog\"} } " $scalyr_config
if [ $? -eq 0 ];
then
	echo -n "DONE";
	echo "";
else
	echo -n "ERROR";
        exit
fi

#follow application.log
echo "";
echo -n "insert authlog to follow ... ";
sed -i "/logs\:\ \[/a { path: \"/var/log/application.log\", attributes: {parser: \"systemLog\"} } " $scalyr_config
if [ $? -eq 0 ];
then
	echo -n "DONE";
	echo "";
else
	echo -n "ERROR";
        exit
fi

#if there was no Errors restart the agent
scalyr-agent-2 restart

