# Milestone 2.1: Ephemeral AWS EKS Module with Cost Guardrails

* **Status:** Complete & Validated (OpenTofu Module & Multi-AZ VPC Architecture Ready)
* **Target Environment:** `aws` (AWS EKS v1.31 / Multi-AZ VPC / KMS Envelope Encryption)
* **Architecture References:** [ADR-0003: Multi-Cloud Abstraction and Spot Cost Guardrails](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0003-multi-cloud-abstraction-and-spot-cost-guardrails.md), [ADR-0008: Single Shared NAT Gateway for Ephemeral Cloud Testbeds](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0008-single-shared-nat-gateway-for-ephemeral-cloud-testbeds.md), [Security & Least-Privilege Architecture Model](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/security/security-model.md)
* **Date:** 2026-11-06

---

## 1. Objective & Problem Solved

Following the successful completion and verification of Phase 1 (Local KVM HA Cluster with Talos Linux, Cilium eBPF, Longhorn 3x Storage, and M1.4 Control Plane Quorum Chaos Drill), **Phase 2** initiates the public cloud track of the platform engineering template.

Milestone 2.1 establishes the foundational infrastructure module for **AWS EKS**, engineering an enterprise-grade, Multi-AZ Kubernetes cluster while adhering strictly to:
1. **Aggressive Cost Guardrails (ADR-0008):** Eliminating the standard 3x NAT Gateway tax (~$97.20/month) for ephemeral testbeds by deploying a **Single Shared NAT Gateway** saving 67% on idle baseline egress costs while maintaining full Multi-AZ private subnets.
2. **Deterministic Keys & Secrets Architecture:** Zero long-lived credentials on disk, hardware KMS envelope encryption for Kubernetes Secret objects at rest in etcd, keyless AWS Systems Manager (SSM) Session Manager for worker node administration (port 22 fully closed), and IAM OIDC federation for workload identity (IRSA).
3. **Production Portability:** Designed with clean parameterization (`single_nat_gateway = true/false`, `enable_kms_encryption = true/false`) allowing seamless progression from ephemeral development to high-availability multi-NAT production environments without code duplication.

---

## 2. Architecture & File Layout

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            VPC (10.0.0.0/16)                                │
│                                                                             │
│  ┌─────────────────────── Public Subnets (/24) ──────────────────────────┐  │
│  │  us-east-2a (10.0.1.0/24)    us-east-2b (10.0.2.0/24)  us-east-2c ... │  │
│  │  ┌────────────────────┐                                               │  │
│  │  │ Shared NAT Gateway │ <────── Outbound Egress from all private AZs  │  │
│  │  └─────────┬──────────┘                                               │  │
│  └────────────┼──────────────────────────────────────────────────────────┘  │
│               │                                                             │
│  ┌────────────┼────────── Private Subnets (/24) ─────────────────────────┐  │
│  │            ▼                                                          │  │
│  │  us-east-2a (10.0.10.0/24)  us-east-2b (10.0.20.0/24)  us-east-2c ... │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │ EKS Worker Nodes (Private IP only, Port 22 Closed, SSM Enabled) │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                        ┌──────────────▼──────────────┐
                        │      AWS EKS Cluster        │
                        │ • Kubernetes v1.31          │
                        │ • KMS Envelope Encryption   │
                        │ • IAM OIDC Provider (IRSA)  │
                        │ • CloudWatch Control Plane  │
                        └─────────────────────────────┘
```

* **Module: `infra/modules/aws-eks/`:**
  * [`variables.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/variables.tf): Parameterizes VPC CIDR (`10.0.0.0/16`), 3 AZs (`us-east-2a`, `us-east-2b`, `us-east-2c`), subnets, Kubernetes version (`1.31`), `single_nat_gateway` toggle, and KMS encryption.
  * [`vpc.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/vpc.tf): Implements Multi-AZ VPC with 3 public subnets (`kubernetes.io/role/elb = 1`), 3 private subnets (`kubernetes.io/role/internal-elb = 1`), Internet Gateway, single EIP & NAT Gateway in Public Subnet 1 (toggleable to 3 NATs in production), and route table associations.
  * [`kms.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/kms.tf): Dedicated AWS KMS Customer Managed Key (`aws_kms_key.eks_secrets`) with automatic key rotation and IAM policies for EKS secret envelope encryption.
  * [`iam.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/iam.tf):
    * EKS Control Plane IAM Role (`AmazonEKSClusterPolicy`, `AmazonEKSVPCResourceController`).
    * Worker Node IAM Role with `AmazonSSMManagedInstanceCore` for keyless remote sessions.
    * IAM OIDC Provider (`aws_iam_openid_connect_provider`) for IRSA workload identity.
    * Fallback deterministic `ED25519` keypair archived directly to AWS Secrets Manager (`aws_secretsmanager_secret.node_ssh_private_key`).
  * [`security_groups.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/security_groups.tf): Cluster and worker security groups with zero open port 22 ingress and strict control-plane-to-node rules.
  * [`eks.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/eks.tf): `aws_eks_cluster` resource with control plane logging (`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`), private/public endpoint access, and KMS encryption config.
  * [`outputs.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/outputs.tf): Exposes cluster endpoints, OIDC ARN, KMS ARN, IAM roles, and VPC/subnet IDs.

* **Environment Root: `infra/environments/aws/`:**
  * [`main.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/aws/main.tf): Declares AWS and TLS providers with default tags and invokes `module.aws_eks`.
  * [`variables.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/aws/variables.tf), [`outputs.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/aws/outputs.tf), and [`terraform.tfvars.example`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/aws/terraform.tfvars.example).

---

## 3. Cost Guardrails Analysis (ADR-0008)

| Metric | Multi-NAT (Standard AWS Architecture) | Single Shared NAT (This Module) | Savings |
| :--- | :---: | :---: | :---: |
| **NAT Gateways** | 3 | **1** | -67% |
| **Baseline Cost / Hour** | $0.135 | **$0.045** | -$0.09/hr |
| **Baseline Cost / Month** | $97.20 | **$32.40** | **-$64.80/mo** |
| **4-Hour Ephemeral Demo Run** | $0.54 | **$0.18** | **-$0.36** |
| **Private Subnet Multi-AZ Isolation** | Maintained | **Maintained** | Parity |

---

## 4. Verification & Validation

The module and environment roots were validated using static analysis, OpenTofu syntax and schema validation, and sanity assertions:
1. `tofu fmt -check -recursive infra/`: Validated formatting across all module and environment files.
2. `tofu init -backend=false` & `tofu validate`: Validated OpenTofu schema and configuration integrity for `infra/environments/aws`.
3. `make ci`: Comprehensive CI validation running `yamllint`, `flake8`, OpenTofu formatting checks, and `pytest`.
