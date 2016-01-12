#!/bin/bash

eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

rsyslog_max_message_size=$config_rsyslog_max_message_size
rsyslog_config=/etc/rsyslog.conf

if [[ -n "$rsyslog_max_message_size" ]]; then
    echo "setting rsyslog_max_message_size..."
    grep -q '^$MaxMessageSize' $rsyslog_config || sed -i "1s/^/\$MaxMessageSize ${rsyslog_max_message_size}\n/" $rsyslog_config
    service rsyslog restart
fi
