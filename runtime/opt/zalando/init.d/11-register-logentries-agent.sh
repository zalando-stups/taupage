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

#if logentries account exists in the yaml file. Register the logentries Daemon to this Account
if [ ! -z "$config_logentries_account_key" ];
then

        echo "register logentries Daemon ...";
        #if custom hostname is set, than register with this name
        if [ ! -z "$config_logentries_hostname" ];
        then
                #register logentries account with custom hostname
                le register --account-key=$config_logentries_account_key --name=$config_logentries_hostname
        else
                #register logentries account
                le register --account-key=$config_logentries_account_key
        fi

        #install logentries daemon
        apt-get install -y -q logentries-daemon

        #add default EC2 followed logfiles
        le follow /var/log/syslog
        le follow /var/log/auth.log
        le follow /var/log/boot.log
        le follow /var/log/cloud-init.log
        le follow /var/log/application.log
        le follow "/var/log/upstart/*.log"

        #restart daemon
        service logentries restart
else 
	echo "no logentries AccountKey was specify in the .yaml file"
fi
