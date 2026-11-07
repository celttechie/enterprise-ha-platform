# OpenTofu Module Variables: AWS EKS with Cost Guardrails

variable "cluster_name" {
  type        = string
  default     = "enterprise-ha-eks"
  description = "Name of the EKS cluster and prefix for related cloud resources"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target deployment environment (e.g., dev, staging, prod)"
}

variable "aws_region" {
  type        = string
  default     = "us-east-2"
  description = "AWS region for provisioning resources"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "Base CIDR block for the dedicated VPC"
}

variable "availability_zones" {
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
  description = "List of Availability Zones to distribute subnets across (minimum 3 for HA)"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  description = "List of CIDR blocks for public subnets (aligned with availability_zones)"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
  description = "List of CIDR blocks for private subnets (aligned with availability_zones)"
}

variable "kubernetes_version" {
  type        = string
  default     = "1.31"
  description = "Desired Kubernetes version for the EKS control plane"
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "If true, provision a single shared NAT Gateway to save 67% on egress costs (ADR-0008). Set false for multi-AZ NAT isolation."
}

variable "enable_kms_encryption" {
  type        = bool
  default     = true
  description = "Enable KMS envelope encryption for Kubernetes Secret resources at rest in etcd"
}

variable "cluster_log_types" {
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  description = "List of EKS control plane logging components to stream to CloudWatch"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to all resources"
}

# -----------------------------------------------------------------------------
# Node Group & Addon Configuration (Milestone 2.2)
# -----------------------------------------------------------------------------

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
  description = "Diversified instance types for Spot node allocation (fall back if capacity constrained)"
}

variable "node_capacity_type" {
  type        = string
  default     = "SPOT"
  description = "EC2 capacity allocation strategy: SPOT (70% savings) or ON_DEMAND"
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

variable "node_disk_size" {
  type        = number
  default     = 20
  description = "Root EBS disk size in GiB for worker node instances"
}

variable "enable_pod_identity_agent" {
  type        = bool
  default     = true
  description = "Enable modern AWS EKS Pod Identity Agent managed addon"
}
