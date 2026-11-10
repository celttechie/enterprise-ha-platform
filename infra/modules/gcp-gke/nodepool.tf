# GKE Spot Compute NodePool (Milestone 3.2)
# Configured with Spot VM pricing (60-91% savings), autoscaling, and Workload Identity metadata.

resource "google_container_node_pool" "spot_nodes" {
  name     = "${var.cluster_name}-spot-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  initial_node_count = var.node_desired_size

  autoscaling {
    min_node_count = var.node_min_size
    max_node_count = var.node_max_size
  }

  node_config {
    # Spot VM allocation for cost guardrail (ADR-0003)
    spot         = true
    machine_type = var.node_machine_type
    disk_size_gb = var.node_disk_size_gb
    disk_type    = "pd-balanced"

    # Dedicated least-privilege node service account
    service_account = google_service_account.gke_nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    # Workload Identity Federation node metadata server integration (ADR-0003)
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Shielded VM security hardening
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = merge(
      var.labels,
      {
        "cloud.google.com/gke-spot" = "true"
      }
    )

    tags = ["gke-node", "${var.cluster_name}-node"]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  lifecycle {
    ignore_changes = [
      initial_node_count,
    ]
  }

  depends_on = [
    google_project_iam_member.node_roles,
  ]
}
