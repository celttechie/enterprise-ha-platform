# Milestone 3.2: GCP GKE Spot NodePool & Workload Identity Federation

## 1. Overview & Objective
Milestone 3.2 expands the **Phase 3 (Ephemeral GCP GKE Module: Parity & Free Tier)** implementation by provisioning an elastic, production-grade worker compute tier. 

In strict alignment with [ADR-0003: Multi-Cloud Abstraction and Spot Cost Guardrails](../adr/0003-multi-cloud-abstraction-and-spot-cost-guardrails.md) and our [Security Architecture Model](../security/security-model.md), this milestone delivers:
- **Spot Virtual Machine Pricing**: 60–91% compute savings utilizing Google Cloud Spot VMs (`e2-medium` / `e2-standard-2`), lowering running cluster costs to **~$0.007/hour per node**.
- **Elastic Autoscaling**: Node pool dynamically scales between 1 and 4 nodes based on pending pod resource requests.
- **Dedicated Least-Privilege IAM**: A dedicated service account (`google_service_account.gke_nodes`) replacing the default Google Compute Engine service account to prevent unauthorized privilege escalation.
- **Workload Identity Node Metadata Configuration**: Configures `workload_metadata_config { mode = "GKE_METADATA" }` on the node pool, intercepting metadata server calls and enabling Kubernetes pods to securely assume Google Cloud IAM roles without static keys.
- **Shielded VM Hardening**: Enables Secure Boot and Integrity Monitoring on all worker nodes.

---

## 2. Architecture & Design Decisions

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GCP GKE SPOT NODEPOOL ARCHITECTURE (M3.2)                │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. Dedicated Least-Privilege IAM (infra/modules/gcp-gke/iam.tf)             │
│    • google_service_account.gke_nodes (custom, zero broad permissions)      │
│    • roles/logging.logWriter                                                │
│    • roles/monitoring.metricWriter                                          │
│    • roles/monitoring.viewer                                                │
│    • roles/artifactregistry.reader                                          │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. Spot Compute NodePool (infra/modules/gcp-gke/nodepool.tf)                 │
│    • google_container_node_pool.spot_nodes                                  │
│    • spot = true (60-91% cost savings)                                      │
│    • machine_type = "e2-medium" (balanced general-purpose compute)          │
│    • autoscaling: min=1, max=4, initial=2                                   │
│    • workload_metadata_config { mode = "GKE_METADATA" } (Pod Workload ID)   │
│    • shielded_instance_config: secure_boot + integrity_monitoring           │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. Environment Wiring (infra/environments/gcp)                              │
│    • Pass node pool sizing, instance type, and disk configurations          │
│    • Outputs: node_pool_id, node_service_account_email                      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Spot VM Economics & Preemption Handling
Spot VMs on Google Cloud offer identical compute, memory, and performance characteristics to standard on-demand VMs at a fraction of the cost:
* **Cost Difference**:
  * On-Demand `e2-medium`: ~$0.0335 / hour (~$24.46 / month).
  * Spot `e2-medium`: ~$0.0070 / hour (~$5.11 / month) — **~79% savings**.
* **Preemption Resilience**: GKE receives a 25-second preemption termination notice from Google Compute Engine. GKE's node controller automatically cordons the node, initiates graceful pod termination, and schedules replacement pods onto surviving nodes.

### 2.2 Dedicated Node Service Account vs. Default Compute SA
Google Compute Engine defaults to assigning the over-privileged `Editor` role to the default Compute Engine service account (`<project-number>-compute@developer.gserviceaccount.com`).
Milestone 3.2 enforces defense-in-depth by creating a dedicated service account (`enterprise-ha-gke-node-sa`) with strictly bounded permissions:
1. `roles/logging.logWriter`: Writing container and system logs to Cloud Logging.
2. `roles/monitoring.metricWriter`: Exporting node and pod metrics to Cloud Monitoring.
3. `roles/monitoring.viewer`: Querying monitoring endpoints.
4. `roles/artifactregistry.reader`: Pulling container images from Artifact Registry without public access.

### 2.3 Workload Identity Node Metadata Server (`GKE_METADATA`)
Workload Identity requires that the node metadata server runs on every worker node:
* **Setting**: `workload_metadata_config { mode = "GKE_METADATA" }`.
* **Mechanism**: When a container inside a pod queries the metadata server (`http://metadata.google.internal`), the GKE metadata server intercepts the request, validates the Pod's Kubernetes ServiceAccount identity against the Workload Identity pool (`<project_id>.svc.id.goog`), and returns a temporary Google Cloud OAuth token for the bound Google Service Account.

---

## 3. Configuration & Outputs Reference

### 3.1 Module Inputs
| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `node_machine_type` | `string` | `"e2-medium"` | Worker node machine type |
| `node_desired_size` | `number` | `2` | Initial desired worker node count |
| `node_min_size` | `number` | `1` | Minimum worker node count for autoscaling |
| `node_max_size` | `number` | `4` | Maximum worker node count for autoscaling |
| `node_disk_size_gb` | `number` | `30` | Balanced SSD persistent disk size per node |

### 3.2 Module Outputs
| Output | Description |
| :--- | :--- |
| `node_pool_id` | Unique resource identifier for the Spot NodePool |
| `node_pool_name` | Name of the Spot NodePool (`enterprise-ha-gke-spot-pool`) |
| `node_service_account_email` | Service account email attached to worker node instances |

---

## 4. Verification & Validation
1. **OpenTofu Validation**: Verified via `tofu init -backend=false` and `tofu validate` in `infra/environments/gcp`.
2. **OpenTofu Plan Evaluation**: Executed `tofu plan` against live Google Cloud APIs, confirming 9 resources planned:
   - Custom VPC & Subnetwork
   - Zonal GKE Cluster
   - Dedicated Node Service Account + 4 IAM Role Memberships
   - Spot Compute NodePool
3. **CI Pipeline Integration**: Added automated regression checks in `tests/test_sanity.py` ensuring all files exist and validation passes.
