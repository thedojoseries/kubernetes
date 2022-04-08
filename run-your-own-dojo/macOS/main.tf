module "eks_cluster" {
  source           = "./infra"
  vpc_cidr_block   = var.vpc_cidr_block
  subnet_cidrs     = var.subnet_cidrs
  min_team_number  = var.min_team_number
  max_team_number  = var.max_team_number
  context_name     = var.context_name
  aws_region       = var.aws_region
  cluster_size     = var.cluster_size
  instance_type    = var.instance_type
  keybase_username = var.keybase_username
}

module "k8s_components" {
  source          = "./k8s"
  min_team_number = var.min_team_number
  max_team_number = var.max_team_number
  account_id      = module.eks_cluster.account_id
}

output "passwords" {
  value = module.eks_cluster.passwords
}

output "access_key_ids" {
  value = module.eks_cluster.access_key_ids
}

output "secret_access_keys" {
  value = module.eks_cluster.secret_access_keys
}