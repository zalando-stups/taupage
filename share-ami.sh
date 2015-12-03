#!/bin/bash

# share ami
if [[ condition ]]; then
    echo "skipping AMI sharing as DISABLE_AMI_SHARING set to TRUE"
else
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
fi
