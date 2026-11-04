# ==============================================================================
# Talos Linux High Availability Configuration Generator
# Uses official siderolabs/talos provider - 100% declarative, zero bash scripts
# ==============================================================================

# 1. Cluster Secrets & PKI Generation (stored securely in OpenTofu state)
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# 2. Control Plane Machine Configuration (KubePrism + kube-vip IPVS + Cilium CNI)
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = "https://${var.controlplane_vip}:6443"
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
  config_patches = [
    yamlencode({
      machine = {
        features = {
          kubePrism = {
            enabled = true
            port    = 7445
          }
        }
        network = {
          interfaces = [
            {
              interface = "eth0"
              dhcp      = true
            }
          ]
        }
      }
      cluster = {
        apiServer = {
          certSANs = [
            var.controlplane_vip,
            "127.0.0.1"
          ]
        }
        etcd = {
          extraArgs = {
            election-timeout   = "1000"
            heartbeat-interval = "200"
          }
        }
        network = {
          cni = {
            name = "none"
          }
        }
        proxy = {
          disabled = true
        }
        inlineManifests = [
          {
            name     = "kube-vip"
            contents = <<-EOT
              apiVersion: v1
              kind: ServiceAccount
              metadata:
                name: kube-vip
                namespace: kube-system
              ---
              apiVersion: rbac.authorization.k8s.io/v1
              kind: ClusterRole
              metadata:
                name: system:kube-vip-role
              rules:
                - apiGroups: [""]
                  resources: ["services", "services/status", "nodes", "endpoints"]
                  verbs: ["list", "get", "watch", "update"]
                - apiGroups: ["coordination.k8s.io"]
                  resources: ["leases"]
                  verbs: ["list", "get", "watch", "update", "create"]
              ---
              apiVersion: rbac.authorization.k8s.io/v1
              kind: ClusterRoleBinding
              metadata:
                name: system:kube-vip-binding
              roleRef:
                apiGroup: rbac.authorization.k8s.io
                kind: ClusterRole
                name: system:kube-vip-role
              subjects:
                - kind: ServiceAccount
                  name: kube-vip
                  namespace: kube-system
              ---
              apiVersion: apps/v1
              kind: DaemonSet
              metadata:
                name: kube-vip-ds
                namespace: kube-system
                labels:
                  app.kubernetes.io/name: kube-vip-ds
              spec:
                selector:
                  matchLabels:
                    app.kubernetes.io/name: kube-vip-ds
                template:
                  metadata:
                    labels:
                      app.kubernetes.io/name: kube-vip-ds
                  spec:
                    serviceAccountName: kube-vip
                    hostNetwork: true
                    nodeSelector:
                      node-role.kubernetes.io/control-plane: ""
                    tolerations:
                      - effect: NoSchedule
                        operator: Exists
                      - effect: NoExecute
                        operator: Exists
                    containers:
                      - name: kube-vip
                        image: ghcr.io/kube-vip/kube-vip:v0.8.7
                        imagePullPolicy: IfNotPresent
                        args:
                          - manager
                        env:
                          - name: vip_arp
                            value: "true"
                          - name: port
                            value: "6443"
                          - name: vip_nodename
                            valueFrom:
                              fieldRef:
                                fieldPath: spec.nodeName
                          - name: vip_interface
                            value: "eth0"
                          - name: cp_enable
                            value: "true"
                          - name: cp_namespace
                            value: "kube-system"
                          - name: vip_leaderelection
                            value: "true"
                          - name: vip_leasename
                            value: "plndr-cp-lock"
                          - name: vip_leaseduration
                            value: "5"
                          - name: vip_renewdeadline
                            value: "3"
                          - name: vip_retryperiod
                            value: "1"
                          - name: lb_enable
                            value: "true"
                          - name: lb_port
                            value: "6443"
                          - name: lb_forwardingmethod
                            value: "local"
                          - name: address
                            value: "${var.controlplane_vip}"
                          - name: prometheus_server
                            value: ":2112"
                        securityContext:
                          capabilities:
                            add:
                              - NET_ADMIN
                              - NET_RAW
                              - SYS_TIME
            EOT
          }
        ]
      }
    })
  ]
}

# 3. Worker Machine Configuration (KubePrism + Longhorn disk partition + Cilium CNI)
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
        proxy = {
          disabled = true
        }
      }
      machine = {
        features = {
          kubePrism = {
            enabled = true
            port    = 7445
          }
        }
        kubelet = {
          extraMounts = [
            {
              destination = "/var/lib/longhorn"
              type        = "bind"
              source      = "/var/lib/longhorn"
              options = [
                "bind",
                "rshared",
                "rw"
              ]
            }
          ]
        }
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

