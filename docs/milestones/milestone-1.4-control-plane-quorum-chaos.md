# Milestone 1.4: Control Plane High Availability Quorum & VIP Failover Chaos Drill

* **Status:** Verified & Fully Operational (Live Chaos Drill Executed)
* **Target Environment:** `local-kvm` (Libvirt / KVM / Talos Linux on bare-metal hypervisor)
* **Architecture Reference:** [ADR-0006: Native Declarative Talos Configuration](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0006-native-talos-configuration-via-opentofu-provider.md)
* **Date:** 2026-11-03

---

## 1. Objective & Problem Solved
In a 3-node High Availability Kubernetes control plane, etcd maintains consensus using the Raft algorithm, where quorum requires $\lfloor N/2 \rfloor + 1 = 2$ surviving members. Additionally, Talos Linux manages the Layer-2 Virtual IP (`192.168.122.200`) using an etcd-backed lease (`network.OperatorSpecController` for `vip/eth0`).

Milestone 1.4 validates that when a control plane node (specifically the active VIP holder or primary bootstrap node) suffers a sudden, ungraceful hardware power-off (`virsh destroy`):
1. **etcd Quorum Survival:** The remaining 2 control plane nodes maintain a $2/3$ Raft quorum and continue serving read/write operations without data loss.
2. **Layer-2 VIP Lease Failover:** Once the terminated node's etcd lease TTL expires (~45s on ungraceful power loss, or ~3s on non-VIP control plane node loss), a surviving control plane node acquires the `192.168.122.200` VIP and broadcasts a Gratuitous ARP to re-route API traffic seamlessly.
3. **Self-Healing Rejoin:** Upon power restoration (`virsh start`), the node boots Talos Linux from disk, rejoins the etcd cluster, and transitions back to `Ready` with zero manual intervention.

---

## 2. Automation & File Layout

* **Chaos Drill Script:**
  * [`workloads/chaos-drills/validate-cp-quorum-chaos.sh`](file:///home/bjarrett/Projects/enterprise-ha-platform/workloads/chaos-drills/validate-cp-quorum-chaos.sh):
    1. Dynamically inspects Talos `AddressStatus` across all 3 control plane nodes (`192.168.122.6..8`) to identify which node currently holds the `192.168.122.200/32` VIP on `eth0`.
    2. Starts a continuous background `/livez` probe against `https://192.168.122.200:6443/livez`.
    3. Forcibly terminates the active VIP holder VM via `virsh destroy`.
    4. Measures the etcd VIP lease election & Gratuitous ARP failover window.
    5. Performs an authenticated Kubernetes state write/read/delete test (`ConfigMap` creation and deletion) while the terminated control plane node is offline (`NotReady`).
    6. Powers the terminated VM back on (`virsh start`) and waits for it to rejoin the cluster and report `Ready`.
* **Makefile Integration:**
  * [`Makefile`](file:///home/bjarrett/Projects/enterprise-ha-platform/Makefile): Exposes `make chaos-cp` (and wires `make demo` to run the chaos drill).

---

## 3. Live Chaos Drill Execution & Telemetry

### Scenario A: Terminating Non-VIP Control Plane Node (`enterprise-ha-cp-01`)
When `enterprise-ha-cp-01` is forcibly powered off while `enterprise-ha-cp-03` holds the VIP:
* **VIP Failover Time:** `0s` interruption (`100%` of API probes succeeded with `0` failed probes).
* **etcd R/W Quorum:** Verified (`ConfigMap` created, verified, and deleted while `enterprise-ha-cp-01` was powered off).

### Scenario B: Terminating Active VIP Holder Node (`enterprise-ha-cp-03`)
When the active VIP holder (`enterprise-ha-cp-03` at `192.168.122.8`) is forcibly powered off via `virsh destroy`:

```text
==============================================================================
  MILESTONE 1.4: HA CONTROL PLANE QUORUM & VIP FAILOVER CHAOS DRILL
==============================================================================
  Active VIP Node : enterprise-ha-cp-03 (192.168.122.8)
  API Endpoint    : https://192.168.122.200:6443/livez
==============================================================================

[3/6] Injecting hardware fault: forcibly powering off VIP holder enterprise-ha-cp-03 (virsh destroy)...
Domain 'enterprise-ha-cp-03' destroyed
⚡ Node enterprise-ha-cp-03 terminated at 2026-11-04T02:44:56Z.

[4/6] Waiting for Talos etcd VIP lease election & Layer-2 Gratuitous ARP failover...
✅ VIP 192.168.122.200:6443 is responding on a surviving control plane node (failover time: 45s)!

Validating API server responsiveness and etcd quorum read/write survival while enterprise-ha-cp-03 is powered off...
NAME                      STATUS     ROLES           AGE    VERSION   INTERNAL-IP      OS-IMAGE
enterprise-ha-cp-01       Ready      control-plane   152m   v1.32.0   192.168.122.6    Talos (v1.8.1)
enterprise-ha-cp-02       Ready      control-plane   152m   v1.32.0   192.168.122.7    Talos (v1.8.1)
enterprise-ha-cp-03       NotReady   control-plane   152m   v1.32.0   192.168.122.8    Talos (v1.8.1)
enterprise-ha-worker-01   Ready      <none>          152m   v1.32.0   192.168.122.22   Talos (v1.8.1)
enterprise-ha-worker-02   Ready      <none>          152m   v1.32.0   192.168.122.23   Talos (v1.8.1)
enterprise-ha-worker-03   Ready      <none>          152m   v1.32.0   192.168.122.24   Talos (v1.8.1)
configmap/chaos-quorum-proof-1793760342 created
  quorum: survived
configmap "chaos-quorum-proof-1793760342" deleted
✅ Verified: etcd quorum wrote and deleted state while enterprise-ha-cp-03 was powered off!

[5/6] Restoring enterprise-ha-cp-03 (virsh start) and awaiting automatic quorum rejoin...
Domain 'enterprise-ha-cp-03' started
✅ enterprise-ha-cp-03 rejoined cluster and is Ready!

==============================================================================
  CHAOS DRILL TELEMETRY SUMMARY
==============================================================================
  Target Terminated : enterprise-ha-cp-03 (ungraceful virsh destroy)
  VIP Failover Time : 45s (etcd lease election + Gratuitous ARP)
  Total API Probes  : 26
  Successful (OK)   : 8
  Failover Window   : 18 probes during L2 VIP lease transfer
  etcd R/W Quorum   : VERIFIED (ConfigMap write/read/delete succeeded offline)
  Post-Drill Nodes  : 6/6 Ready
==============================================================================
✅ MILESTONE 1.4 PASSED: Control plane survived node loss and recovered!
```
