# Outputs for GCP Ephemeral GKE Environment (Milestone 3.1)

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = module.gcp_gke.cluster_name
}

output "cluster_id" {
  description = "Unique resource identifier for the GKE cluster"
  value       = module.gcp_gke.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for GKE Kubernetes API server"
  value       = module.gcp_gke.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded public certificate authority data for cluster communication"
  value       = module.gcp_gke.cluster_ca_certificate
  sensitive   = true
}

output "location" {
  description = "The zone hosting the GKE control plane"
  value       = module.gcp_gke.location
}

output "network_name" {
  description = "Name of the custom VPC network"
  value       = module.gcp_gke.network_name
}

output "network_id" {
  description = "ID of the custom VPC network"
  value       = module.gcp_gke.network_id
}

output "subnetwork_name" {
  description = "Name of the subnetwork hosting GKE nodes"
  value       = module.gcp_gke.subnetwork_name
}

output "subnetwork_id" {
  description = "ID of the subnetwork hosting GKE nodes"
  value       = module.gcp_gke.subnetwork_id
}

output "pod_range_name" {
  description = "Name of the secondary IP range for Pods"
  value       = module.gcp_gke.pod_range_name
}

output "service_range_name" {
  description = "Name of the secondary IP range for Services"
  value       = module.gcp_gke.service_range_name
}

# -----------------------------------------------------------------------------
# Node Pool & Node IAM Outputs (Milestone 3.2)
# -----------------------------------------------------------------------------

output "node_pool_id" {
  description = "Unique resource identifier for the Spot NodePool"
  value       = module.gcp_gke.node_pool_id
}

output "node_pool_name" {
  description = "Name of the Spot NodePool"
  value       = module.gcp_gke.node_pool_name
}

output "node_service_account_email" {
  description = "Email address of the dedicated worker node service account"
  value       = module.gcp_gke.node_service_account_email
}
