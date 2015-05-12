# ssh keypair for installation
#TODO generate on the fly and clean up later
keypair="jdoe"

# region
region="eu-central-1"

# base AMI (Ubuntu 14.04 LTS)
base_ami="ami-accff2b1"

instance_type="t2.small"

config_dir=$(dirname $1)
secret_dir="$config_dir/secret"

# accounts to share with
accounts="
123456789
123456788
"

copy_regions="
eu-west-1
"

# security group with SSH and HTTP open
security_group="sg-123456"

# subnet to use:
subnet="subnet-123456"
