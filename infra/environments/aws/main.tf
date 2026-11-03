# OpenTofu Root: AWS Ephemeral EKS (Spot NodeGroup + Cost Safety Guardrails)

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

variable "aws_region" {
  type        = string
  default     = "us-east-2"
  description = "AWS target region"
}

variable "environment" {
  type        = string
  default     = "ephemeral-demo"
  description = "Deployment environment name"
}

# Module calls for VPC (single shared NAT) and EKS Spot NodeGroup will be populated here
