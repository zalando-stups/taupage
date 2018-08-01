#!/bin/bash

TDAGENT_PID=$(ps aux | grep "td-agent" | grep -v grep | awk '{print $2}')
SCALYR_PID=$(ps aux | grep "scalyr" | grep -v grep | awk '{print $2}')

if [ ! -z "${TDAGENT_PID}" ];then
   logger "td-agent memory usage: $(pmap -X ${TDAGENT_PID} | tail -1 | awk '{print $3}')"
fi

if [ ! -z "${SCALYR_PID}" ];then
   logger "scalyr-agent-2 memory usage: $(pmap -X ${SCALYR_PID} | tail -1 | awk '{print $3}')"
fi
