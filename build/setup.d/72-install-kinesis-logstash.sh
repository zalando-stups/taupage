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

function createTagsToLogstashHelper {
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

function createLogstashUpstartService {
  cat <<EOF > /etc/init/logstash.conf
description "logstash"

start on filesystem and started docker and stopped cloud-init-local
stop on runlevel [!2345]

script
  set +e
  RESULT=\$(docker inspect logstash)
  if [ \$? = 0 ]; then
    true
  else
    echo "/meta/taupage.yaml"
    cat /meta/taupage.yaml
    
    if [ "\$(cat /meta/taupage.yaml | shyaml get-value 'logstash.enabled' 'false')" = "false" ]; then
      echo "logstash not enabled."
      exit 0
    fi
    
    instanceId=\$(ec2metadata --instance-id)
    instanceAvailabilityZone=\$(ec2metadata --availability-zone)
    instanceRegion=\$(echo \${instanceAvailabilityZone} | rev | cut -c 2- | rev)

    region=\$(cat /meta/taupage.yaml | shyaml get-value "logstash.kinesis_region" "${instanceRegion}")
    stream=\$(cat /meta/taupage.yaml | shyaml get-value "logstash.kinesis_stream" "logging")

    rm -rf /etc/logstash.conf
    cat <<__EOF > /etc/logstash.conf
input {
  # Graylog Extended Log Format - https://www.graylog.org/resources/gelf/
  # https://www.elastic.co/guide/en/logstash/current/plugins-inputs-gelf.html
  gelf {
    # listen to udp://0.0.0.0:12201
  }
  
  heartbeat {
    interval => 10
    type => "heartbeat"
  }
}

filter {
  # rename 'short_message' to 'message'
  if [short_message] {
    mutate {
      rename => { "short_message" => "message" }
    }
  }
}

# extract json from field 'message'
filter {
   grok {
      match => ["message", "(?<jsonMessage>^{.*}$)"]
      tag_on_failure => []
   }
}

filter {
  # remove 'message' when jsonMessage found
  if [jsonMessage] {
    mutate {
      remove_field => ["message"]
    }
  }
  
  # try to import json from field 'jsonMessage'
  json {
    # https://www.elastic.co/guide/en/logstash/current/plugins-filters-json.html
    source => "jsonMessage"
    remove_field => "jsonMessage"
  }
}

filter {
  # add instanceId, availabilityZone, region
  mutate {
    add_field => { "instance_id" => "\${instanceId}" }
    add_field => { "availability_zone" => "\${availabilityZone}" }
    add_field => { "region" => "\${region}" }
__EOF

  /bin/tags-to-logstash.sh >> /etc/logstash.conf

cat <<__EOF >> /etc/logstash.conf
  }
}

# force field 'level' to be a string
filter {
  mutate {
    convert => { "level" => "string" }
  }
}

output {
  stdout {
    codec => rubydebug
  } 
  if [type] == "heartbeat" {
    stdout {
      codec => rubydebug
    } 
  } else {
    # https://github.com/samcday/logstash-output-kinesis
    kinesis {
      stream_name => "\${stream}"
      region => "\${region}"
      # for more settings see
      # https://github.com/awslabs/amazon-kinesis-producer/blob/v0.10.0/java/amazon-kinesis-producer/src/main/java/com/amazonaws/services/kinesis/producer/KinesisProducerConfiguration.java#L230
      metrics_level => "none"
      aggregation_enabled => false
      randomized_partition_key => true
    }
  }
}
__EOF

    docker run \
      -d \
      --restart=always \
      --name logstash \
      -p 12201:12201/udp \
      -v /etc/logstash.conf:/logstash.conf \
      ${logstashImage} \
      logstash -f /logstash.conf
    
    sleep 5
    
    # wait for first heartbeat in logs
    # until docker logs logstash | grep -m 1 "heartbeat"; do: sleep 1; done
  fi
end script
EOF
}

pip install shyaml
buildLogstashDockerContainer
createTagsToLogstashHelper
createLogstashUpstartService

# testing
# docker kill logstash || true; docker rm logstash || true; rm -rf /var/log/upstart/logstash.log && service logstash start && sleep 2 && less /var/log/upstart/logstash.log
