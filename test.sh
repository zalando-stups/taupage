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
		if [ -n "$mint_bucket" ]; then
			taupageyamlfile="$(pwd)/test-userdata.yaml"
			echo "change mint-bucket to a example again"
			sed -i "1,$ s/mint_bucket.*$/mint_bucket:\ S3-MINT-BUCKET/" $taupageyamlfile
		fi

	else
		echo "Skipping termination of server due to dry run. Instance profile and test volumes were also kept intact!"
	fi
    #aws ec2 terminate-instances --region $region --instance-ids $instanceid > /dev/null
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
    echo "Usage:  $0 <config-file> <taupage-version> " >&2
    exit 1
fi

CONFIG_FILE=$1
TAUPAGE_VERSION=$2

# start!
set -e

# load config
. $CONFIG_FILE

# load volume testing definitions
. volume_testing.sh

# this is set in the config-stups.sh file
if [ -n "$mint_bucket" ]; then
	taupageyamlfile="$(pwd)/test-userdata.yaml"
	sed -i "1,$ s/mint_bucket.*$/mint_bucket:\ $MINT_BUCKET/" $taupageyamlfile
fi

AMI_ID=$(aws ec2 describe-images --region $region --filters Name=tag-key,Values=Version Name=tag-value,Values=$TAUPAGE_VERSION --query 'Images[*].{ID:ImageId}' --output  text)

echo "Running AMI tests for $AMI_ID"

create_profile_for_volume_attachment
create_test_volumes
sleep 10

# get a server
echo "Starting test server..."
result=$(aws ec2 run-instances \
    --iam-instance-profile Name=${INSTANCE_PROFILE} \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $instance_type \
    --associate-public-ip-address \
    --key-name $keypair \
    --security-group-ids $security_group \
    --subnet-id $subnet \
    --output json \
    --region $region \
    --user-data file://$(pwd)/test-userdata.yaml)

instanceid=$(echo $result | jq .Instances\[0\].InstanceId | sed 's/"//g')
echo "Instance: $instanceid"

aws ec2 create-tags --region $region --resources $instanceid --tags "Key=Name,Value=Taupage AMI Test, Key=Version,Value=$TAUPAGE_VERSION"

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
    echo "Waiting for server..."

    set +e
    ssh $ssh_args ubuntu@$ip echo >/dev/null
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

# run ServerSpec tests
ssh $ssh_args ubuntu@$ip sudo chmod +x /tmp/scripts/serverspec.sh
ssh $ssh_args ubuntu@$ip sudo /tmp/scripts/serverspec.sh

# now wait until HTTP works
set +e
AVAILABILITY_TEST_OK=false

max_tries=30  # ~3 minutes
while [ true ]; do
    echo "Waiting for HTTP server..."

    result=$(curl --fail http://$ip/ 2>/dev/null)
    if [ $? -eq 0 ]; then

        AVAILABILITY_TEST_OK=true
        break
    fi

    max_tries=$(($max_tries - 1))
    if [ $max_tries -lt 1 ]; then
        break
    fi

    sleep 10
done

if [ $AVAILABILITY_TEST_OK = true ]; then
    echo "TEST SUCCESS: got good response from http"
    while [ true ]; do
        echo "Testing docker..."

        result=$(curl -s -o /dev/null -w "%{http_code}" http://$ip/)
        if [ $result = 200 ]; then
            echo "DOCKER TEST SUCCESS: docker seems to work"
            break
        fi
        if [ $result = 404 ]; then
            echo "DOCKER TEST FAILED: docker does not seem to work properly"
            exit 1
        fi
        max_tries=$(($max_tries - 1))
        if [ $max_tries -lt 1 ]; then
            break
        fi

        sleep 10
    done
    exit 0
else
    echo "TEST FAILED: http did not come up properly"
    exit 1
fi
