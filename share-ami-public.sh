#!/bin/bash

CONFIG_FILE=$1
TAUPAGE_VERSION=$2

cd $(dirname $0)

# load configuration file
. $CONFIG_FILE


config_dir=$(dirname $1)

# accounts to share with
all_accounts=`$config_dir/get-aws-account-ids.py`

# get ami_id, ami_name and commitID
imageid=$(aws ec2 describe-images --region $region --filters Name=tag-key,Values=Version Name=tag-value,Values=$TAUPAGE_VERSION --query 'Images[*].{ID:ImageId}' --output  text)
ami_name=$(aws ec2 describe-images --region $region --filters Name=tag-key,Values=Version Name=tag-value,Values=$TAUPAGE_VERSION --query 'Images[*].{ID:Name}' --output  text)
commit_id=$(git log | head -n 1 | awk {'print $2'})

#share AMI in default region
for account in $all_accounts; do
    echo "Sharing AMI in $region with account $account ..."
    aws ec2 modify-image-attribute --region $region --image-id $imageid --launch-permission "{\"Add\":[{\"UserId\":\"$account\"}]}"
done

#copy ami to target regions
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
    done
    sleep 10

    #create image tags in target region
    aws ec2 create-tags --region $target_$region --resources $target_$imageid --tags Key=Version,Value=$TAUPAGE_VERSION
    aws ec2 create-tags --region $target_$region --resources $target_$imageid --tags Key=CommitID,Value=$commit_id

    # share image in target region
    for account in $all_accounts; do
        echo "Sharing AMI in $target_region with account $account ..."
        aws ec2 modify-image-attribute --region $target_region --image-id $target_imageid --launch-permission "{\"Add\":[{\"UserId\":\"$account\"}]}"
    done
done
