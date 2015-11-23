#!/bin/bash

# pull at install time, to have agent be available and in a stable version on ami launch
logstashImage="immobilienscout24/lma-logstash:1"

cat <<EOF > /etc/default/docker
DOCKER_OPTS="--log-driver=gelf --log-opt gelf-address=udp://localhost:12201" 
EOF

docker pull ${logstashImage}
docker pull busybox

cat <<EOF > /etc/init/logstash.conf
description "logstash"

start on filesystem and started docker and stopped cloud-final
stop on runlevel [!2345]

script
  set +e
  RESULT=\$(docker inspect logstash)
  if [ \$? = 0 ]; then
    true
  else
    availabilityZone=\$(ec2metadata --availability-zone)
    region=\$(echo \${availabilityZone} | rev | cut -c 2- | rev)
    stream=\$(cat /etc/default/log-stream-name)
    rm -rf /etc/logstash.conf
    cat <<__EOF > /etc/logstash.conf
input {
  # Graylog Extended Log Format - https://www.graylog.org/resources/gelf/
  # https://www.elastic.co/guide/en/logstash/current/plugins-inputs-gelf.html
  gelf {
    # listen to udp://0.0.0.0:12201
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
  # extract ecs 'task', 'taskRevision' and 'container' name 
  # http://grokconstructor.appspot.com/do/match
  grok {
    match => [
      "container_name",
      "^ecs-%{GREEDYDATA:task}-%{INT:taskRevision}-%{GREEDYDATA:container}-[^-]{20}$"
    ]
  }
}

output {
  # https://github.com/samcday/logstash-output-kinesis
  kinesis {
    stream_name => "\${stream}"
    region => "eu-west-1"
    # for more settings see
    # https://github.com/awslabs/amazon-kinesis-producer/blob/v0.10.0/java/amazon-kinesis-producer/src/main/java/com/amazonaws/services/kinesis/producer/KinesisProducerConfiguration.java#L230
    metrics_level => "none"
    aggregation_enabled => false
  }
}

#output { 
#  stdout {
#    codec => rubydebug
#  } 
#}
__EOF
    docker run \
      --log-driver=syslog \
      -d \
      --restart=always \
      --name logstash \
      -p 12201:12201/udp \
      -v /etc/logstash.conf:/logstash.conf \
      ${logstashImage} \
      logstash -f /logstash.conf
    sleep 5
    docker run --rm busybox echo "create log-stream"
  fi
end script
EOF