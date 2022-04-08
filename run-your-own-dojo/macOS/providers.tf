terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 1.13.3"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  # config_context = var.context_name
  # load_config_file = true
  # config_path = pathexpand("~/.kube/config")
}
