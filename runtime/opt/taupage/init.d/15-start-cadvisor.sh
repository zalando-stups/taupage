#!/usr/bin/env bash

eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

if [ "$config_cadvisor_enabled" = True ] ; then
  echo "starting cadvisor docker container bound to port 9999"
  docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=9999:8080 \
    --detach=true \
    --name=cadvisor \
    google/cadvisor:latest
else
  echo "cadvisor disabled --> doing nothing"
fi