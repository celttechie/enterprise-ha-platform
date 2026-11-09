# OpenTofu Root: GCP Ephemeral GKE (Free Tier Zonal + Spot NodePool) (Milestone 3.1)

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# GCP GKE & Custom VPC Infrastructure Module
module "gcp_gke" {
  source = "../../modules/gcp-gke"

  project_id               = var.gcp_project_id
  region                   = var.gcp_region
  zone                     = var.gcp_zone
  cluster_name             = var.cluster_name
  network_name             = var.network_name
  subnetwork_name          = var.subnetwork_name
  primary_ip_cidr_range    = var.primary_ip_cidr_range
  pod_ip_cidr_range        = var.pod_ip_cidr_range
  service_ip_cidr_range    = var.service_ip_cidr_range
  release_channel          = var.release_channel
  enable_workload_identity = var.enable_workload_identity
  deletion_protection      = var.deletion_protection
  labels                   = var.labels
}
