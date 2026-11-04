# Milestone 1.3: Cilium eBPF CNI & Longhorn 3-Way Distributed Block Storage

* **Status:** Verified & Fully Operational (Live Cluster Deployed)
* **Target Environment:** `local-kvm` (Libvirt / KVM / Talos Linux on bare-metal hypervisor)
* **Architecture Reference:** [ADR-0002: Decoupled Monorepo Tiering](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0002-decoupled-monorepo-tiering.md), [ADR-0006: Native Declarative Talos Configuration](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0006-native-talos-configuration-via-opentofu-provider.md)
* **Date:** 2026-11-03

---

## 1. Objective & Problem Solved
With the 6-node Talos Linux HA cluster booted and its Layer-2 Virtual IP (`192.168.122.200:6443`) active, the cluster requires:
1. **High-Performance eBPF CNI & Kube-Proxy Replacement:** Because default Flannel CNI and `kube-proxy` are disabled in the Talos machine configs, **Cilium eBPF (`v1.16.3`)** is deployed to handle east-west pod networking, service load balancing via eBPF maps directly against `192.168.122.200:6443`, and Hubble network observability.
2. **Distributed 3-Way Replicated Block Storage (Longhorn `v1.7.2`):** Stateless workloads can reschedule freely, but stateful workloads (such as PostgreSQL or message queues) require persistent volumes that survive worker node loss. Longhorn aggregates the dedicated `43 GB` `/dev/vdb` secondary disks mounted at `/var/lib/longhorn` across `enterprise-ha-worker-01..03` into a synchronous 3-way replicated `StorageClass`.

---

## 2. Architecture & File Layout

* **Tier 1 Infrastructure Patch (`infra/environments/local-kvm/`):**
  * [`talos.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/local-kvm/talos.tf): Adds `machine.kubelet.extraMounts` for `/var/lib/longhorn` with `["bind", "rshared", "rw"]` mount propagation and `cluster.proxy.disabled = true` on the worker configuration so Longhorn CSI mounts propagate cleanly between the Talos host and the containerized `kubelet`.
* **Tier 2 Platform Services (`platform/`):**
  * [`platform/cni/cilium/values.yaml`](file:///home/bjarrett/Projects/enterprise-ha-platform/platform/cni/cilium/values.yaml): Configures Cilium with `kubeProxyReplacement: true`, `k8sServiceHost: 192.168.122.200`, `k8sServicePort: 6443`, Hubble Relay enabled, and Talos-hardened security capabilities (`cgroup.autoMount.enabled: false`, `cgroup.hostRoot: /sys/fs/cgroup`, omitting `SYS_MODULE`).
  * [`platform/storage/longhorn/namespace.yaml`](file:///home/bjarrett/Projects/enterprise-ha-platform/platform/storage/longhorn/namespace.yaml): Creates the `longhorn-system` namespace with `pod-security.kubernetes.io/enforce: privileged` required by Talos Linux's default PodSecurity admission controller.
  * [`platform/storage/longhorn/values.yaml`](file:///home/bjarrett/Projects/enterprise-ha-platform/platform/storage/longhorn/values.yaml): Configures Longhorn with `defaultDataPath: /var/lib/longhorn` and `defaultReplicaCount: 3` (`defaultClassReplicaCount: 3`).
* **Unified Automation (`Makefile`):**
  * [`Makefile`](file:///home/bjarrett/Projects/enterprise-ha-platform/Makefile): Adds `make deploy-platform` to declaratively install/upgrade Cilium eBPF and Longhorn via Helm.

---

## 3. Live Verification & Evidence

### A. All 6 Nodes Transitioned to `Ready` via Cilium eBPF (`kubectl get nodes -o wide`)
```text
NAME                      STATUS   ROLES           AGE     VERSION   INTERNAL-IP      EXTERNAL-IP   OS-IMAGE         KERNEL-VERSION   CONTAINER-RUNTIME
enterprise-ha-cp-01       Ready    control-plane   3h49m   v1.32.0   192.168.122.6    <none>        Talos (v1.8.1)   6.6.54-talos     containerd://2.0.0-rc.5
enterprise-ha-cp-02       Ready    control-plane   3h49m   v1.32.0   192.168.122.7    <none>        Talos (v1.8.1)   6.6.54-talos     containerd://2.0.0-rc.5
enterprise-ha-cp-03       Ready    control-plane   3h49m   v1.32.0   192.168.122.8    <none>        Talos (v1.8.1)   6.6.54-talos     containerd://2.0.0-rc.5
enterprise-ha-worker-01   Ready    <none>          3h49m   v1.32.0   192.168.122.22   <none>        Talos (v1.8.1)   6.6.54-talos     containerd://2.0.0-rc.5
enterprise-ha-worker-02   Ready    <none>          3h49m   v1.32.0   192.168.122.23   <none>        Talos (v1.8.1)   6.6.54-talos     containerd://2.0.0-rc.5
enterprise-ha-worker-03   Ready    <none>          3h49m   v1.32.0   192.168.122.24   <none>        Talos (v1.8.1)   6.6.54-talos     containerd://2.0.0-rc.5
```

### B. Dedicated `/dev/vdb` Disks Registered & Schedulable in Longhorn (`nodes.longhorn.io`)
```text
NAME                      READY   ALLOWSCHEDULING   SCHEDULABLE   DISK PATH           FILESYSTEM   STORAGE MAXIMUM
enterprise-ha-worker-01   True    true              True          /var/lib/longhorn   xfs          42.88 GB (42880466944 B)
enterprise-ha-worker-02   True    true              True          /var/lib/longhorn   xfs          42.88 GB (42880466944 B)
enterprise-ha-worker-03   True    true              True          /var/lib/longhorn   xfs          42.88 GB (42880466944 B)
```

### C. 3-Way Replicated PersistentVolumeClaim (PVC) Verification
A test `PersistentVolumeClaim` (`longhorn-smoke-test-pvc`, `1Gi`, `storageClassName: longhorn`) and consumer pod were deployed, verified to bind (`ROBUSTNESS: healthy`) with **3 active volume replicas** across `enterprise-ha-worker-01`, `enterprise-ha-worker-02`, and `enterprise-ha-worker-03`, confirmed read/write persistence, and cleaned up:

```text
NAME                                       DATA ENGINE   STATE      ROBUSTNESS   SCHEDULED   SIZE         NODE                      AGE
pvc-e7012118-55eb-479a-a0f4-e933767fe9ee   v1            attached   healthy                  1073741824   enterprise-ha-worker-03   26s

NAME                                                  DATA ENGINE   STATE     NODE                      DISK                                   IMAGE                               AGE
pvc-e7012118-55eb-479a-a0f4-e933767fe9ee-r-4532a4cd   v1            running   enterprise-ha-worker-02   cb2adbc6-0924-4616-a172-36cbc16a26fe   longhornio/longhorn-engine:v1.7.2   25s
pvc-e7012118-55eb-479a-a0f4-e933767fe9ee-r-674dfedf   v1            running   enterprise-ha-worker-01   cecd29fd-0649-4267-8797-95fd374cba47   longhornio/longhorn-engine:v1.7.2   25s
pvc-e7012118-55eb-479a-a0f4-e933767fe9ee-r-f47d321b   v1            running   enterprise-ha-worker-03   e67a8d32-9acc-459e-8395-21eb3098165d   longhornio/longhorn-engine:v1.7.2   25s
```
