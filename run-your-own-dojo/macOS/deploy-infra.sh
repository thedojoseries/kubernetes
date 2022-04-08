#!/bin/bash

if ! command -v terraform &> /dev/null; then
    echo "terraform not installed. Install terraform v1.0+ before proceeding. Exiting..."
    exit
fi

if ! command -v aws &> /dev/null; then
    echo "aws not installed. Install the AWS CLI before proceeding. Exiting..."
    exit
fi

echo -n "Enter minimum team number (e.g. 1): " && read min
echo -n "Enter maximum team number (e.g. 10): " && read max
echo -n "Enter the number of nodes for the cluster: " && read cluster_size
echo -n "Enter the instance type for the nodes (e.g. t2.micro): " && read instance_type
echo -n "Enter name of the AWS profile configured in your machine (e.g. default): " && read aws_profile
echo -n "Enter your keybase username in the form keybase:username (e.g. keybase:thedojoseries): " && read keybase_username

export AWS_PROFILE=$aws_profile

echo
echo "Running as: $(aws sts get-caller-identity | jq -r .Arn). Make sure this is the right profile!"
echo "Starting in 10 secs..."
echo

# This is to give you enough time to stop the script in case you're using the wrong profile
sleep 10

rm -rf .terraform
terraform init

# Deploys the cluster and Cloud9 environments
# The command below will also configure your ~/.kube/config
terraform apply \
    -var min_team_number=$min \
    -var max_team_number=$max \
    -var cluster_size=$cluster_size \
    -var instance_type=$instance_type \
    -var keybase_username=$keybase_username \
    -target module.eks_cluster
echo

# Waiting a few seconds before configuring the cluster
echo "Sleeping for 15 secs..."
sleep 15

terraform apply \
    -var min_team_number=$min \
    -var max_team_number=$max \
    -var cluster_size=$cluster_size \
    -var instance_type=$instance_type \
    -target module.k8s_components \
    -auto-approve

# Deploys Ingress Controller (i.e. Nginx)
kubectl apply -f k8s/components/ingress-controller.yaml

# Deploys Calico (for the Network Policies section)
kubectl apply -f k8s/components/calico.yaml
echo

account_id=`aws sts get-caller-identity | jq -r .Account`
sed -i '' "s/ACCOUNT_ID/$account_id/g" aws-auth-patch.yaml

kubectl patch configmap aws-auth --patch-file aws-auth-patch.yaml -n kube-system
echo

# Increase Cloud9 Instance's volume. If you use the default volume size (10GB), you might run
# out of disk space while building the Docker images. I'd suggest increasing to 20 or 30GB.
# Change the size of the volume using the variable below.
volume_size_gb=30

for i in `seq $min $max`; do
    instance_id=`aws cloudformation describe-stack-resources --stack-name $(aws cloudformation describe-stacks | jq -r ".Stacks[] | select(.StackName | contains(\"aws-cloud9-team$i-\")) | .StackName") | jq -r '.StackResources[] | select(.ResourceType == "AWS::EC2::Instance") | .PhysicalResourceId'`
    volume_id=`aws ec2 describe-instances --instance-ids $instance_id | jq -r ".Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId"`

    aws ec2 modify-volume --size $volume_size_gb --volume-id $volume_id
done

# Wait for the volumes to be increased
sleep_time=300
echo "Sleeping for $sleep_time seconds before rebooting all Cloud9 instances..."
sleep $sleep_time

# Reboot all Cloud9 instances to make sure the filesystem recognizes the new volume size
for i in `seq $min $max`; do
    instance_id=`aws cloudformation describe-stack-resources --stack-name $(aws cloudformation describe-stacks | jq -r ".Stacks[] | select(.StackName | contains(\"aws-cloud9-team$i-\")) | .StackName") | jq -r '.StackResources[] | select(.ResourceType == "AWS::EC2::Instance") | .PhysicalResourceId'`
    aws ec2 reboot-instances --instance-ids $instance_id
done

new_max=`expr $max - $min`

# Print information about all the teams (i.e. AWS username, password, access key ID and secret access key)
for i in `seq 0 $new_max`; do
    team=`expr $i + $min`
    echo "***** TEAM $team *****"
    echo Username: team$team
    echo Password: `terraform output -json passwords | jq -r ".[$i]" | base64 -D | keybase pgp decrypt | sed 's/;$//'`
    echo Access Key ID: `terraform output -json access_key_ids | jq -r ".[$i]"`
    echo Secret Access Key: `terraform output -json secret_access_keys | jq -r ".[$i]" | base64 -D | keybase pgp decrypt | sed 's/;$//'`
    echo "******************"
    echo
done

sed -i '' "s/$account_id/ACCOUNT_ID/g" aws-auth-patch.yaml
