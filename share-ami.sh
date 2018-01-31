#!/bin/bash
set -euo pipefail

CONFIG_FILE=$1
CONFIG_DIR="$(dirname "$CONFIG_FILE")"
TAUPAGE_VERSION=$2
CHANNEL=$3

cd "$(dirname "$0")"

# load configuration file
. "$CONFIG_FILE"

# get ami_id, ami_name and commitID
result=$(aws ec2 describe-images --region "$region" --filters "Name=name,Values=TaupageBuild-$TAUPAGE_VERSION" --query 'Images[0]' --output json)
imageid=$(echo "$result" | jq -r '.ImageId')
build_date=$(echo "$result" | jq -r '.Tags[] | select(.Key == "BuildDate") | .Value')
if [[ -z "$build_date" ]]; then
    echo "BuildDate not set, cannot copy the image" >2
    exit 1
fi
publish_date="$(date +%Y%m%d-%H%M%S)"
ami_name="Taupage${CHANNEL}-AMI-${publish_date}"
commit_id=$(git rev-parse HEAD)

share_ami() {
    # share_ami region
    local target_region="$1"

    # Create a copy of the AMI with the correct name (Taupage$CHANNEL-$DATE)
    echo "Copying AMI $imageid to $target_region as $ami_name..."
    local target_imageid=$(aws ec2 copy-image --source-region "$region" --source-image-id "$imageid" --region "$target_region" --name "$ami_name" --description "$ami_description" --output text)

    # Wait until the image is available
    while true; do
        local state="$(aws ec2 describe-images --region "$target_region" --query 'Images[0].State' --output text --image-id "$target_imageid")"

        if [ "$state" = "failed" ]; then
            echo "Copying failed."
            exit 1
        elif [ "$state" = "available" ]; then
            break
        else
            echo "Waiting for AMI creation in $target_region ... ($state)"
            sleep 10
        fi
    done

    # Update the image tags
    local tags="$(jq -n --arg build_date "$build_date" --arg version "$TAUPAGE_VERSION" --arg source_ami "$imageid" --arg commit_id "$commit_id" '[{Key: "BuildDate", Value: $build_date}, {Key: "SourceAMI", Value: $source_ami}, {Key: "CommitID", Value: $commit_id}, {Key: "Version", Value: $version}]')"
    aws ec2 create-tags --region "$target_region" --resources "$target_imageid" --tags "$tags"

    # Share the image
    echo $all_accounts | xargs aws ec2 modify-image-attribute --region "$target_region" --image-id "$target_imageid" --attribute launchPermission --operation-type add --user-ids
}

for target_rgn in $copy_regions; do
    share_ami $target_rgn
done

# git add new release tag
git tag $ami_name
git push --tags
if [ -d "$CONFIG_DIR" ]; then
    cd "$CONFIG_DIR"
    git tag "$ami_name"
    git push --tags
fi
