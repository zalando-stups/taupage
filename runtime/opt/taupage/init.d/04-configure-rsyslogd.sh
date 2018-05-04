#!/bin/bash

eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

rsyslog_max_message_size=$config_rsyslog_max_message_size
rsyslog_aws_metadata=$config_rsyslog_aws_metadata
rsyslog_config=/etc/rsyslog.conf

if [[ -n "$rsyslog_max_message_size" ]]; then
    echo "setting rsyslog_max_message_size..."
    grep -q '^$MaxMessageSize' $rsyslog_config || sed -i "1s/^/\$MaxMessageSize ${rsyslog_max_message_size}\n/" $rsyslog_config
fi

if [[ -n "$rsyslog_aws_metadata" ]]; then
    echo "enabling AWS metadata in rsyslog..."
    IID="$(curl --fail -s http://169.254.169.254/latest/dynamic/instance-identity/document)"
    if [ $? -eq 0 ]; then
      AWS_ACCOUNT="$(echo "$IID" | jq -r .accountId)"
      AWS_REGION="$(echo "$IID" | jq -r .region)"
      cat >/etc/rsyslog.d/00-template.conf <<EOF
template(name="DefaultFormat" type="list") {
    property(name="timestamp" dateFormat="rfc3164")
    constant(value=" $AWS_ACCOUNT $AWS_REGION ")
    property(name="hostname")
    constant(value=" ")
    property(name="syslogtag")
    property(name="msg" spifno1stsp="on" )
    property(name="msg" droplastlf="on" )
    constant(value="\n")
}

\$ActionFileDefaultTemplate DefaultFormat
EOF
    fi
fi

if [[ -n "$rsyslog_max_message_size" ]] || [[ -n "$rsyslog_aws_metadata" ]]; then
    service rsyslog restart
fi
