#!/usr/bin/env bash
set -x

function wait_until_instance_properly_terminated {
    local INSTANCE_ID REGION STATE RESULT_JSON
    INSTANCE_ID=$1
    REGION=$2
    while [ true ]; do
        RESULT_JSON=$(aws ec2 describe-instances --instance-id i-78ebd8f3 --region $REGION 2>/dev/null)
        EXITCODE_AWS=$?
        if [[ $EXITCODE_AWS -ne 0 ]]; then
            # No such id or other error, exit
            return
        fi
        STATE=$(echo $RESULT_JSON|jq -r '.Reservations[0].Instances[0].State.Name')
        if [[ $STATE = 'terminated' ]]; then
            return
        fi
        # Wait a bit with retrying
        sleep 5
    done
}

# finally terminate ec2 instance
function finally {

    if [ $DRY_RUN = true ]; then
        echo "Dry run requested; skipping server termination"
    else
        # delete instance
        echo "Terminating server..."
        aws ec2 terminate-instances --region $region --instance-ids $instanceid > /dev/null
        # Cleanup files
        rm -f ssh_config $keyfile
        wait_until_instance_properly_terminated $instanceid $region
    fi
}
trap finally EXIT TERM SEGV ABRT QUIT INT


# default description (may be overriden by config file)
ami_description="TEST Taupage AMI with Docker runtime"

# argument parsing
if [ "$1" = "--dry-run" ]; then
    echo "Dry run requested."
    DRY_RUN=true
    shift
else
    DRY_RUN=false
fi

if [ -z "$1" ] || [ ! -r "$1" ]; then
    echo "Usage:  $0 [--dry-run] <config-file>" >&2
    exit 1
fi
CONFIG_FILE=./$1

# load configuration file
source $CONFIG_FILE

# reset path
cd $(dirname $0)

if [ ! -f "$secret_dir/secret-vars.sh" ]; then
    echo "Missing secret-vars.sh in secret dir" >&2
    exit 1
fi


# create server
echo "Starting a base server..."
result=$(aws ec2 run-instances \
    --image-id $base_ami \
    --count 1 \
    --associate-public-ip-address \
    --instance-type $instance_type \
    --key-name $keypair \
    --security-group-ids $security_group \
    --output json \
    --region $region \
    --subnet-id $subnet)

instanceid=$(echo $result | jq .Instances\[0\].InstanceId | sed 's/"//g')
echo "Instance: $instanceid"

aws ec2 create-tags --region $region --resources $instanceid --tags "Key=Name,Value=Taupage AMI Builder"

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

# upload files
echo "Uploading runtime/* files to server..."
tar c -C runtime --exclude=__pycache__ . | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner --no-overwrite-dir -C /

echo "Set link to old taupage file"
ssh $ssh_args ubuntu@$ip sudo ln -s /meta/taupage.yaml /etc/taupage.yaml

echo "Uploading build/* files to server..."
tar c build | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner -C /tmp

echo "Uploading secret/* files to server..."
tar c -C $secret_dir . | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner -C /tmp/build

if [ ! -z "$proprietary_dir" ]; then
    echo "Uploading proprietary/* files to server..."
    ssh $ssh_args ubuntu@$ip sudo mkdir /opt/proprietary
    tar c -C $proprietary_dir . | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner -C /opt/proprietary
fi

ssh $ssh_args ubuntu@$ip find /tmp/build

# execute setup script
echo "Executing setup script..."
ssh $ssh_args ubuntu@$ip sudo /tmp/build/setup.sh

if [ $DRY_RUN = true ]; then
    echo "Dry run requested; skipping image creation and sharing!"
    exit 0
fi

# cleanup build scripts
echo "Cleaning up build files from server..."
ssh $ssh_args ubuntu@$ip sudo rm -rf /tmp/build

# remove ubuntu user
# echo "Removing ubuntu user from system..."
# ssh $ssh_args ubuntu@$ip sudo /tmp/delete-ubuntu-user-wrapper.sh
# echo "Giving deluser some time..."
# sleep 15

# create ami
ami_name="Taupage${ami_suffix}-AMI-$(date +%Y%m%d-%H%M%S)"
echo "Creating $ami_name ..."
result=$(aws ec2 create-image \
    --region $region \
    --instance-id $instanceid \
    --output json \
    --name $ami_name \
    --description "$ami_description")

imageid=$(echo $result | jq .ImageId | sed 's/"//g')
echo "Image: $imageid"

state="no state yet"
while [ true ]; do
    echo "Waiting for AMI creation... ($state)"

    result=$(aws ec2 describe-images --region $region --output json --image-id $imageid)
    state=$(echo $result | jq .Images\[0\].State | sed 's/"//g')

    if [ "$state" = "failed" ]; then
        echo "Image creation failed."
        exit 1
    elif [ "$state" = "available" ]; then
        break
    fi

    sleep 10
done

# run tests
./test.sh $CONFIG_FILE $imageid
# Early exit if tests failed
EXITCODE_TESTS=$?
if [ $EXITCODE_TESTS -ne 0 ]; then
    echo "!!! AMI $ami_name ($imageid) create failed "
    exit $EXITCODE_TESTS
fi


# TODO exit if git is dirty
rm -f ./list_of_new_amis
echo "$region,$imageid" >> ./list_of_new_amis
echo "Attaching launch permission to accounts: $accounts"

# get commitID
commit_id=$( git rev-parse HEAD )
# Tag AMI with commit id
aws ec2 create-tags --region $region --resources $imageid --tags Key=CommitID,Value=$commit_id

# share ami
for account in $accounts; do
    echo "Sharing AMI with account $account ..."
    aws ec2 modify-image-attribute --region $region --image-id $imageid --launch-permission "{\"Add\":[{\"UserId\":\"$account\"}]}"
done

for target_region in $copy_regions; do
    echo "Copying AMI to region $target_region ..."
    result=$(aws ec2 copy-image --source-region $region --source-image-id $imageid --region $target_region --name $ami_name --description "$ami_description" --output json)
    target_imageid=$(echo $result | jq .ImageId | sed 's/"//g')
    state="no state yet"
    while [ true ]; do
        echo "Waiting for AMI creation in $target_region ... ($state)"

        result=$(aws ec2 describe-images --region $target_region --output json --image-id $target_imageid)
        state=$(echo $result | jq .Images\[0\].State | sed 's/"//g')

        if [ "$state" = "failed" ]; then
            echo "Image creation failed."
            exit 1
        elif [ "$state" = "available" ]; then
            break
        fi

        sleep 10
    done
    # Tag the copied AMI in the target region
    aws ec2 create-tags --region $target_region --resources $target_imageid --tags Key=CommitID,Value=$commit_id

    for account in $accounts; do
        echo "Sharing AMI with account $account ..."
        aws ec2 modify-image-attribute --region $target_region --image-id $target_imageid --launch-permission "{\"Add\":[{\"UserId\":\"$account\"}]}"

        #write ami and region to file for later parsing
    done
    echo "$target_region,$target_imageid" >> ./list_of_new_amis
done
#git add new release tag
# git tag $ami_name
# git push --tags

# finished!
echo "AMI $ami_name ($imageid) successfully created and shared."

# HipChat notification
if [ "$hipchat_notification_enabled" = 'true' ]; then
    echo "Sending HipChat notification..."
    curl -s -S -X POST -H "Content-Type: application/json" -d "{\"message\":\"$hipchat_message\"}" "https://${hipchat_server_address}/v2/room/${hipchat_room_id}/notification?auth_token=${hipchat_auth_token}"
fi
