#!/bin/bash
set -e

# finally cleanup ec2 instance
function finally() {
	# clean up aka terminate test server
	if [ $DRY_RUN = false ]; then
		echo "Terminating server..."
		aws ec2 terminate-instances --region $region --instance-ids $instanceid > /dev/null
		delete_test_volumes
		delete_profile_for_volume_attachment
	else
		echo "Skipping termination of server due to dry run. Instance profile and test volumes were also kept intact!"
	fi
}
trap finally EXIT


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

# wait a little for the instance-profile to settle
sleep 5

result=$(aws ec2 run-instances \
    --iam-instance-profile Name=${INSTANCE_PROFILE} \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type c3.large \
    --associate-public-ip-address \
    --key-name $keypair \
    --security-group-ids $security_group \
    --subnet-id $subnet \
    --output json \
    --region $region \
    --user-data file://$(pwd)/../test-userdata.yaml)

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


# wait for server
while [ true ]; do
    echo "Logging in with ubuntu user..."

    set +e
    ssh $ssh_args ubuntu@$ip echo >/dev/null
    alive=$?
    set -e

    if [ $alive -eq 0 ]; then
        break
    fi

    sleep 2
done

# wait for server - checking ssh-access-granting-service.pub
while [ true ]; do
    echo "Waiting for server, checking private ssh user ..."

    set +e
    ssh $secret_ssh_args $private_ssh_user@$ip echo >/dev/null
    alive=$?
    set -e

    if [ $alive -eq 0 ]; then
        break
    fi

    sleep 2
done

if [[ $OSTYPE == darwin* ]]; then
    # Disable tar'ing resource forks on Macs
    export COPYFILE_DISABLE=true
fi

echo "Uploading tests and scripts files to server..."
ssh $ssh_args ubuntu@$ip sudo mkdir -p /tmp/{tests,scripts}
tar c -C tests . | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner --no-overwrite-dir -C /tmp/tests/
tar c -C scripts . | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner --no-overwrite-dir -C /tmp/scripts/

# now wait until HTTP works
set +e
TEST_OK=false

max_tries=30  # ~3 minutes
while [ true ]; do
    echo "Waiting for HTTP server..."

    result=$(curl --fail http://$ip/ 2>/dev/null)
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


echo "### TAUPAGE.YAML DEBUG OUTPUT ###"
cat /meta/taupage.yaml

echo "### SYSLOG DEBUG OUTPUT ###"
cat /var/log/syslog

# run ServerSpec tests
ssh $ssh_args ubuntu@$ip sudo chmod +x /tmp/scripts/serverspec.sh
ssh $ssh_args ubuntu@$ip sudo /tmp/scripts/serverspec.sh

result_test=$?

if [[ $result_test != 0 ]]; then
    echo "Tests failed with error code $result_test"
    exit $result_test
fi

if [ $TEST_OK = true ]; then
    echo "TEST SUCCESS: got good response from http"
    exit 0
else
    echo "TEST FAILED: http did not come up properly"
    exit 1
fi
