# Milestone 1.2: Talos Linux HA Machine Configs & Virtual Control Plane IP

* **Status:** Verified & Complete
* **Target Environment:** `local-kvm` (Libvirt / KVM / Talos Linux)
* **Date:** 2026-11-03

---

## 1. Objective & Problem Solved
In a multi-node Kubernetes cluster, pointing clients (`kubectl`, worker nodes, ingress) to a single master node's IP creates a single point of failure. If that node crashes, connections drop even though other master nodes are healthy.

Milestone 1.2 implements an **HA Layer-2 Virtual IP (VIP)** across the 3 control plane nodes and configures worker nodes for distributed block storage:
1. **Virtual Control Plane IP:** Talos native VIP fails over seamlessly across the 3 master nodes via Gratuitous ARP / VRRP.
2. **eBPF Preparedness:** Disables default Flannel CNI and `kube-proxy` to allow pure Cilium eBPF routing in Phase 4.
3. **Dedicated Storage Device:** Configures worker nodes to mount the secondary `/dev/vdb` disk to `/var/lib/longhorn` for 3-way distributed volume replication.

---

## 2. File & Configuration Layout

* **Environment Variables & Outputs:**
  * [`infra/environments/local-kvm/variables.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/local-kvm/variables.tf): Parameterizes `controlplane_vip` with generic default (`192.168.122.200`).
  * [`infra/environments/local-kvm/outputs.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/local-kvm/outputs.tf): Exports `controlplane_vip` and `kubernetes_api_endpoint` (`https://${var.controlplane_vip}:6443`).
* **Talos Patches & Templates:**
  * [`infra/environments/local-kvm/talos/patches/00-controlplane-vip.yaml.tpl`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/local-kvm/talos/patches/00-controlplane-vip.yaml.tpl): Template for Layer-2 VIP binding on `eth0`.
  * [`infra/environments/local-kvm/talos/patches/01-cilium-cni.yaml`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/local-kvm/talos/patches/01-cilium-cni.yaml): CNI none and proxy disabled patch.
  * [`infra/environments/local-kvm/talos/patches/02-longhorn-worker-disk.yaml`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/local-kvm/talos/patches/02-longhorn-worker-disk.yaml): Dedicated `/dev/vdb` Longhorn storage disk mount.
* **Automated Config Generator:**
  * [`infra/environments/local-kvm/talos/scripts/generate-ha-configs.sh`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/local-kvm/talos/scripts/generate-ha-configs.sh): Renders VIP template, merges patches, and invokes `talosctl gen config`.
  * [`infra/environments/local-kvm/talos/.gitignore`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/local-kvm/talos/.gitignore): Guarantees generated `secrets.yaml` and machine configs are never committed to version control.

---

## 3. Verification & Evidence

### A. Talos Config Generation Test
```bash
bash infra/environments/local-kvm/talos/scripts/generate-ha-configs.sh test-cluster 192.168.122.200
```
Verified that:
* `controlplane.yaml` contains `vip.ip = 192.168.122.200`.
* `worker.yaml` contains `disks[0].device = /dev/vdb` mounted to `/var/lib/longhorn`.
* `talosconfig` endpoints target `https://192.168.122.200:6443`.

### B. OpenTofu Validation
```bash
tofu init -backend=false
tofu validate
# Output: Success! The configuration is valid.
```

### C. Automated Test Suite
```bash
pytest -v
# Output: 5 passed in 1.45s
```
