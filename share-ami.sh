#!/bin/bash

CONFIG_FILE=$1
CONFIG_DIR=$(dirname $CONFIG_FILE)
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
echo "Share AMI $imageid for $accounts"
echo $accounts | xargs aws ec2 modify-image-attribute --region $region --image-id $imageid --attribute launchPermission --operation-type add --user-ids
aws ec2 create-tags --region $region --resources $imageid --tags "Key=Shared,Value=Internal"

for target_region in $copy_regions; do
    target_imageid=$(aws ec2 describe-images --region $target_region --filters Name=tag-key,Values=Version Name=tag-value,Values=$TAUPAGE_VERSION --query 'Images[*].{ID:ImageId}' --output  text)
    if [ -z "$target_imageid" ]; then
        echo "Copying AMI to region $target_region ..."
        target_imageid=$(aws ec2 copy-image --source-region $region --source-image-id $imageid --region $target_region --name $ami_name --description "$ami_description" --output text)

        state="no state yet"
        while [ true ]; do
            echo "Waiting for AMI creation in $target_region ... ($state)"

            state=$(aws ec2 describe-images --region $target_region --query 'Images[0].State' --output text --image-id $target_imageid)

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
    else
        echo "Image still exist ($target_imageid). Skip copy."
        state="available"
    fi

    echo "Share AMI $target_imageid for $accounts"
    echo $accounts | xargs aws ec2 modify-image-attribute --region $target_region --image-id $target_imageid --attribute launchPermission --operation-type add --user-ids
done

#check if image creation/copy was successfull
if [ "$state" = "available" ]; then
    # git add new release tag
    git tag $ami_name
    git push --tags
    if [ -d "$CONFIG_DIR" ]; then
        cd "$CONFIG_DIR"
        git tag $ami_name
        git push --tags
        cd -
    fi

    #tag image in Frankfurt with commitID
    aws ec2 create-tags --region $region --resources $imageid --tags Key=CommitID,Value=$commit_id
else
    echo "Image creation/copy failed."
fi
