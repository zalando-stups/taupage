#!/usr/bin/env bash


# default description (may be overriden by config file)
ami_description="STUPS' Taupage AMI with Docker runtime"

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
. $CONFIG_FILE

# start creation
set -e

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
tar c -C runtime --exclude=__pycache__ . | ssh $ssh_args ubuntu@$ip sudo tar x --no-overwrite-dir -C /
echo "Uploading build/* files to server..."
tar c build | ssh $ssh_args ubuntu@$ip sudo tar x -C /tmp
echo "Uploading secret/* files to server..."
tar c -C $secret_dir . | ssh $ssh_args ubuntu@$ip sudo tar x -C /tmp/build
ssh $ssh_args ubuntu@$ip find /tmp/build

# execute setup script
echo "Executing setup script..."
ssh $ssh_args ubuntu@$ip sudo /tmp/build/setup.sh

if [ $DRY_RUN = true ]; then
    echo "Dry run requested; skipping image creation, server termination and sharing!"
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


# delete instance
echo "Terminating server..."
aws ec2 terminate-instances --region $region --instance-ids $instanceid > /dev/null

# run tests
./test.sh $CONFIG_FILE $imageid

#if test failed then dont share and copy the image to other regions
if [ $? -eq 0 ];
then

    # TODO exit if git is dirty

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

        for account in $accounts; do
        echo "Sharing AMI with account $account ..."
        aws ec2 modify-image-attribute --region $target_region --image-id $target_imageid --launch-permission "{\"Add\":[{\"UserId\":\"$account\"}]}"
        done
    done
    #git add new release tag
    git tag $ami_name 
    git push --tags 
    # get commitID
    commit_id=$(git log | head -n 1 | awk {'print $2'})
    #tag image in Frankfurt with commitID
    aws ec2 create-tags --region eu-central-1 --resources $imageid --tags Key=CommitID,Value=$commit_id    
    #tag image in Ireland with commitID
    aws ec2 create-tags --region eu-west-1 --resources $target_imageid --tags Key=CommitID,Value=$commit_id    

    # finished!
    echo "AMI $ami_name ($imageid) successfully created and shared."

    # HipChat notification
    if [ "$hipchat_notification_enabled" = true ]; then
        echo "Sending HipChat notification..."
        curl -s -S -X POST -H "Content-Type: application/json" -d "{\"message\":\"$hipchat_message\"}" "https://${hipchat_server_address}/v2/room/${hipchat_room_id}/notification?auth_token=${hipchat_auth_token}"
    fi

else

    echo "AMI $ami_name ($imageid) create failed "

fi
