# Zonal GKE Cluster ($0 Management Fee Waiver) (Milestone 3.1)
# Configured with VPC-Native IP routing, Workload Identity, and ephemeral guardrails.

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone
  project  = var.project_id

  network    = google_compute_network.main.name
  subnetwork = google_compute_subnetwork.main.name

  # Cost Guardrail: Remove expensive default node pool immediately upon creation
  remove_default_node_pool = true
  initial_node_count       = 1

  # Ephemeral Safety: Allow automated OpenTofu teardown without console lockouts
  deletion_protection = var.deletion_protection

  # VPC-Native IP Allocation (Alias IPs for Pods and Services)
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pod_range_name
    services_secondary_range_name = var.service_range_name
  }

  # Workload Identity Federation (ADR-0003: Zero static JSON service account keys)
  dynamic "workload_identity_config" {
    for_each = var.enable_workload_identity ? [1] : []
    content {
      workload_pool = "${var.project_id}.svc.id.goog"
    }
  }

  # GKE Core Addons Configuration
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    dns_cache_config {
      enabled = true
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  release_channel {
    channel = var.release_channel
  }

  resource_labels = merge(
    {
      "project"    = "enterprise-ha-platform"
      "managed-by" = "opentofu"
    },
    var.labels
  )

  lifecycle {
    ignore_changes = [
      # Ignore subnetwork changes if GKE computes internal links
      subnetwork,
    ]
  }
}
