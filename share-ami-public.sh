#!/bin/bash

CONFIG_FILE=$1
TAUPAGE_VERSION=$2

cd $(dirname $0)

# load configuration file
. $CONFIG_FILE

# get ami_id, ami_name and commitID
imageid=$(aws ec2 describe-images --region $region --filters Name=tag-key,Values=Version Name=tag-value,Values=$TAUPAGE_VERSION --query 'Images[*].{ID:ImageId}' --output  text)

#share AMI in default region
for account in $all_accounts; do
    echo "Sharing AMI in $region with account $account ..."
    aws ec2 modify-image-attribute --region $region --image-id $imageid --launch-permission "Add=[{UserId=$account}]"
done
aws ec2 create-tags --region $region --resources $imageid --tags "Key=Shared,Value=Public"

#copy ami to target regions
for target_region in $copy_regions; do
    # share image in target region
    for account in $all_accounts; do
        echo "Sharing AMI in $target_region with account $account ..."
        aws ec2 modify-image-attribute --region $target_region --image-id $target_imageid --launch-permission "Add=[{UserId=$account}]"
    done
    aws ec2 create-tags --region $target_region --resources $target_imageid --tags "Key=Shared,Value=Public"
done
