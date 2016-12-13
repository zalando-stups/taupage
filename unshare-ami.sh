#!/bin/bash

CONFIG_FILE=$1
TAUPAGE_VERSION=$2

cd $(dirname $0)

# load configuration file
. $CONFIG_FILE

# get ami_id
imageid=$(aws ec2 describe-images --region $region --filters Name=tag-key,Values=Version Name=tag-value,Values=$TAUPAGE_VERSION --query 'Images[*].{ID:ImageId}' --output  text)
shared_accounts=$(aws ec2 describe-image-attribute --region $region --image-id $imageid --attribute launchPermission --query 'LaunchPermissions[]' --output text)

# unshare AMI in default region
echo "Share AMI $imageid for $shared_accounts"
echo $shared_accounts | xargs aws ec2 modify-image-attribute --region $region --image-id $imageid --attribute launchPermission --operation-type remove --user-ids
aws ec2 create-tags --region $region --resources $imageid --tags "Key=Shared,Value=None"

# target regions
for target_region in $copy_regions; do
    # get ami_id
    target_imageid=$(aws ec2 describe-images --region $target_region --filters Name=tag-key,Values=Version Name=tag-value,Values=$TAUPAGE_VERSION --query 'Images[*].{ID:ImageId}' --output  text)
    shared_accounts=$(aws ec2 describe-image-attribute --region $target_region --image-id $target_imageid --attribute launchPermission --query 'LaunchPermissions[]' --output text)
    echo "Share AMI $target_imageid for $shared_accounts"
    echo $shared_accounts | xargs aws ec2 modify-image-attribute --region $target_region --image-id $target_imageid --attribute launchPermission --operation-type remove --user-ids
    aws ec2 create-tags --region $target_region --resources $target_imageid --tags "Key=Shared,Value=None"
done
