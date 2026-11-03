variable "cluster_name" {
  type        = string
  default     = "enterprise-ha"
  description = "Unique cluster identifier used for VM domain names"
}

variable "storage_pool" {
  type        = string
  default     = "default"
  description = "Libvirt storage pool name for VM disks"
}

variable "network_name" {
  type        = string
  default     = "default"
  description = "Libvirt virtual network name (e.g. default / virbr0)"
}

variable "talos_version" {
  type        = string
  default     = "v1.8.0"
  description = "Talos Linux release version"
}

variable "talos_image_url" {
  type        = string
  default     = "https://factory.talos.dev/image/787b50bbd266e745672ab6443c748c5a2c4e33d2ff90eb01ff1a78c18712a488/v1.8.0/nocloud-amd64.raw.gz"
  description = "URL to the Talos Linux base disk image (nocloud-amd64)"
}

variable "controlplane_count" {
  type        = number
  default     = 3
  description = "Number of control plane nodes (odd number 3 or 5 required for etcd quorum)"
}

variable "worker_count" {
  type        = number
  default     = 3
  description = "Number of worker nodes for 3-way storage replication"
}

variable "controlplane_vcpu" {
  type        = number
  default     = 2
  description = "vCPU count per control plane node"
}

variable "controlplane_memory_mb" {
  type        = number
  default     = 3072
  description = "RAM allocated per control plane node (MB)"
}

variable "worker_vcpu" {
  type        = number
  default     = 2
  description = "vCPU count per worker node"
}

variable "worker_memory_mb" {
  type        = number
  default     = 4096
  description = "RAM allocated per worker node (MB)"
}

variable "os_disk_size_bytes" {
  type        = number
  default     = 21474836480 # 20 GiB
  description = "Size of the Talos OS root disk in bytes"
}

variable "longhorn_disk_size_bytes" {
  type        = number
  default     = 42949672960 # 40 GiB
  description = "Size of the secondary unformatted data disk for Longhorn storage in bytes"
}

variable "controlplane_macs" {
  type        = list(string)
  default     = ["52:54:00:12:34:10", "52:54:00:12:34:11", "52:54:00:12:34:12"]
  description = "Deterministic MAC addresses for control plane nodes"
}

variable "worker_macs" {
  type        = list(string)
  default     = ["52:54:00:12:34:20", "52:54:00:12:34:21", "52:54:00:12:34:22"]
  description = "Deterministic MAC addresses for worker nodes"
}
