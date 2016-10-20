#!/bin/bash

#just create custom log directory
if [ ! -d /var/log-custom ]
then
  mkdir /var/log-custom
fi

#make writeable for application user that are docker is able to write custom logs
chown -Rf application:application /var/log-custom
