#!/bin/sh

cd $(dirname $0)

# argument parsing
if [ "$1" = "--dry-run" ]; then
    echo "Dry run requested."
    DRY_RUN=true
    shift
else
    DRY_RUN=false
fi

if [ -z "$2" ]; then
    echo "Usage:  $0 <config-file> <ami-id>" >&2
    exit 1
fi
CONFIG_FILE=$1
AMI_ID=$2

# start!
set -e

# load config
. ./$CONFIG_FILE

# load volume testing definitions
. ./volume_testing.sh

echo "Running AMI tests for $AMI_ID"

create_profile_for_volume_attachment
create_test_volumes

# get a server
echo "Starting test server..."
result=$(aws ec2 run-instances \
    --iam-instance-profile Name=${INSTANCE_PROFILE} \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type t2.micro \
    --associate-public-ip-address \
    --key-name $keypair \
    --security-group-ids $security_group \
    --subnet-id $subnet \
    --output json \
    --region $region \
    --user-data file://$(pwd)/test-userdata.yaml)

instanceid=$(echo $result | jq .Instances\[0\].InstanceId | sed 's/"//g')
echo "Instance: $instanceid"

aws ec2 create-tags --region $region --resources $instanceid --tags "Key=Name,Value=Taupage AMI Test"

while [ true ]; do
    result=$(aws ec2 describe-instances --region $region --instance-id $instanceid --output json)
    ip=$(echo $result | jq .Reservations\[0\].Instances\[0\].PublicIpAddress | sed 's/"//g')

    [ ! -z "$ip" ] && [ "$ip" != "null" ] && break

    echo "Waiting for public IP..."
    sleep 5
done

echo "IP: $ip"

# now wait until HTTP works
set +e
TEST_OK=false

max_tries=18  # ~3 minutes
while [ true ]; do
    echo "Waiting for HTTP server..."

    result=$(curl http://$ip/ 2>/dev/null)
    if [ $? -eq 0 ]; then

        TEST_OK=true
        break
    fi

    max_tries=$(($max_tries - 1))
    if [ $max_tries -lt 1 ]; then
        break
    fi

    sleep 10
done

# clean up aka terminate test server
if [ $DRY_RUN = false ]; then
    echo "Terminating server..."
    aws ec2 terminate-instances --region $region --instance-ids $instanceid > /dev/null
    delete_test_volumes
    delete_profile_for_volume_attachment
else
    echo "Skipping termination of server due to dry run. Instance profile and test volumes were also kept intact!"
fi


if [ $TEST_OK = true ]; then
    echo "TEST SUCCESS: got good response from http"
    exit 0
else
    echo "TEST FAILED: http did not come up properly"
    exit 1
fi
