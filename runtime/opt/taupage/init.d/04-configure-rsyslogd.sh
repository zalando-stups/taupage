#!/bin/bash

eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

rsyslog_max_message_size=$config_rsyslog_max_message_size
rsyslog_config=/etc/rsyslog.d/19-messagesize.conf

if [[ -n "$rsyslog_max_message_size" ]]; then
    echo "setting rsyslog_max_message_size..."
    echo "\$MaxMessageSize ${rsyslog_max_message_size}" > $rsyslog_config
    service rsyslog restart
fi
