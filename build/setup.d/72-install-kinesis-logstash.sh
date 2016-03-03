#!/bin/bash

logstashImage="local/logstash:1"

function buildLogstashDockerContainer {
  cat <<__EOF > /tmp/Dockerfile
FROM logstash:2.2
RUN /opt/logstash/bin/plugin install logstash-output-kinesis
__EOF
  cd /tmp/
  docker build --tag=${logstashImage} .
  cd -
  
  docker pull busybox
}

function createTagsToLogstashHelperScript {
  # store logstash to 
  cat <<__EOF > /bin/tags-to-logstash.sh
#!/usr/bin/env python3

import yaml

stream = open("/meta/taupage.yaml", "r")
config = yaml.load(stream)

if config.get('logstash', {}).get('tags'):
    for k,v in config.get('logstash', {}).get('tags').items():
        print('    add_field => {{ "{0}" => "{1}" }}'.format(k, v))
__EOF
  chmod +x /bin/tags-to-logstash.sh
}

pip install shyaml
buildLogstashDockerContainer
createTagsToLogstashHelperScript
