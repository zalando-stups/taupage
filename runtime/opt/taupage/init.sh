#!/bin/sh

# lock task execution, only run once
mkdir /run/taupage-init-ran
if [ $? -ne 0 ]; then
    echo "ERROR: Aborting init process; init already ran."
    exit 0
fi

echo "INFO: Starting Taupage AMI init process.."
# save current timestamp,
# this timestamp is used has Taupage's boot time reference
date --utc --iso-8601=seconds | tee /run/taupage-init-ran/date
START_TIME=$(date +"%s")

# reset dir
cd $(dirname $0)

# general preparation
for script in $(ls init.d); do
    ./init.d/$script
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to start $script" >&2
        exit 1
    fi
done

# runtime execution
RUNTIME=$(grep -E "^runtime: " /etc/taupage.yaml | cut -d' ' -f 2)

if [ -z "$RUNTIME" ]; then
    echo "ERROR: No runtime configuration found!" >&2
    exit 1
fi

# make sure there are no path hacks
RUNTIME=$(basename $RUNTIME)

# figure out executable
RUNTIME_INIT=/opt/taupage/runtime/${RUNTIME}.py

if [ ! -f $RUNTIME_INIT ]; then
    echo "ERROR: Runtime '$RUNTIME' not found!" >&2
    exit 1
fi

# do magic!
$RUNTIME_INIT
result=$?

# notify cloud formation

# TODO get it more reliably
CFN_STACK=$(grep -E "^    stack:" /etc/taupage.yaml | awk '{print $2}')
CFN_RESOURCE=$(grep -E "^    resource:" /etc/taupage.yaml | awk '{print $2}')

if [ -z "$CFN_STACK" ] || [ -z "$CFN_RESOURCE" ]; then
    echo "INFO: Skipping notification of CloudFormation."
else
    EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
    EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

    echo "INFO: Notifying CloudFormation (region $EC2_REGION stack $CFN_STACK resource $CFN_RESOURCE status $result)..."

    cfn-signal -e $result --stack $CFN_STACK --resource $CFN_RESOURCE --region $EC2_REGION
fi

END_TIME=$(date +"%s")
ELAPSED_SECONDS=$(($END_TIME-$START_TIME))

if [ $result -eq 0 ]; then
    echo "SUCCESS: Initialization completed successfully in $ELAPSED_SECONDS seconds"
else
    echo "ERROR: $RUNTIME failed to start with exit code $result ($ELAPSED_SECONDS seconds elapsed)"
fi

# finished!
exit $result
