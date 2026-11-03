# OpenTofu Root: Local KVM Hypervisor (Libvirt / Talos Linux)
# Architecture: 3 Control Plane (HA etcd) + 3 Worker Nodes (Longhorn 3x Replication)

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

module "kvm_cluster" {
  source = "../../modules/kvm-cluster"

  cluster_name       = var.cluster_name
  storage_pool       = var.storage_pool
  network_name       = var.network_name
  controlplane_count = var.controlplane_count
  worker_count       = var.worker_count
}
