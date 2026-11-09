# Milestone 3.1: Ephemeral GCP GKE Module & Custom VPC ($0 Management Fee)

## 1. Overview & Objective
Milestone 3.1 initiates **Phase 3 (Ephemeral GCP GKE Module: Parity & Free Tier)**. Following the successful delivery of Phase 1 (Local KVM) and Phase 2 (Ephemeral AWS EKS with Cost Guardrails), this milestone establishes Google Cloud GKE infrastructure designed for zero ongoing idle management fees and strict multi-cloud environment neutrality (as codified in [ADR-0003](../adr/0003-multi-cloud-abstraction-and-spot-cost-guardrails.md) and [ADR-0005](../adr/0005-environment-neutrality-and-variable-driven-infrastructure.md)).

Key deliverables include:
- **Custom VPC Network & Subnetting**: A non-default VPC (`auto_create_subnetworks = false`) featuring dedicated secondary CIDR ranges for VPC-native alias IP routing.
- **Zonal GKE Cluster (`google_container_cluster`)**: Deployed to `us-central1-a` to qualify for Google Cloud's **1 free zonal cluster management fee waiver per billing account**, saving $74.40/month.
- **Workload Identity Federation**: Configured with `workload_identity_config` (`${var.project_id}.svc.id.goog`), allowing Kubernetes ServiceAccounts to authenticate directly to Google Cloud APIs without static JSON service account keys.
- **Cost & Ephemeral Guardrails**: Immediate removal of the default node pool upon creation (`remove_default_node_pool = true`), and deletion protection disabled (`deletion_protection = false`) for rapid automated teardown via `make destroy TARGET=gcp`.

---

## 2. Architecture & Design Decisions

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GCP GKE INFRASTRUCTURE (MILESTONE 3.1)                   │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. Custom VPC & Subnetting (infra/modules/gcp-gke/vpc.tf)                   │
│    • Custom VPC (auto_create_subnetworks = false)                           │
│    • Primary Subnetwork: 10.10.0.0/20 (GKE Nodes)                           │
│    • Secondary Range 1: 10.20.0.0/16 (Pod Alias IPs)                        │
│    • Secondary Range 2: 10.30.0.0/20 (Service Cluster IPs)                  │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. Zonal GKE Control Plane (infra/modules/gcp-gke/cluster.tf)               │
│    • Location: Zonal (us-central1-a) -> $0.00 cluster fee waiver            │
│    • remove_default_node_pool = true (instant cleanup of default pool)      │
│    • ip_allocation_policy (VPC-native alias routing)                        │
│    • workload_identity_config (project.svc.id.goog)                         │
│    • deletion_protection = false (enables clean make destroy)               │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. Environment Wiring (infra/environments/gcp)                              │
│    • Provider: hashicorp/google ~> 5.30                                     │
│    • Parameterized project_id, region, zone, cluster_name                   │
│    • Deterministic outputs: endpoint, CA data, cluster_name, vpc_name       │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 The $0 Control Plane Management Fee Waiver
Unlike AWS EKS ($0.10/hr = ~$73/mo flat fee) or multi-zone/regional GKE clusters, Google Cloud provides one zonal GKE cluster per billing account free of cluster management fees:
* **Selected Zone**: `us-central1-a` (configurable via `gcp_zone`).
* **Cost Impact**: $0.00/month control plane management fee.
* **Failure Domain**: While a regional cluster distributes the control plane across three zones, ephemeral testbeds prioritize zero idle costs and rapid standup/teardown.

### 2.2 VPC-Native IP Routing (Alias IPs)
Traditional overlay networks add encapsulation overhead and complicate cloud-native load balancing. The GCP GKE module uses VPC-native IP aliasing:
* **Primary Range**: `10.10.0.0/20` (Node instances)
* **Secondary Range `pods`**: `10.20.0.0/16` (Kubernetes Pod IPs directly routable within the VPC)
* **Secondary Range `services`**: `10.30.0.0/20` (Kubernetes Service ClusterIPs)

### 2.3 Workload Identity Federation
In compliance with our [Security Architecture Model](../security/security-model.md):
* **OIDC Integration**: The cluster is configured with `workload_pool = "${var.project_id}.svc.id.goog"`.
* **Zero Static Keys**: Workloads assume Google Service Accounts (GSAs) by annotating Kubernetes ServiceAccounts (`KSAs`) with `iam.gke.io/gcp-service-account`, eliminating static JSON credential files.

### 2.4 Ephemeral Teardown Safeguards
To prevent common OpenTofu destroy failures on GKE:
* `deletion_protection = false`: Allows single-command automated destruction (`make destroy TARGET=gcp`) without console intervention.
* `remove_default_node_pool = true`: Guarantees standard, non-Spot machines are not inadvertently left running.

---

## 3. Configuration & Outputs Reference

### 3.1 Module Inputs
| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `project_id` | `string` | *(Required)* | Target GCP project ID |
| `region` | `string` | `"us-central1"` | GCP region |
| `zone` | `string` | `"us-central1-a"` | GCP zone (qualifies for free management waiver) |
| `cluster_name` | `string` | `"enterprise-ha-gke"` | GKE cluster name |
| `network_name` | `string` | `"enterprise-ha-gke-vpc"` | VPC network name |
| `subnetwork_name` | `string` | `"enterprise-ha-gke-subnet"` | Subnet name |
| `primary_ip_cidr_range`| `string` | `"10.10.0.0/20"` | Subnet CIDR for worker nodes |
| `pod_ip_cidr_range` | `string` | `"10.20.0.0/16"` | Secondary CIDR for Pod alias IPs |
| `service_ip_cidr_range`| `string` | `"10.30.0.0/20"` | Secondary CIDR for Service ClusterIPs |
| `enable_workload_identity` | `bool` | `true` | Workload Identity pool integration |
| `deletion_protection` | `bool` | `false` | Ephemeral teardown guardrail |

### 3.2 Module Outputs
| Output | Description |
| :--- | :--- |
| `cluster_name` | Name of the GKE cluster |
| `cluster_id` | Full resource identifier |
| `cluster_endpoint` | Endpoint IP of the Kubernetes API server |
| `cluster_ca_certificate`| Base64 encoded CA certificate (sensitive) |
| `location` | Control plane zone (`us-central1-a`) |
| `network_name` | Name of the VPC network |
| `subnetwork_name` | Name of the node subnetwork |

---

## 4. Verification & Validation
1. **OpenTofu Formatting**: Validated via `tofu fmt -check -recursive infra/`.
2. **OpenTofu Validation**: Verified via `tofu init -backend=false` and `tofu validate` in `infra/environments/gcp` (syntax, resource schema, and module arguments validated).
3. **CI Pipeline Integration**: Added automated regression checks in `tests/test_sanity.py` ensuring all GCP GKE files exist and OpenTofu validation passes.
