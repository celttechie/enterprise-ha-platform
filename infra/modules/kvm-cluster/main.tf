terraform {
  required_version = ">= 1.8.0"
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Base Talos Linux Operating System Volume (Golden Image)
# -----------------------------------------------------------------------------

resource "libvirt_volume" "talos_base_image" {
  name   = "talos-${var.talos_version}-${var.cluster_name}-base.raw"
  pool   = var.storage_pool
  source = var.talos_image_url
  format = "raw"
}

# -----------------------------------------------------------------------------
# Control Plane Nodes (HA Quorum: 3 Nodes)
# -----------------------------------------------------------------------------

resource "libvirt_volume" "cp_root" {
  count          = var.controlplane_count
  name           = "${var.cluster_name}-cp-${format("%02d", count.index + 1)}-root.qcow2"
  pool           = var.storage_pool
  base_volume_id = libvirt_volume.talos_base_image.id
  size           = var.os_disk_size_bytes
  format         = "qcow2"
}

resource "libvirt_domain" "controlplane" {
  count  = var.controlplane_count
  name   = "${var.cluster_name}-cp-${format("%02d", count.index + 1)}"
  memory = var.controlplane_memory_mb
  vcpu   = var.controlplane_vcpu

  cpu {
    mode = "host-passthrough"
  }

  disk {
    volume_id = libvirt_volume.cp_root[count.index].id
  }

  network_interface {
    network_name   = var.network_name
    mac            = length(var.controlplane_macs) > count.index ? var.controlplane_macs[count.index] : null
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}

# -----------------------------------------------------------------------------
# Worker Nodes with Secondary Longhorn Storage Disks (/dev/vdb)
# -----------------------------------------------------------------------------

resource "libvirt_volume" "worker_root" {
  count          = var.worker_count
  name           = "${var.cluster_name}-worker-${format("%02d", count.index + 1)}-root.qcow2"
  pool           = var.storage_pool
  base_volume_id = libvirt_volume.talos_base_image.id
  size           = var.os_disk_size_bytes
  format         = "qcow2"
}

resource "libvirt_volume" "worker_data" {
  count  = var.worker_count
  name   = "${var.cluster_name}-worker-${format("%02d", count.index + 1)}-longhorn.qcow2"
  pool   = var.storage_pool
  size   = var.longhorn_disk_size_bytes
  format = "qcow2"
}

resource "libvirt_domain" "worker" {
  count  = var.worker_count
  name   = "${var.cluster_name}-worker-${format("%02d", count.index + 1)}"
  memory = var.worker_memory_mb
  vcpu   = var.worker_vcpu

  cpu {
    mode = "host-passthrough"
  }

  # OS Disk (/dev/vda)
  disk {
    volume_id = libvirt_volume.worker_root[count.index].id
  }

  # Dedicated Longhorn Raw Block Volume (/dev/vdb)
  disk {
    volume_id = libvirt_volume.worker_data[count.index].id
  }

  network_interface {
    network_name   = var.network_name
    mac            = length(var.worker_macs) > count.index ? var.worker_macs[count.index] : null
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
