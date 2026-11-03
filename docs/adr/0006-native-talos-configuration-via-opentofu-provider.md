# ADR 0006: Native Declarative Talos Configuration & Lifecycle via OpenTofu Provider

* **Status:** Accepted
* **Date:** 2026-11-03
* **Deciders:** Platform Engineering Team
* **Supersedes:** Imperative shell script generator pattern (`generate-ha-configs.sh`) and manual `talosctl` bootstrap steps

---

## 1. Context and Problem Statement
When deploying Talos Linux clusters, node configurations (`controlplane.yaml`, `worker.yaml`) and client credentials (`talosconfig`) must be generated with specific network, storage, and CNI configurations (e.g., Layer-2 Virtual IP, Cilium eBPF disabling default Flannel/kube-proxy, secondary Longhorn disk partitioning). Furthermore, once VMs boot in maintenance mode, configurations must be applied over mTLS, etcd quorum bootstrapped on the control plane, and administrative `kubeconfig` retrieved.

Initially, an external shell script (`generate-ha-configs.sh`) and manual CLI steps (`talosctl apply-config`, `talosctl bootstrap`, `talosctl kubeconfig`) were used. However, relying on custom shell scripts and manual CLI operations fractures the IaC lifecycle, requires external CLI binaries (`talosctl`), and violates the contract that each infrastructure environment (`infra/environments/*`) should independently emit a ready-to-use `kubeconfig`.

---

## 2. Decision Drivers
* **Declarative Consistency & Single-Command Standup:** All infrastructure definition, configuration rendering, node delivery, and etcd bootstrapping must be executed through standard `tofu apply`.
* **Zero Host Tool Dependencies:** Eliminates the requirement to have `talosctl` installed on the host machine running OpenTofu.
* **Environment Output Contract Alignment:** Matches AWS EKS and GCP GKE environments by having `infra/environments/local-kvm` directly output a functioning Kubernetes cluster and `kubeconfig`.
* **Secure PKI Lifecycle:** Manage cluster secrets (PKI, CA, bootstrap tokens) securely inside OpenTofu state rather than dropping plaintext secrets files into the workspace directory.
* **Hermetic & GitOps Friendly:** Patches and parameters (e.g., `controlplane_vip`) are validated at plan time via typed variables rather than runtime string substitution.

---

## 3. Considered Options
* **Option A: Imperative Shell Scripting & Manual CLI Steps:**
  * Uses `sed` to replace `${CONTROLPLANE_VIP}` in template files.
  * Relies on developer running manual `talosctl apply-config`, `talosctl bootstrap`, and `talosctl kubeconfig`.
  * *Drawbacks:* Requires `talosctl` binary; writes unencrypted secrets to disk; cannot be planned or validated natively by OpenTofu.
* **Option B: Full End-to-End Native OpenTofu Provider (`siderolabs/talos`):**
  * Uses the official `siderolabs/talos` provider.
  * Generates PKI in state via `talos_machine_secrets`.
  * Generates configurations via `data.talos_machine_configuration` with inline typed `config_patches`.
  * Applies configs directly over port 50000 via `talos_machine_configuration_apply`.
  * Bootstraps etcd quorum via `talos_machine_bootstrap`.
  * Emits administrative `kubeconfig` via `talos_cluster_kubeconfig` resource and `local_file.kubeconfig`.

---

## 4. Decision Outcome
**Chosen Option:** Option B (`siderolabs/talos` OpenTofu Provider for full lifecycle).

### Positive Consequences:
* **True Zero-Touch Stand-up:** A single `tofu apply` in `infra/environments/local-kvm` brings up VMs, applies configs, bootstraps etcd, and outputs a valid `kubeconfig`.
* **No `talosctl` Requirement for IaC:** OpenTofu compiles certificates, communicates over gRPC (port 50000), and handles the cluster lifecycle natively.
* **Safe Secrets Handling:** Cluster PKI is tracked in OpenTofu state, protected by backend encryption and state locking.
* **Identical Substrate Interface:** Tier 2 (`platform/`) can consume `infra/environments/local-kvm/kubeconfig` identically to how it will consume AWS EKS or GCP GKE kubeconfigs.

### Negative Consequences / Trade-offs:
* OpenTofu state file contains sensitive cluster PKI (state must be protected and never committed to version control).

---

## 5. Compliance & Verification
* `infra/environments/local-kvm/talos.tf` implements:
  - `talos_machine_secrets`
  - `data.talos_machine_configuration` (control plane & worker)
  - `talos_machine_configuration_apply` (control plane & worker)
  - `talos_machine_bootstrap`
  - `talos_cluster_kubeconfig`
  - `local_file.kubeconfig`
* No shell scripts exist in `infra/environments/local-kvm/talos/scripts/`.
* `tofu validate` and `pytest` verify that provider resolution, configuration generation, and bootstrap resources are valid.
