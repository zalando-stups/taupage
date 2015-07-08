#!/bin/bash

#install and register ruxid agent
AGENT=/data/ruxit-Agent-Linux-1.71.160.sh

#read taupage.yaml file
eval $(/opt/taupage/bin/parse-yaml.py /etc/taupage.yaml "config")

RUXIT_TOKEN=$config_ruxit_account_key

#check if agent is there 
if [ -f $AGENT ];
then
   if [ -n "$RUXIT_TOKEN" ];
   then
      echo -n "Register Ruxit Agent ... "
      #insert ruxit_token_id
      sed -i "1,$ s/ACCOUNTTOKEN/$RUXIT_TOKEN/g" $AGENT
      #install agent
      /bin/sh $AGENT
   else
      echo "ERROR: Ruxit Token is not set";
      exit;
   fi
else
   echo "ERROR: Ruxit install script is not installed"
   exit;
fi



