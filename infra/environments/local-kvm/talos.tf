# ==============================================================================
# Talos Linux High Availability Configuration Generator
# Uses official siderolabs/talos provider - 100% declarative, zero bash scripts
# ==============================================================================

# 1. Cluster Secrets & PKI Generation (stored securely in OpenTofu state)
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# 2. Control Plane Machine Configuration (with VIP and Cilium CNI patches)
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.controlplane_vip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              interface = "eth0"
              dhcp      = true
              vip = {
                ip = var.controlplane_vip
              }
            }
          ]
        }
      }
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
      }
    })
  ]
}

# 3. Worker Machine Configuration (with Longhorn disk partition and Cilium CNI)
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.controlplane_vip}:6443"
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    yamlencode({
      cluster = {
        network = {
          cni = {
            name = "none"
          }
        }
      }
      machine = {
        disks = [
          {
            device = "/dev/vdb"
            partitions = [
              {
                mountpoint = "/var/lib/longhorn"
              }
            ]
          }
        ]
      }
    })
  ]
}

# 4. Talos Client Configuration (talosconfig)
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.controlplane_vip]
  nodes                = [var.controlplane_vip]
}

# 5. Local File Generation (writes configurations to talos/ directory)
resource "local_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.module}/talos/talosconfig"
  file_permission = "0600"
}

resource "local_file" "controlplane_config" {
  content         = data.talos_machine_configuration.controlplane.machine_configuration
  filename        = "${path.module}/talos/controlplane.yaml"
  file_permission = "0644"
}

resource "local_file" "worker_config" {
  content         = data.talos_machine_configuration.worker.machine_configuration
  filename        = "${path.module}/talos/worker.yaml"
  file_permission = "0644"
}

# ------------------------------------------------------------------------------
# 6. Automated Machine Configuration Delivery (Insecure -> Configured Transition)
# ------------------------------------------------------------------------------
resource "talos_machine_configuration_apply" "controlplane" {
  count                       = var.controlplane_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = module.kvm_cluster.controlplane_ips[count.index]
}

resource "talos_machine_configuration_apply" "worker" {
  count                       = var.worker_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = module.kvm_cluster.worker_ips[count.index]
}

# ------------------------------------------------------------------------------
# 7. Automated etcd Cluster Bootstrap
# ------------------------------------------------------------------------------
resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.controlplane]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = module.kvm_cluster.controlplane_ips[0]
}

# ------------------------------------------------------------------------------
# 8. Automated Admin Kubeconfig Extraction
# ------------------------------------------------------------------------------
resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = module.kvm_cluster.controlplane_ips[0]
}

resource "local_file" "kubeconfig" {
  content         = resource.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.module}/kubeconfig"
  file_permission = "0600"
}

