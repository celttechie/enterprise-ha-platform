# Variables for GCP Ephemeral GKE Environment (Milestone 3.1)

variable "gcp_project_id" {
  type        = string
  default     = ""
  description = "Target Google Cloud Project ID"
}

variable "gcp_region" {
  type        = string
  default     = "us-central1"
  description = "Target Google Cloud region"
}

variable "gcp_zone" {
  type        = string
  default     = "us-central1-a"
  description = "Target Google Cloud zone (Zonal cluster qualifies for 1 free cluster management fee waiver)"
}

variable "cluster_name" {
  type        = string
  default     = "enterprise-ha-gke"
  description = "GKE cluster name"
}

variable "network_name" {
  type        = string
  default     = "enterprise-ha-gke-vpc"
  description = "Custom VPC network name"
}

variable "subnetwork_name" {
  type        = string
  default     = "enterprise-ha-gke-subnet"
  description = "Subnetwork name"
}

variable "primary_ip_cidr_range" {
  type        = string
  default     = "10.10.0.0/20"
  description = "Primary IP CIDR block for GKE worker nodes"
}

variable "pod_ip_cidr_range" {
  type        = string
  default     = "10.20.0.0/16"
  description = "Secondary IP CIDR block for Pods (VPC-native alias routing)"
}

variable "service_ip_cidr_range" {
  type        = string
  default     = "10.30.0.0/20"
  description = "Secondary IP CIDR block for ClusterIP Services"
}

variable "release_channel" {
  type        = string
  default     = "REGULAR"
  description = "GKE Release Channel"
}

variable "enable_workload_identity" {
  type        = bool
  default     = true
  description = "Enable Workload Identity Federation"
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Enable deletion protection (set false for automated ephemeral teardowns)"
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Resource labels applied to GCP resources"
}
