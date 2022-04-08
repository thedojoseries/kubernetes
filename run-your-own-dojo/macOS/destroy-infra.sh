#!/bin/bash

echo -n "Enter name of the AWS profile configured in your machine (e.g. default): " && read aws_profile
export AWS_PROFILE=$aws_profile

echo Running as: `aws sts get-caller-identity | jq -r .Arn`
echo "Starting in 10 secs..."

# This is to give you enough time to stop the script in case you're using the wrong profile
sleep 10

echo "Destroying the Ingress Controller..."
echo
kubectl delete -f k8s/components/ingress-controller.yaml

# The Network Load Balancer is created by Kubernetes and NOT Terraform.
# If you destroy the infrastructure using Terraform before deleting the Load Balancer,
# you will run into issues where the Load Balancer is using an ENI and Terraform is not able to delete 
# the subnets/VPC
echo "Sleeping for a minute so the Network Load Balancer is destroyed before destroying the AWS resources..."
echo
sleep 60

terraform apply -destroy -auto-approve -target module.eks_cluster
