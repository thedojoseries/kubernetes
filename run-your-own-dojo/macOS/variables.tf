variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
}

variable "subnet_cidrs" {
  description = "The CIDRs for the subnets."
}

variable "min_team_number" {
  description = "The lowest number to be assigned to a team"
}

variable "max_team_number" {
  description = "The highest number to be assigned to a team"
}

variable "aws_region" {
  description = "The AWS region where all resources will be deployed."
}

variable "context_name" {
  description = "The name of the K8s context"
}

variable "instance_type" {
  description = "The size of the instance."
  default     = "t2.micro"
}

variable "cluster_size" {
  description = "The size of the cluster."
  default     = 1
}

variable "keybase_username" {
  description = "A keybase username in the form of keybase:username. This will be used to encrypt the IAM User's password."
  default = "test"
}
