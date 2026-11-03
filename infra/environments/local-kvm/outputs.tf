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

output "controlplane_vip" {
  description = "Virtual IP address for the Kubernetes API server endpoint"
  value       = var.controlplane_vip
}

output "kubernetes_api_endpoint" {
  description = "HA Kubernetes API endpoint using the Virtual IP"
  value       = "https://${var.controlplane_vip}:6443"
}

output "kubeconfig_path" {
  description = "Path to the administrative kubeconfig file"
  value       = local_file.kubeconfig.filename
}
