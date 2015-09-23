#!/bin/sh

eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

enhanced_cloudwatch_metrics=$config_enhanced_cloudwatch_metrics

if [ "$enhanced_cloudwatch_metrics" = True ] ; then
  if [ ! -f /etc/cron.d/mon-put-instance-data-cloudwatch ]; then
    echo "enhanced_cloudwatch_metrics detected...enabling additional cloudwatch metrics"
    mv /etc/cron.d/mon-put-instance-data-cloudwatch.deactivated /etc/cron.d/mon-put-instance-data-cloudwatch
  fi
fi
