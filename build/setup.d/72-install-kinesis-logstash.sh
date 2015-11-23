#!/bin/bash

# pull at install time, to have agent be available and in a stable version on ami launch
logstashImage="immobilienscout24/lma-logstash:1"

docker pull ${logstashImage}
docker pull busybox
