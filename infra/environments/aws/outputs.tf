# Outputs for AWS Ephemeral EKS Environment

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.aws_eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane API"
  value       = module.aws_eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.aws_eks.cluster_certificate_authority_data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.aws_eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the IAM OIDC Provider for EKS IRSA"
  value       = module.aws_eks.oidc_provider_arn
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for envelope encryption of Kubernetes secrets"
  value       = module.aws_eks.kms_key_arn
}

output "node_role_arn" {
  description = "IAM role ARN attached to worker node instances"
  value       = module.aws_eks.node_role_arn
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane"
  value       = module.aws_eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS worker nodes"
  value       = module.aws_eks.node_security_group_id
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.aws_eks.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.aws_eks.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.aws_eks.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.aws_eks.nat_gateway_ids
}

output "node_ssh_key_name" {
  description = "Name of the deterministic EC2 KeyPair for fallback worker node console access"
  value       = module.aws_eks.node_ssh_key_name
}

output "node_ssh_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret storing the private SSH key"
  value       = module.aws_eks.node_ssh_secret_arn
}
