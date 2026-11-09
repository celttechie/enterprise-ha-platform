# Custom VPC & Subnetwork for GKE (Milestone 3.1)
# Enforces VPC-Native Alias IP Routing with dedicated Pod and Service secondary ranges.

resource "google_compute_network" "main" {
  name                    = var.network_name
  auto_create_subnetworks = false
  description             = "Custom VPC for enterprise-ha-platform GKE testbed"
  project                 = var.project_id
}

resource "google_compute_subnetwork" "main" {
  name                     = var.subnetwork_name
  ip_cidr_range            = var.primary_ip_cidr_range
  region                   = var.region
  network                  = google_compute_network.main.id
  private_ip_google_access = true
  project                  = var.project_id

  # Secondary IP range for Kubernetes Pods
  secondary_ip_range {
    range_name    = var.pod_range_name
    ip_cidr_range = var.pod_ip_cidr_range
  }

  # Secondary IP range for Kubernetes ClusterIP Services
  secondary_ip_range {
    range_name    = var.service_range_name
    ip_cidr_range = var.service_ip_cidr_range
  }
}
