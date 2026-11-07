# Variables for AWS Ephemeral EKS Environment

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

variable "cluster_name" {
  type        = string
  default     = "enterprise-ha-eks"
  description = "EKS cluster name"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Base VPC CIDR block"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.31"
  description = "Kubernetes control plane version"
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "Enable single shared NAT Gateway for cost guardrails (ADR-0008)"
}

variable "enable_kms_encryption" {
  type        = bool
  default     = true
  description = "Enable KMS envelope encryption for Kubernetes Secret resources"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to all resources"
}
