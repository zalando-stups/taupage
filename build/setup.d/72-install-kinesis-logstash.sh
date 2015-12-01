#!/bin/bash

# pull at install time, to have agent be available and in a stable version on ami launch
logstashImage="immobilienscout24/lma-logstash:1"

pip install shyaml

docker pull ${logstashImage}
docker pull busybox

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
    
    if [ "\$(cat /meta/taupage.yaml | shyaml get-value 'logging.enabled' 'false')" = "false" ]; then
      echo "Logging not enabled."
      exit 0
    fi
    
    instanceId=\$(ec2metadata --instance-id)
    availabilityZone=\$(ec2metadata --availability-zone)
    region=\$(echo \${availabilityZone} | rev | cut -c 2- | rev)
    stream=\$(cat /meta/taupage.yaml | shyaml get-value "logging.kinesis_stream" "logging")
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
  # add instanceId, availabilityZone, region
  mutate {
    add_field => { "instance_id" => "\${instanceId}" }
    add_field => { "availability_zone" => "\${availabilityZone}" }
    add_field => { "region" => "\${region}" }
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