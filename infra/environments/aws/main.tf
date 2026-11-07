# OpenTofu Root: AWS Ephemeral EKS (Spot NodeGroup + Cost Safety Guardrails)

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project   = "enterprise-ha-platform"
        ManagedBy = "OpenTofu"
      },
      var.tags
    )
  }
}

# AWS EKS & Multi-AZ VPC Infrastructure Module
module "aws_eks" {
  source = "../../modules/aws-eks"

  cluster_name          = var.cluster_name
  environment           = var.environment
  aws_region            = var.aws_region
  vpc_cidr              = var.vpc_cidr
  kubernetes_version    = var.kubernetes_version
  single_nat_gateway    = var.single_nat_gateway
  enable_kms_encryption = var.enable_kms_encryption
  tags                  = var.tags
}
