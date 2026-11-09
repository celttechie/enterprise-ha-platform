# Outputs for GCP GKE & VPC Module (Milestone 3.1)

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_id" {
  description = "Unique resource identifier for the GKE cluster"
  value       = google_container_cluster.primary.id
}

output "cluster_endpoint" {
  description = "Endpoint for GKE Kubernetes API server"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded public certificate authority data for cluster communication"
  value       = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "location" {
  description = "The zone hosting the GKE control plane"
  value       = google_container_cluster.primary.location
}

output "network_name" {
  description = "Name of the custom VPC network"
  value       = google_compute_network.main.name
}

output "network_id" {
  description = "ID of the custom VPC network"
  value       = google_compute_network.main.id
}

output "subnetwork_name" {
  description = "Name of the subnetwork hosting GKE nodes"
  value       = google_compute_subnetwork.main.name
}

output "subnetwork_id" {
  description = "ID of the subnetwork hosting GKE nodes"
  value       = google_compute_subnetwork.main.id
}

output "pod_range_name" {
  description = "Name of the secondary IP range for Pods"
  value       = var.pod_range_name
}

output "service_range_name" {
  description = "Name of the secondary IP range for Services"
  value       = var.service_range_name
}
