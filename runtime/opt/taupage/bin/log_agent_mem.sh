#!/bin/bash

TDAGENT_PID=$(ps aux | grep "td-agent" | grep -v grep | awk '{print $2}')
SCALYR_PID=$(ps aux | grep "scalyr" | grep -v grep | awk '{print $2}')

if [ ! -z "${TDAGENT_PID}" ];then
   PSS=$(pmap -X ${TDAGENT_PID} | tail -1 | awk '{print $3}')
   CPU=$(top -b -n 1 -p ${TDAGENT_PID} | tail -1 | awk '{print $9}')
   logger "td-agent cpu and memory usage: ${CPU} ${PSS}"
fi

if [ ! -z "${SCALYR_PID}" ];then
   PSS=$(pmap -X ${SCALYR_PID} | tail -1 | awk '{print $3}')
   CPU=$(top -b -n 1 -p ${SCALYR_PID} | tail -1 | awk '{print $9}')
   logger "scalyr-agent-2 cpu and memory usage: ${CPU} ${PSS}"
fi
