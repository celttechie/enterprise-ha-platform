# ADR 0007: Split-Horizon Active/Active Control Plane Load Balancing & Fast VIP Failover

* **Status:** Accepted
* **Date:** 2026-11-04
* **Deciders:** Platform Engineering Team
* **Related:** [ADR-0006: Native Declarative Talos Configuration](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0006-native-talos-configuration-via-opentofu-provider.md), [Milestone 1.4: Control Plane Quorum Chaos Drill](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/milestones/milestone-1.4-control-plane-quorum-chaos.md)

---

## 1. Context and Problem Statement
During execution of the **Milestone 1.4 Control Plane HA Quorum & VIP Failover Chaos Drill** (`make chaos-cp`), forcibly powering off the control plane node holding the Layer-2 Virtual IP (`192.168.122.200`) via `virsh destroy` revealed two production architectural bottlenecks:

1. **45–48 Second Failover Window on Hard Power Loss:** Talos Linux's built-in Layer-2 VIP controller (`network.OperatorVIPConfigController`) relies on an etcd distributed lock (`clientv3` `concurrency.NewSession`) with a hardcoded ~30–45 second session TTL and gRPC keepalive timeout. When a control plane node suffers an ungraceful power cut, surviving control plane nodes must wait ~45–48 seconds for the etcd session lease to expire before acquiring `192.168.122.200` and broadcasting a Gratuitous ARP.
2. **Single-Node API Traffic Bottleneck:** Pointing both external clients (`kubectl`, CI/CD) and internal cluster components (`Cilium eBPF` with `kubeProxyReplacement: true`, `kubelet`, operators) at a single active/passive Layer-2 VIP routes 100% of API requests onto a single `kube-apiserver` instance while the other two control plane nodes sit idle. Furthermore, if the VIP is transiently unreachable during L2 lease transfer, in-cluster CNI and controller health checks experience unnecessary disruption.

In a large-scale production environment (hundreds of nodes), control plane traffic must be actively load-balanced across all healthy `kube-apiserver` instances without introducing an external Single Point of Failure (SPOF), and failover upon sudden hardware loss must complete in **under 5 seconds**.

---

## 2. Decision Drivers
* **Zero Single Points of Failure (SPOF):** The load-balancing and failover mechanism must survive the sudden destruction of any infrastructure component or VM.
* **True Active/Active/Active Load Balancing:** Both internal (East-West) and external (North-South) API traffic should be distributed across all 3 `kube-apiserver` instances (`192.168.122.6`, `192.168.122.7`, `192.168.122.8`).
* **Sub-5-Second Failover (`<5s`):** Ungraceful termination (`virsh destroy`) of the active VIP holder must recover North-South connectivity in `~3–5 seconds` and East-West in-cluster connectivity in `<1 second`.
* **100% Declarative Zero-Touch Lifecycle:** Must integrate cleanly into `infra/environments/local-kvm/talos.tf` (`cluster.inlineManifests`) so `make deploy TARGET=local-kvm` stands up the entire architecture without external scripts or extra host VMs.

---

## 3. Considered Options

### Option A: Talos Built-in etcd Layer-2 VIP (Baseline)
* **Mechanism:** Uses `machine.network.interfaces[].vip.ip` managed by Talos's internal `OperatorVIPConfigController` backed by an etcd session lease.
* **Pros:** Built into Talos; zero extra manifests.
* **Cons:**
  * Hardcoded etcd session lease TTL results in a **45–48s** API outage during ungraceful power loss of the VIP holder.
  * Couples VIP availability directly to etcd Raft consensus under load.
  * Pure Active/Passive routing (all API traffic lands on 1 of 3 control plane nodes).

### Option B: Single External Layer-4 Load Balancer (HAProxy / Envoy on Hypervisor)
* **Mechanism:** Run a single external HAProxy or Envoy TCP load balancer on `192.168.122.200:6443` health-checking `192.168.122.6..8:6443`.
* **Pros:** Sub-second (`<1s`) backend failover; round-robins across all 3 control plane nodes.
* **Cons:** **Introduces an external Single Point of Failure (SPOF).** If the single HAProxy process or host crashes, the entire cluster API becomes unreachable even though all 3 Kubernetes control plane nodes are healthy.

