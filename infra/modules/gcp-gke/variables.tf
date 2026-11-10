# Variables for GCP GKE & VPC Module (Milestone 3.1)

variable "project_id" {
  type        = string
  description = "Target Google Cloud Project ID"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Target Google Cloud region"
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
  description = "Target Google Cloud zone (Zonal cluster qualifies for 1 free cluster management fee waiver)"
}

variable "cluster_name" {
  type        = string
  default     = "enterprise-ha-gke"
  description = "Name of the GKE cluster"
}

variable "network_name" {
  type        = string
  default     = "enterprise-ha-gke-vpc"
  description = "Name of the custom VPC network"
}

variable "subnetwork_name" {
  type        = string
  default     = "enterprise-ha-gke-subnet"
  description = "Name of the subnetwork hosting nodes"
}

variable "primary_ip_cidr_range" {
  type        = string
  default     = "10.10.0.0/20"
  description = "Primary IP CIDR block for GKE worker nodes"
}

variable "pod_ip_cidr_range" {
  type        = string
  default     = "10.20.0.0/16"
  description = "Secondary IP CIDR block for Kubernetes Pods (VPC-native alias routing)"
}

variable "pod_range_name" {
  type        = string
  default     = "pods"
  description = "Name of the secondary range for Pods"
}

variable "service_ip_cidr_range" {
  type        = string
  default     = "10.30.0.0/20"
  description = "Secondary IP CIDR block for Kubernetes ClusterIP Services"
}

variable "service_range_name" {
  type        = string
  default     = "services"
  description = "Name of the secondary range for Services"
}

variable "release_channel" {
  type        = string
  default     = "REGULAR"
  description = "GKE Release Channel (RAPID, REGULAR, STABLE)"
}

variable "enable_workload_identity" {
  type        = bool
  default     = true
  description = "Enable Workload Identity Federation mapping K8s ServiceAccounts to Google Cloud IAM"
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Enable deletion protection (set false for ephemeral automated testbeds)"
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Resource labels applied to GCP resources"
}

# -----------------------------------------------------------------------------
# Spot NodePool Configuration (Milestone 3.2)
# -----------------------------------------------------------------------------

variable "node_machine_type" {
  type        = string
  default     = "e2-medium"
  description = "Compute Engine machine type for worker nodes (e2-medium: 2 vCPU, 4GB RAM)"
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Initial desired worker node count"
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Minimum worker node count for autoscaling"
}

variable "node_max_size" {
  type        = number
  default     = 4
  description = "Maximum worker node count for autoscaling"
}

variable "node_disk_size_gb" {
  type        = number
  default     = 30
  description = "Root disk size in GB for each worker node"
}
