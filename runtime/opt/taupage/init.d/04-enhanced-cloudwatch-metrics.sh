#!/bin/bash

eval $(/opt/taupage/bin/parse-yaml.py /meta/taupage.yaml "config")

enhanced_cloudwatch_metrics=$config_enhanced_cloudwatch_metrics

if [ "$enhanced_cloudwatch_metrics" = True ] ; then
  if [ ! -f /etc/cron.d/mon-put-instance-data-cloudwatch ]; then
    echo "enhanced_cloudwatch_metrics detected...enabling additional cloudwatch metrics"
    mv /etc/cron.d/mon-put-instance-data-cloudwatch.deactivated /etc/cron.d/mon-put-instance-data-cloudwatch
  fi
  if [ -f /etc/cron.d/mon-put-instance-data-cloudwatch ]; then
    if [ ! -f /root/.mon-put-instance-data-cloudwatch.lock ]; then
      for i in `df -h | grep ^/dev | awk  '{print $6}'`; do echo $i;
        sed -i " 1 s:.*:&\ --disk-path=$i:" /etc/cron.d/mon-put-instance-data-cloudwatch
        touch /root/.mon-put-instance-data-cloudwatch.lock
      done
    else
      echo "Skipping disk adding for enhanced_cloudwatch_metrics, found /root/.mon-put-instance-data-cloudwatch.lock"
    fi
  fi
fi
