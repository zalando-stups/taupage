#!/bin/bash
set -euo pipefail

CONFIG_FILE=$1
CONFIG_DIR="$(dirname "$CONFIG_FILE")"
TAUPAGE_VERSION=$2
CHANNEL_PREFIX=$3

cd "$(dirname "$0")"

# load configuration file
. "$CONFIG_FILE"

publish_date="$(date +%Y%m%d-%H%M%S)"
ami_name="${CHANNEL_PREFIX}-AMI-${publish_date}"
commit_id=$(git rev-parse HEAD)

share_ami() {
    # share_ami region
    local region="$1"
    local ami_data=$(aws ec2 describe-images --region "$region" --filters "Name=name,Values=TaupageBuild-$TAUPAGE_VERSION" --query 'Images[0]' --output json)
    local imageid=$(echo "$ami_data" | jq -r '.ImageId')
    local build_date=$(echo "$ami_data" | jq -r '.Tags[] | select(.Key == "BuildDate") | .Value')
    local build_date_parsed="$(echo "$build_date" | sed -E 's/([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})/\1-\2-\3T\4:\5:\6Z/')"
    local ami_expiration="$(date -d "${build_date_parsed} + ${expire_time}" '+%Y-%m-%dT%H:%M:%SZ')"

    if [[ -z "$build_date" ]]; then
        echo "BuildDate not set, cannot copy the image" >2
        exit 1
    fi

    # create an updated AMI skeleton. most of the properties we copy from the original AMI, but
    # we need to remove 'encrypted' from the EBS volumes and update the name
    local updated_ami="$(echo "$ami_data" | jq --arg name "$ami_name" '{Description, Architecture, RootDeviceName, VirtualizationType, SriovNetSupport, EnaSupport, Name: $name, BlockDeviceMappings: .BlockDeviceMappings | map(del(.Ebs.Encrypted))}')"

    echo "Copying AMI $imageid in $region as $ami_name..."
    local target_imageid=$(aws ec2 register-image --region "$region" --cli-input-json "$updated_ami" --output text)

    # Wait until the image is available
    while true; do
        local state="$(aws ec2 describe-images --region "$region" --query 'Images[0].State' --output text --image-id "$target_imageid")"

        if [ "$state" = "failed" ]; then
            echo "Copying failed."
            exit 1
        elif [ "$state" = "available" ]; then
            echo "AMI $region/$ami_name ($target_imageid) successfully created."
            break
        else
            echo "Waiting for AMI creation in $region ... ($state)"
            sleep 10
        fi
    done

    # Update the image tags
    local tags="$(jq -n --arg build_date "$build_date" --arg version "$TAUPAGE_VERSION" --arg source_ami "$imageid" --arg commit_id "$commit_id" --arg ami_expiration "$ami_expiration" '[{Key: "BuildDate", Value: $build_date}, {Key: "SourceAMI", Value: $source_ami}, {Key: "CommitID", Value: $commit_id}, {Key: "Version", Value: $version}, {Key: "ExpirationTime", Value: $ami_expiration}]')"
    aws ec2 create-tags --region "$region" --resources "$target_imageid" --tags "$tags"

    echo "Sharing the AMI with AWS accounts: $all_accounts"

    # Share the image
    echo $all_accounts | xargs aws ec2 modify-image-attribute --region "$region" --image-id "$target_imageid" --attribute launchPermission --operation-type add --user-ids
}

for target_rgn in $copy_regions; do
    share_ami $target_rgn
done

if [[ -z "${NO_RELEASE_TAG}" ]]; then
    # git add new release tag
    git tag $ami_name
    git push --tags
    if [ -d "$CONFIG_DIR" ]; then
        cd "$CONFIG_DIR"
        git tag "$ami_name"
        git push --tags
    fi
fi
