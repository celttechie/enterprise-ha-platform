# Milestone 2.3: AWS Load Balancer Controller (ALB/NLB) & Amazon EBS CSI Driver

* **Status:** Complete & Validated (OpenTofu Pod Identity Associations, StorageClass, and Helm Values Configured)
* **Target Environment:** `aws` (AWS EKS v1.31 / AWS LBC / Amazon EBS CSI Driver / EKS Pod Identity)
* **Architecture References:** [ADR-0002: Decoupled Monorepo Tiering](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0002-decoupled-monorepo-tiering.md), [ADR-0003: Multi-Cloud Abstraction and Spot Cost Guardrails](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0003-multi-cloud-abstraction-and-spot-cost-guardrails.md), [Security & Least-Privilege Architecture Model](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/security/security-model.md)
* **Date:** 2026-11-07

---

## 1. Objective & Problem Solved

Following the successful provisioning and verification of the foundational Multi-AZ network (M2.1) and EC2 Spot compute capacity (M2.2), **Milestone 2.3** establishes the critical Kubernetes Platform Ingress and Storage services for AWS EKS:

1. **Enterprise Layer 7 Ingress (AWS Load Balancer Controller):** Eliminates static or third-party proxy nodes by automatically provisioning AWS Application Load Balancers (ALBs) for HTTP/HTTPS Ingress and Network Load Balancers (NLBs) for TCP/UDP services, discovering public subnets via `kubernetes.io/role/elb = 1`.
2. **Dynamic Encrypted Block Storage (Amazon EBS CSI Driver):** Enables Kubernetes workloads to dynamically provision encrypted `gp3` block storage volumes with zero manual intervention, envelope-encrypted with our dedicated AWS KMS key.
3. **Keyless IAM Authorization (EKS Pod Identity):** Integrates both controllers using `aws_eks_pod_identity_association`, granting least-privilege IAM permissions via short-lived STS tokens directly to Kubernetes ServiceAccounts with zero static cloud credentials inside pods.

---

## 2. Architecture & File Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            AWS EKS PLATFORM SERVICES                        │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. AWS Load Balancer Controller (platform/ingress/aws-lbc)                  │
│    • Ingress -> Application Load Balancers (ALB) across Public Subnets      │
│    • Service LoadBalancer -> Network Load Balancers (NLB)                   │
│    • IAM Role via EKS Pod Identity (aws-load-balancer-controller)           │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. Amazon EBS CSI Driver (infra/modules/aws-eks/ebs_csi.tf)                 │
│    • Managed EKS Addon (aws-ebs-csi-driver)                                 │
│    • Dynamic volume provisioning via StorageClass gp3-encrypted             │
│    • Hardware encryption via KMS Key (aws_kms_key.eks_secrets)              │
│    • IAM Role via EKS Pod Identity (ebs-csi-controller-sa)                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

* **Module `infra/modules/aws-eks/`:**
  * [`ebs_csi.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/ebs_csi.tf): Defines `aws_iam_role.ebs_csi`, `aws_eks_pod_identity_association.ebs_csi`, KMS key grant policy, and `aws_eks_addon.ebs_csi`.
  * [`lbc_iam.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/lbc_iam.tf): Defines `aws_iam_role.aws_lbc`, custom `aws_iam_policy.aws_lbc` with complete ALB/NLB permissions, and `aws_eks_pod_identity_association.aws_lbc`.
  * [`outputs.tf`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/aws-eks/outputs.tf): Exports `ebs_csi_role_arn`, `lbc_role_arn`, and `addon_ebs_csi_arn`.

* **Platform Layer `platform/`:**
  * [`platform/storage/ebs-csi/storageclass.yaml`](file:///home/bjarrett/Projects/enterprise-ha-platform/platform/storage/ebs-csi/storageclass.yaml): Default `gp3-encrypted` StorageClass with `WaitForFirstConsumer` volume binding.
  * [`platform/ingress/aws-lbc/values.yaml`](file:///home/bjarrett/Projects/enterprise-ha-platform/platform/ingress/aws-lbc/values.yaml): Production Helm values for AWS Load Balancer Controller with Multi-AZ topology spread.

* **Automation & Operations:**
  * [`Makefile`](file:///home/bjarrett/Projects/enterprise-ha-platform/Makefile): Enhanced `make deploy-platform TARGET=aws` to apply the `gp3-encrypted` StorageClass and install the AWS Load Balancer Controller Helm chart.

---

## 3. Security & IAM Governance

Both controllers follow the project's **Zero Secret Leakage Policy**:
* **AWS Load Balancer Controller:** Assumes `aws_iam_role.aws_lbc` strictly through the EKS Pod Identity Agent (`pods.eks.amazonaws.com`). The controller creates target groups and ALBs in the VPC without access to workstation credentials or static access keys.
* **Amazon EBS CSI Driver:** Assumes `aws_iam_role.ebs_csi` through Pod Identity. Volume creation requests are authenticated against KMS, generating KMS data keys dynamically for volume envelope encryption.

---

## 4. Verification & Validation

1. **OpenTofu Validation:** Ran `tofu fmt -check -recursive infra/` and `tofu validate` on `infra/environments/aws` (passed with code 0).
2. **CI Quality Gates:** `make ci` passed all linters (`yamllint`, `flake8`) and unit tests.
3. **Execution Plan:** `make plan TARGET=aws` verified all added IAM roles, policies, Pod Identity associations, and the EBS CSI managed addon (**50 resources to add**).
