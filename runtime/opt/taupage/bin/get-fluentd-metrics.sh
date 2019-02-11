#!/bin/bash

OUTFILE="/var/local/textfile_collector/fluentd_metrics.prom"

curl -s "localhost:9110/metrics" > ${OUTFILE}

if [ $? != 0 ];then
   echo "fluentd_process_running{tag=\"td-agent\",hostname=\"$(hostname)\"} 0.0" > ${OUTFILE}
else
   echo "fluentd_process_running{tag=\"td-agent\",hostname=\"$(hostname)\"} 1.0" >> ${OUTFILE}
fi
