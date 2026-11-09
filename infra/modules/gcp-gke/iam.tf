# Dedicated Least-Privilege IAM for GKE Worker Nodes (Milestone 3.2)
# Avoids using the default Compute Engine service account to prevent privilege escalation.

resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Worker Node Service Account for ${var.cluster_name}"
  project      = var.project_id
}

# Least-privilege roles required for worker node health, logging, metrics, and image pulling
locals {
  node_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ]
}

resource "google_project_iam_member" "node_roles" {
  for_each = toset(local.node_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.gke_nodes.email}"
}
