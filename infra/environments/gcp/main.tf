# OpenTofu Root: GCP Ephemeral GKE (Free Tier Zonal + Spot NodePool)

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.30"
    }
  }
}

variable "gcp_project_id" {
  type        = string
  default     = ""
  description = "Target Google Cloud Project ID"
}

variable "gcp_region" {
  type        = string
  default     = "us-central1"
  description = "GCP region"
}

variable "gcp_zone" {
  type        = string
  default     = "us-central1-a"
  description = "GCP zone (for 1 free cluster management fee waiver)"
}

# Module calls for GCP VPC and Zonal GKE Spot NodePool will be populated here
