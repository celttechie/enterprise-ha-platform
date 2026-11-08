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

# -----------------------------------------------------------------------------
# Node Group & Addon Outputs (Milestone 2.2)
# -----------------------------------------------------------------------------

output "node_group_id" {
  description = "ID of the EKS Spot Node Group"
  value       = module.aws_eks.node_group_id
}

output "node_group_arn" {
  description = "ARN of the EKS Spot Node Group"
  value       = module.aws_eks.node_group_arn
}

output "node_group_status" {
  description = "Status of the EKS Spot Node Group"
  value       = module.aws_eks.node_group_status
}

output "addon_vpc_cni_arn" {
  description = "ARN of the vpc-cni addon"
  value       = module.aws_eks.addon_vpc_cni_arn
}

output "addon_coredns_arn" {
  description = "ARN of the coredns addon"
  value       = module.aws_eks.addon_coredns_arn
}

output "addon_kube_proxy_arn" {
  description = "ARN of the kube-proxy addon"
  value       = module.aws_eks.addon_kube_proxy_arn
}

output "addon_pod_identity_agent_arn" {
  description = "ARN of the eks-pod-identity-agent addon"
  value       = module.aws_eks.addon_pod_identity_agent_arn
}

# -----------------------------------------------------------------------------
# Platform Storage & Ingress Outputs (Milestone 2.3)
# -----------------------------------------------------------------------------

output "ebs_csi_role_arn" {
  description = "ARN of the IAM role for Amazon EBS CSI Driver"
  value       = module.aws_eks.ebs_csi_role_arn
}

output "addon_ebs_csi_arn" {
  description = "ARN of the aws-ebs-csi-driver addon"
  value       = module.aws_eks.addon_ebs_csi_arn
}

output "lbc_role_arn" {
  description = "ARN of the IAM role for AWS Load Balancer Controller"
  value       = module.aws_eks.lbc_role_arn
}

# -----------------------------------------------------------------------------
# Cost Guardrail & Budget Outputs (Milestone 2.4)
# -----------------------------------------------------------------------------

output "budget_name" {
  description = "Name of the AWS Budgets cost guardrail"
  value       = module.aws_eks.budget_name
}

output "budget_limit_amount" {
  description = "Configured monthly spend limit for the testbed"
  value       = module.aws_eks.budget_limit_amount
}