### Option C: External HAProxy Pair + Keepalived (VRRP) VMs
* **Mechanism:** Provision 2 additional dedicated load-balancer VMs running HAProxy + Keepalived VRRP in front of the 3 control plane VMs.
* **Pros:** Eliminates the external SPOF; provides VRRP sub-3s failover and L4 round-robin load balancing.
* **Cons:** Requires provisioning and maintaining 2 extra VMs (increasing cluster VM count from 6 to 8 and consuming ~4 GB of additional hypervisor RAM) for functionality that the Linux kernel on the 3 control plane nodes can perform natively.

### Option D: Split-Horizon Active/Active Architecture — Talos `KubePrism` (East-West) + `kube-vip` with Kernel IPVS Load Balancing (North-South)
* **Mechanism:** Decouples internal cluster API traffic from external client API traffic across two resilient layers running directly on the cluster nodes:
  1. **East-West (In-Cluster) via Talos `KubePrism` (`127.0.0.1:7445`) — Zero VIP:** Every control plane and worker node runs a stateless, node-local TCP load balancer on `127.0.0.1:7445` that actively health-checks and load-balances across all 3 control plane nodes (`192.168.122.6:6443`, `.7:6443`, `.8:6443`). Cilium eBPF (`kubeProxyReplacement`) and `kubelet` connect strictly to `127.0.0.1:7445`, completely eliminating any VIP or ARP dependency inside the cluster.
  2. **North-South (External) via `kube-vip` DaemonSet with Tuned Lease (`5s/3s/1s`) + Kernel IPVS Load Balancing:** On a flat Layer-2 Ethernet subnet (`192.168.122.0/24`) without an upstream Layer-3 BGP/ECMP router, Ethernet ARP can only map `192.168.122.200` to one MAC address at a time (the **L2 IPVS Director**), which then fans out connections in parallel across all 3 backend `kube-apiserver` instances (`.6`, `.7`, `.8`) via Linux Kernel IPVS (`lb_enable=true`). If the L2 IPVS Director node is destroyed, `kube-vip`'s tuned lease (`vip_leaseduration=5`, `vip_renewdeadline=3`, `vip_retryperiod=1`) elects a new IPVS Director and updates ARP in `~1.5–3 seconds`—fast enough that standard client TCP `SYN` retransmission absorbs the handoff with **zero failed API requests**. *(Note: In data centers with Layer-3 ToR switches, `kube-vip` or Cilium can switch from ARP mode to BGP Anycast + ECMP so all 3 nodes advertise `192.168.122.200/32` simultaneously with zero L2 VIP handoff).*

---

## 4. Decision Outcome
**Chosen Option:** **Option D** (`KubePrism` East-West Active/Active Load Balancing + `kube-vip` North-South Kernel IPVS Load Balancing with `5s/3s/1s` Lease Election).

### Positive Consequences:
* **Zero External SPOF:** All load balancing and VIP failover run natively across the 3 HA control plane nodes and 3 worker nodes.
* **10x Faster North-South Failover (`48s` $\rightarrow$ `~3–5s`):** When the control plane node holding `192.168.122.200` is forcibly terminated (`virsh destroy`), the `5s` lease expires and a surviving control plane node claims the VIP and broadcasts Gratuitous ARP within `3–5 seconds`.
* **Sub-Second (`<1s`) East-West Failover:** Because Cilium eBPF and `kubelet` use `KubePrism` (`127.0.0.1:7445`), in-cluster networking and pod scheduling never depend on the external `.200` VIP at all.
* **True Active/Active/Active Utilization:** Kernel IPVS (`kube-vip`) and `KubePrism` distribute API requests evenly across all 3 `kube-apiserver` instances.

### Negative Consequences / Trade-offs:
* Adds a declarative `kube-vip` `inlineManifest` (~120 lines of YAML) to `infra/environments/local-kvm/talos.tf`.

---

## 5. Compliance & Verification
* `infra/environments/local-kvm/talos.tf` enables `machine.features.kubePrism` (`port = 7445`), configures `cluster.apiServer.certSANs = [var.controlplane_vip, "127.0.0.1"]`, and embeds the `kube-vip` RBAC and `DaemonSet` via `cluster.inlineManifests`.
* `platform/cni/cilium/values.yaml` points `k8sServiceHost: 127.0.0.1` and `k8sServicePort: 7445`.
* Verified via `make chaos-cp` (`workloads/chaos-drills/validate-cp-quorum-chaos.sh`).
