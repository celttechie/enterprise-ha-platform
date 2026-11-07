# Milestone 2.2: EC2 Spot Managed NodeGroup with AWS Pod Identity / IRSA

* **Status:** Complete & Validated (OpenTofu Spot NodeGroup, Managed Addons, and Dry-Run Verified)
* **Target Environment:** `aws` (AWS EKS v1.31 / EC2 Spot Instances / EKS Managed Addons)
* **Architecture References:** [ADR-0003: Multi-Cloud Abstraction and Spot Cost Guardrails](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0003-multi-cloud-abstraction-and-spot-cost-guardrails.md), [ADR-0008: Single Shared NAT Gateway for Ephemeral Cloud Testbeds](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0008-single-shared-nat-gateway-for-ephemeral-cloud-testbeds.md), [Security & Least-Privilege Architecture Model](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/security/security-model.md)
* **Date:** 2026-11-07

---

## 1. Objective & Problem Solved

Following the successful provisioning, live verification, and clean teardown of the EKS control plane and Multi-AZ VPC network in Milestone 2.1, **Milestone 2.2** introduces compute capacity and modern identity federation to the AWS EKS environment:

1. **Spot Instance Compute Pool (ADR-0003):** Worker compute accounts for the vast majority of running Kubernetes costs in public cloud. Milestone 2.2 provisions an `aws_eks_node_group` utilizing **EC2 Spot instances (`capacity_type = "SPOT"`)**, delivering **70–90% cost savings** over on-demand pricing.
2. **Capacity Diversification:** Spot instances can be reclaimed if capacity is scarce. By defining a diversified instance type pool (`["t3.medium", "t3a.medium"]`), EKS automatically provisions equivalent AMD or Intel instances across multi-AZ private subnets, preventing Spot allocation failures.
3. **Managed EKS Addons & Pod Identity:** Declarative lifecycle management of core cluster networking components (`vpc-cni`, `kube-proxy`, `coredns`) and the modern `eks-pod-identity-agent` addon, enabling frictionless, keyless workload authentication without long-lived static cloud keys.

---

## 2. Architecture & File Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            AWS EKS CLUSTER                                  │
│                                                                             │
│  ┌─────────────────────── Managed EKS Addons ────────────────────────────┐  │
│  │ • vpc-cni (AWS VPC CNI networking)                                    │  │
│  │ • kube-proxy (Service routing)                                        │  │
│  │ • coredns (In-cluster DNS resolution)                                 │  │
│  │ • eks-pod-identity-agent (Modern pod-to-IAM role federation)          │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │                                      │
│  ┌───────────────────────────────────▼───────────────────────────────────┐  │
│  │             EC2 Spot Managed Node Group (capacity_type = SPOT)        │  │
│  │  • Multi-AZ Private Subnets (us-east-2a, us-east-2b, us-east-2c)      │  │
│  │  • Diversified Types: ["t3.medium", "t3a.medium"] (2 vCPU / 4 GB)     │  │
│  │  • Sizing: Min 1, Desired 2, Max 4 (max_unavailable = 1)             │  │
│  │  • Security: Zero open port 22, AWS Systems Manager (SSM) enabled     │  │
│  │  • Cost: ~$0.025/hr for 2 nodes (vs $0.083/hr on-demand)              │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

* **Module `infra/modules/aws-eks/`:**
  * [`variables.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/variables.tf): Parameterized `node_instance_types`, `node_capacity_type`, `node_desired_size`, `node_min_size`, `node_max_size`, `node_disk_size`, and `enable_pod_identity_agent`.
  * [`nodegroup.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/nodegroup.tf): Implements `aws_eks_node_group.spot` across private subnets, with rolling update guardrails (`max_unavailable = 1`), spot labels (`role=worker`, `capacity-type=spot`), and cluster autoscaler tags.
  * [`addons.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/addons.tf): Implements managed addons for `vpc-cni`, `kube-proxy`, `coredns`, and `eks-pod-identity-agent` with overwrite conflict resolution.
  * [`outputs.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/outputs.tf): Exports node group ID, ARN, status, and addon ARNs.

* **Environment `infra/environments/aws/`:**
  * [`main.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/aws/main.tf), [`variables.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/aws/variables.tf), [`outputs.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/aws/outputs.tf), and [`terraform.tfvars.example`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/aws/terraform.tfvars.example).

---

## 3. Cost Profile & Economic Analysis

| Component | Sizing / Strategy | Hourly Rate | 30-Min Demo Cost |
| :--- | :--- | :---: | :---: |
| **EKS Control Plane** | AWS Managed v1.31 | $0.100 | $0.050 |
| **NAT Gateway (ADR-0008)** | 1 Shared Gateway in `us-east-2a` | $0.045 | $0.0225 |
| **Worker Compute (Spot)** | 2x `t3.medium` Spot Instances | **$0.025** | **$0.0125** |
| *(Worker Compute On-Demand)* | *(2x t3.medium On-Demand)* | *($0.083)* | *($0.0415)* |
| **Total Running Cluster** | **Control Plane + NAT + 2 Spot Nodes** | **~$0.170/hr** | **~$0.085 (< 9 cents)** |

---

## 4. Verification & Validation

1. **Static Linting & Format:** `tofu fmt -check -recursive infra/` verified clean syntax.
2. **OpenTofu Validation:** `tofu init -backend=false` and `tofu validate` passed with code 0 on `infra/environments/aws`.
3. **CI Test Suite:** `make ci` passed 100% (including `yamllint`, `flake8`, OpenTofu format, and all 5 unit tests in `tests/test_sanity.py`).
4. **Cloud Execution Plan:** `make plan TARGET=aws` verified the creation of:
   - `aws_eks_node_group.spot`
   - `aws_eks_addon.vpc_cni`
   - `aws_eks_addon.kube_proxy`
   - `aws_eks_addon.coredns`
   - `aws_eks_addon.pod_identity_agent`
   - Total plan: **45 to add, 0 to change, 0 to destroy**.
