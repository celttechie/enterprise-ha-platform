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

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
  description = "Diversified instance types for Spot node allocation"
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Initial desired worker node count"
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Minimum worker node count"
}

variable "node_max_size" {
  type        = number
  default     = 4
  description = "Maximum worker node count"
}
