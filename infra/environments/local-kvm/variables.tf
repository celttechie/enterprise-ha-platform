variable "libvirt_uri" {
  type        = string
  default     = "qemu:///system"
  description = "Libvirt daemon connection URI (e.g. qemu:///system or qemu+ssh://<user>@<host>/system)"
}

variable "cluster_name" {
  type        = string
  default     = "ha-kvm"
  description = "Cluster identifier prefix"
}

variable "storage_pool" {
  type        = string
  default     = "default"
  description = "Libvirt storage pool name"
}

variable "network_name" {
  type        = string
  default     = "default"
  description = "Libvirt network bridge name (e.g. default / virbr0)"
}

variable "controlplane_count" {
  type        = number
  default     = 3
  description = "Number of control plane nodes (odd number 3 or 5 for etcd quorum)"
}

variable "worker_count" {
  type        = number
  default     = 3
  description = "Number of worker nodes for 3-way storage replication"
}

variable "controlplane_vip" {
  type        = string
  default     = "192.168.122.200"
  description = "Virtual IP (VIP) for HA control plane floating address"
}
