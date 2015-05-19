#!/bin/sh

TEST_ROLE="test-role-$AMI_ID"
TEST_PERMISSIONS="test-permissions-$AMI_ID"
INSTANCE_PROFILE="test-profile-$AMI_ID"
TEST_VOLUMES="test-volumes-$AMI_ID"

create_profile_for_volume_attachment()
{
    echo "Creating test instance profile $INSTANCE_PROFILE ..."

TRUST_POLICY="trustpolicy-$AMI_ID"
cat << EOF > "$TRUST_POLICY"
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}
EOF

PERMISSIONS_POLICY="permissionspolicy-$AMI_ID"
cat << EOF > "$PERMISSIONS_POLICY"
{
    "Version": "2012-10-17",
    "Statement": {
        "Effect": "Allow",
        "Action": [
            "ec2:DescribeVolumes",
            "ec2:AttachVolume",
            "ec2:DetachVolume"
        ],
        "Resource": "*"
    }
}
EOF

    aws iam create-role --role-name "$TEST_ROLE" \
        --assume-role-policy-document "file://$TRUST_POLICY" > /dev/null

    aws iam put-role-policy --role-name "$TEST_ROLE" \
        --policy-name "$TEST_PERMISSIONS" --policy-document "file://$PERMISSIONS_POLICY" > /dev/null

    aws iam create-instance-profile --instance-profile-name "$INSTANCE_PROFILE" > /dev/null

    aws iam add-role-to-instance-profile --instance-profile-name "$INSTANCE_PROFILE" \
        --role-name "$TEST_ROLE"

    rm -f "$TRUST_POLICY" "$PERMISSIONS_POLICY"
}

delete_profile_for_volume_attachment()
{
    echo "Deleting test instance profile $INSTANCE_PROFILE ..."
    aws iam remove-role-from-instance-profile --instance-profile-name "$INSTANCE_PROFILE" --role-name "$TEST_ROLE"
    aws iam delete-instance-profile --instance-profile-name "$INSTANCE_PROFILE"
    aws iam delete-role-policy --role-name "$TEST_ROLE" --policy-name "$TEST_PERMISSIONS"
    aws iam delete-role --role-name "$TEST_ROLE"
}

create_test_volumes()
{
    echo "Creating test EBS volumes ..."
    SUBNET_DESCRIPTION=$(aws ec2 describe-subnets --output json --region ${region} --subnet-id ${subnet})
    AVAILABILITY_ZONE=$(echo ${SUBNET_DESCRIPTION} | jq .Subnets\[0\].AvailabilityZone | sed 's/"//g')

    for i in `seq 1 4`;
    do
        result=$(aws ec2 create-volume \
            --size 2 \
            --output json \
            --region ${region} \
            --availability-zone ${AVAILABILITY_ZONE} \
            --volume-type gp2)
        volumeid=$(echo ${result} | jq .VolumeId | sed 's/"//g')
        aws ec2 create-tags --region ${region} --resources ${volumeid} --tags "Key=Name,Value=taupage-ami-test-vol$i"
        echo ${volumeid} >> "${TEST_VOLUMES}"
    done
}

delete_test_volumes()
{
    echo "Deleting test EBS volumes ..."
    for volumeid in $(cat "${TEST_VOLUMES}") ;
    do
        while [ true ]; do
            result=$(aws ec2 describe-volumes --output json --region ${region} --volume-id $volumeid --output json)
            state=$(echo $result | jq .Volumes\[0\].State | sed 's/"//g')

            if [ ! -z "$state" ] && [ "$state" = "available" ];
        then
            break
        else
                echo "Waiting for volume $volumeid to detach...";
                sleep 2;
        fi
        done
    #debug
    echo "delete ${volumeid}";
        aws ec2 delete-volume --region ${region} --volume-id ${volumeid}
    done
    rm -f "$TEST_VOLUMES"
}
