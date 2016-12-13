#!/bin/bash

CONFIG_FILE=$1
TAUPAGE_VERSION=$2

cd $(dirname $0)

# load configuration file
. $CONFIG_FILE

# get ami_id, ami_name and commitID
result=$(aws ec2 describe-images --region $region --filters Name=tag-key,Values=Version Name=tag-value,Values=$TAUPAGE_VERSION --query 'Images[0]' --output json)
imageid=$(echo $result | jq -r '.ImageId')
ami_name=$(echo $result | jq -r '.Name')
commit_id=$(git rev-parse HEAD)

#share AMI in default region
for account in $accounts; do
    echo "Sharing AMI with account $account ..."
    aws ec2 modify-image-attribute --region $region --image-id $imageid --launch-permission "Add=[{UserId=$account}]"
done
aws ec2 create-tags --region $region --resources $imageid --tags "Key=Shared,Value=Internal"

for target_region in $copy_regions; do
    echo "Copying AMI to region $target_region ..."
    result=$(aws ec2 copy-image --source-region $region --source-image-id $imageid --region $target_region --name $ami_name --description "$ami_description" --output json)
    target_imageid=$(echo $result | jq -r '.ImageId')

    state="no state yet"
    while [ true ]; do
        echo "Waiting for AMI creation in $target_region ... ($state)"

        result=$(aws ec2 describe-images --region $target_region --output json --image-id $target_imageid)
        state=$(echo $result | jq -r '.Images[0].State')

        if [ "$state" = "failed" ]; then
            echo "copying Image failed."
            exit 1
        elif [ "$state" = "available" ]; then
            break
        fi

        sleep 10
    done

    # set tags in other account
    aws ec2 create-tags --region $target_region --resources $target_imageid --tags "Key=Version,Value=$TAUPAGE_VERSION" "Key=CommitID,Value=$commit_id" "Key=Shared,Value=Internal"

    for account in $accounts; do
        echo "Sharing AMI $target_region with account $account ..."
        aws ec2 modify-image-attribute --region $target_region --image-id $target_imageid --launch-permission "Add=[{UserId=$account}]"
    done
done

#check if image creation/copy was successfull
if [ "$state" = "available" ]; then
    # git add new release tag
    git tag $ami_name
    git push --tags
    #tag image in Frankfurt with commitID
    aws ec2 create-tags --region $region --resources $imageid --tags Key=CommitID,Value=$commit_id
else
    echo "Image creation/copy failed."
fi
