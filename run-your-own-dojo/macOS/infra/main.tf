data "aws_caller_identity" "current" {}

#############
# IAM Users #
#############

resource "aws_iam_user" "team_user" {
  count = var.max_team_number - var.min_team_number + 1
  name  = "team${var.min_team_number + count.index}"
  path  = "/"

  tags = {
    TeamName = "team${count.index + var.min_team_number}"
    Name     = "team${var.min_team_number + count.index}"
    Event    = "Kubernetes"
  }
}

resource "aws_iam_access_key" "access_keys" {
  count   = var.max_team_number - var.min_team_number + 1
  user    = aws_iam_user.team_user[count.index].name
  pgp_key = "keybase:thedojoseries"
}

resource "aws_iam_policy" "user_policy" {
  count       = var.max_team_number - var.min_team_number + 1
  name        = "k8s-ctf-user-policy-team${count.index + var.min_team_number}"
  description = "The Policy to be assigned to the Kubernetes users"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "cloudshell:CreateEnvironment",
        "cloudshell:CreateSession",
        "cloudshell:GetFileDownloadUrls"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "ecr:PutImage",
        "ecr:*Upload*",
        "ecr:BatchCheckLayerAvailability"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/team${count.index + var.min_team_number}*"
    },
    {
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Action": [
        "eks:DescribeCluster"
      ],
      "Effect": "Allow",
      "Resource": "${aws_eks_cluster.cluster.arn}"
    },
    {
      "Action": [
        "cloud9:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_user_policy_attachment" "user_policy_attachment" {
  count      = var.max_team_number - var.min_team_number + 1
  user       = aws_iam_user.team_user[count.index].name
  policy_arn = aws_iam_policy.user_policy[count.index].arn
}

resource "aws_iam_user_login_profile" "user_login_profile" {
  count                   = var.max_team_number - var.min_team_number + 1
  pgp_key                 = var.keybase_username
  user                    = aws_iam_user.team_user[count.index].name
  password_length         = 15
  password_reset_required = false
}

###########
# Network #
###########

resource "aws_vpc" "default" {
  cidr_block       = var.vpc_cidr_block
  instance_tenancy = "default"

  tags = {
    Name = "Kubernetes"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name  = "Kubernetes VPC"
    Event = "Kubernetes"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.subnet_cidrs)
  vpc_id                  = aws_vpc.default.id
  cidr_block              = var.subnet_cidrs[count.index]
  availability_zone       = "${var.aws_region}${var.azs[count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "Public - ${count.index + 1}"
    Event                                       = "Kubernetes"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name  = "Public Route Table"
    Event = "Kubernetes"
  }
}

resource "aws_route" "route" {
  route_table_id         = aws_route_table.route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
  depends_on             = [aws_route_table.route_table]
}

resource "aws_route_table_association" "rt_subnet_assoc" {
  count          = length(var.subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.route_table.id
}

#########
# E K S #
#########

resource "aws_kms_key" "kms_key" {}

resource "aws_kms_alias" "kms_key_alias" {
  name          = "alias/kubernetes-ctf-kms-key"
  target_key_id = aws_kms_key.kms_key.key_id
}

resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids             = aws_subnet.public.*.id
    public_access_cidrs    = ["0.0.0.0/0"]
    endpoint_public_access = true
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.kms_key.arn
    }
    resources = ["secrets"]
  }

  tags = {
    Name  = "kubernetes-ctf-cluster"
    Event = "Kubernetes"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_ec2_container_reg_policy_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.public[*].id
  ami_type        = "AL2_x86_64"
  capacity_type   = "ON_DEMAND"
  disk_size       = 20
  instance_types  = [var.instance_type]

  scaling_config {
    desired_size = var.cluster_size
    max_size     = var.cluster_size
    min_size     = var.cluster_size
  }

  tags = {
    Name  = "eks-node-group"
    Event = "Kubernetes"
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy_attach,
    aws_iam_role_policy_attachment.eks_cni_policy_attach,
    aws_iam_role_policy_attachment.eks_ec2_container_reg_policy_attach,
  ]
}

resource "local_file" "kubeconfig" {
  filename = pathexpand("~/.kube/config")
  content  = <<-EOT
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.cluster.endpoint}
    certificate-authority-data: ${aws_eks_cluster.cluster.certificate_authority[0].data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: ${var.context_name}
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws
      args:
        - "eks"
        - "get-token"
        - "--cluster-name"
        - "${aws_eks_cluster.cluster.id}" 
EOT
}

#########
# E C R #
#########

resource "aws_ecr_repository" "frontend" {
  count                = var.max_team_number - var.min_team_number + 1
  name                 = "team${count.index + var.min_team_number}-frontend"
  image_tag_mutability = "MUTABLE"

  tags = {
    TeamName = "team${count.index + var.min_team_number}"
    Name     = "team${count.index + var.min_team_number}-frontend"
    Event    = "Kubernetes"
  }
}

resource "aws_ecr_repository" "auth_api" {
  count                = var.max_team_number - var.min_team_number + 1
  name                 = "team${count.index + var.min_team_number}-auth-api"
  image_tag_mutability = "MUTABLE"

  tags = {
    TeamName = "team${count.index + var.min_team_number}"
    Name     = "team${count.index + var.min_team_number}-auth-api"
    Event    = "Kubernetes"
  }
}

resource "aws_ecr_repository" "todos_api" {
  count                = var.max_team_number - var.min_team_number + 1
  name                 = "team${count.index + var.min_team_number}-todos-api"
  image_tag_mutability = "MUTABLE"

  tags = {
    TeamName = "team${count.index + var.min_team_number}"
    Name     = "team${count.index + var.min_team_number}-todos-api"
    Event    = "Kubernetes"
  }
}

resource "aws_ecr_repository" "users_api" {
  count                = var.max_team_number - var.min_team_number + 1
  name                 = "team${count.index + var.min_team_number}-users-api"
  image_tag_mutability = "MUTABLE"

  tags = {
    TeamName = "team${count.index + var.min_team_number}"
    Name     = "team${count.index + var.min_team_number}-users-api"
    Event    = "Kubernetes"
  }
}

resource "aws_ecr_repository" "log_message_processor" {
  count                = var.max_team_number - var.min_team_number + 1
  name                 = "team${count.index + var.min_team_number}-log-message-processor"
  image_tag_mutability = "MUTABLE"

  tags = {
    TeamName = "team${count.index + var.min_team_number}"
    Name     = "team${count.index + var.min_team_number}-log-message-processor"
    Event    = "Kubernetes"
  }
}

##########
# Cloud9 #
##########

resource "aws_cloud9_environment_ec2" "cloud9" {
  count         = var.max_team_number - var.min_team_number + 1
  instance_type = "t3.medium"
  name          = "team${count.index + var.min_team_number}-environment"
  owner_arn     = aws_iam_user.team_user[count.index].arn
  subnet_id     = aws_subnet.public[0].id

  depends_on = [
    aws_iam_user.team_user
  ]
}

###########
# Outputs #
###########

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "passwords" {
  value = aws_iam_user_login_profile.user_login_profile.*.encrypted_password
}

output "access_key_ids" {
  value = aws_iam_access_key.access_keys[*].id
}

output "secret_access_keys" {
  value = aws_iam_access_key.access_keys[*].encrypted_secret
}
