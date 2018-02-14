#!/usr/bin/env bash
set -e

# finally terminate ec2 instance
function finally() {

    if [ $DRY_RUN = true ]; then
       echo "Dry run requested; skipping server termination"
    else
       # delete instance
       echo "Terminating server..."
       aws ec2 terminate-instances --region $region --instance-ids $instanceid > /dev/null
    fi
}
trap finally EXIT

# argument parsing
if [ "$1" = "--dry-run" ]; then
    echo "Dry run requested."
    DRY_RUN=true
    shift
else
    DRY_RUN=false
fi

if [ -z "$1" ] || [ ! -r "$1" ] || [ -z "$2" ]; then
    echo "Usage:  $0 [--dry-run] <config-file> <taupage-version>" >&2
    exit 1
fi
CONFIG_FILE=$1
TAUPAGE_VERSION=$2

# load configuration file
. $CONFIG_FILE

# start creation
set -e

# reset path
#cd $(dirname $0)

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

instanceid=$(echo $result | jq -r .Instances\[0\].InstanceId)
echo "Instance: $instanceid"

aws ec2 create-tags --region $region --resources $instanceid --tags "Key=Name,Value=Taupage AMI Builder, Key=Version,Value=$TAUPAGE_VERSION"

while [ true ]; do
    result=$(aws ec2 describe-instances --region $region --instance-id $instanceid --output json)
    ip=$(echo $result | jq -r .Reservations\[0\].Instances\[0\].PublicIpAddress)

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
tar c -C $(dirname $0)/runtime --exclude=__pycache__ . | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner --no-overwrite-dir -C /

echo "Set link to old taupage file"
ssh $ssh_args ubuntu@$ip sudo ln -s /meta/taupage.yaml /etc/taupage.yaml

echo "Uploading build/* files to server..."
tar c -C $(dirname $0) build  | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner -C /tmp

echo "Uploading secret/* files to server..."
tar c -C $secret_dir . | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner -C /tmp/build

if [ ! -z "$proprietary_dir" ]; then
    echo "Uploading proprietary/* files to server..."
    ssh $ssh_args ubuntu@$ip sudo mkdir /opt/proprietary
    tar c -C $proprietary_dir . | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner -C /opt/proprietary
fi

if [ ! -z "$overlay_dir" ]; then
    echo "Uploading overlaying files to server..."
    tar c -C $overlay_dir --exclude=__pycache__ . | ssh $ssh_args ubuntu@$ip sudo tar x --no-same-owner --no-overwrite-dir -C /
fi

ssh $ssh_args ubuntu@$ip find /tmp/build

# execute setup script
echo "Executing setup script..."
set +e
ssh $ssh_args ubuntu@$ip sudo /tmp/build/setup.sh
build_status=$?
set -e

if [ $build_status -ne 0 ]; then
    echo "Build failed"
    exit 1
fi

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

echo "Stopping instance to enable ENA support"
aws ec2 stop-instances --region $region --instance-ids $instanceid

while [[ $(aws ec2 describe-instances --region $region --instance-id $instanceid --output json | jq -r '.Reservations[].Instances[].State.Name') != "stopped" ]]; do
    echo "Waiting for Instance.State == 'stopped'"
    sleep 5
done

echo "Setting EnaSupport flag"
aws ec2 modify-instance-attribute --region $region --instance-id $instanceid --ena-support

# create ami
build_date="$(date +%Y%m%d-%H%M%S)"
ami_name="TaupageBuild-${TAUPAGE_VERSION}"
echo "Creating $ami_name ..."
result=$(aws ec2 create-image \
    --region $region \
    --instance-id $instanceid \
    --output json \
    --name $ami_name \
    --description "$ami_description")

imageid=$(echo $result | jq -r .ImageId)
echo "Image: $imageid"

function wait_for_ami() {
    local region="$1"
    local imageid="$2"

    while true; do
        local state=$(aws ec2 describe-images --region $region --output json --image-id $imageid | jq -r .Images\[0\].State)
        echo "Waiting for AMI creation... ($state)"


        if [ "$state" = "failed" ]; then
            echo "Image creation failed."
            exit 1
        elif [ "$state" = "available" ]; then
            echo "AMI $region/$ami_name ($imageid) successfully created."
            # set AMI tags
            image_tags="$(jq -n --arg version "$TAUPAGE_VERSION" --arg build_date "$build_date" '[{Key: "Version", Value: $version}, {Key: "BuildDate", Value: $build_date}]')"
            aws ec2 create-tags --region $region --resources $imageid --tags "$image_tags"
            return
        fi

        sleep 10
    done
}

wait_for_ami "$region" "$imageid"

# copy to other regions
for target_region in $copy_regions; do
    if [[ "$target_region" != "$region" ]]; then
        target_imageid="$(aws ec2 copy-image --source-region "$region" --source-image-id "$imageid" --region "$target_region" --name "$ami_name" --description "$ami_description" --output text)"
        wait_for_ami "$target_region" "$target_imageid"
    fi
done
