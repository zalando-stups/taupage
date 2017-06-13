#!/bin/bash

EXITCODE=${EXITCODE:-0}
WAITTIME=${WAITTIME:-20}

while [ "$WAITTIME" -gt 0 ]; do
  echo "waiting... ${WAITTIME}"
  WAITTIME=$((--WAITTIME))
  sleep 1
done

exit $EXITCODE
