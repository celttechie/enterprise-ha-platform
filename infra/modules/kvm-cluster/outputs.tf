output "controlplane_nodes" {
  description = "List of control plane VM domain names"
  value       = libvirt_domain.controlplane[*].name
}

output "controlplane_ips" {
  description = "Assigned IP addresses for control plane nodes"
  value       = [for d in libvirt_domain.controlplane : try(d.network_interface[0].addresses[0], "pending")]
}

output "worker_nodes" {
  description = "List of worker VM domain names"
  value       = libvirt_domain.worker[*].name
}

output "worker_ips" {
  description = "Assigned IP addresses for worker nodes"
  value       = [for d in libvirt_domain.worker : try(d.network_interface[0].addresses[0], "pending")]
}

output "base_image_id" {
  description = "ID of the cached base OS volume"
  value       = libvirt_volume.talos_base_image.id
}
