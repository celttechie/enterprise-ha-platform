# Module Outputs: AWS EKS Cluster & Infrastructure

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane API"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "The ARN of the IAM OIDC Provider for EKS IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "kms_key_arn" {
  description = "The ARN of the KMS key used for envelope encryption of Kubernetes secrets"
  value       = try(aws_kms_key.eks_secrets[0].arn, null)
}

output "node_role_arn" {
  description = "IAM role ARN attached to worker node instances"
  value       = aws_iam_role.node.arn
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane"
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS worker nodes"
  value       = aws_security_group.node.id
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.nat[*].id
}

output "node_ssh_key_name" {
  description = "Name of the deterministic EC2 KeyPair for fallback worker node console access"
  value       = aws_key_pair.node_key.key_name
}

output "node_ssh_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret storing the private SSH key"
  value       = aws_secretsmanager_secret.node_ssh_private_key.arn
}
