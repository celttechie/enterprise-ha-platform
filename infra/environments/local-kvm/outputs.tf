output "controlplane_nodes" {
  description = "Domain names of the 3 HA control plane nodes"
  value       = module.kvm_cluster.controlplane_nodes
}

output "controlplane_ips" {
  description = "Assigned IP addresses of the control plane nodes"
  value       = module.kvm_cluster.controlplane_ips
}

output "worker_nodes" {
  description = "Domain names of the 3 worker nodes"
  value       = module.kvm_cluster.worker_nodes
}

output "worker_ips" {
  description = "Assigned IP addresses of the worker nodes"
  value       = module.kvm_cluster.worker_ips
}
