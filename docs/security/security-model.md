# Security & Least-Privilege Architecture Model

This document outlines the security posture, secret handling policies, and identity federation models applied across all environments in this template.

---

## 1. Zero Secret Leakage Policy

* **No Credentials in Git:** API keys, AWS access keys, GCP service account JSONs, SSH private keys, and Kubeconfigs must **never** be checked into version control.
* **Pre-Commit Enforcement:** Local `.pre-commit-config.yaml` runs `gitleaks` on every commit attempt.
* **CI Gate:** GitHub Actions executes a full-repository Gitleaks scan on every pull request.
* **Environment Injection:** Sensitive parameters are supplied exclusively via environment variables (`TF_VAR_*`), AWS Secrets Manager, or ephemeral local `.env` files (which are explicitly ignored in `.gitignore`).

---

## 2. Cloud Identity Federation (No Static Service Account Keys)

To adhere to defense-in-depth and zero-trust principles, this platform strictly avoids static cloud credentials inside pods:

| Environment | Identity Federation Pattern | Implementation |
| :--- | :--- | :--- |
| **AWS EKS** | EKS Pod Identity / IRSA (IAM Roles for Service Accounts) | Pods assume short-lived AWS STS tokens via OIDC federation. |
| **GCP GKE** | GKE Workload Identity Federation | K8s service accounts map directly to Google Cloud IAM Service Accounts without JSON keys. |
| **Local KVM Hypervisor** | SSH Key Isolation / Bastion Access | Host administration is restricted to private hypervisor network interfaces. |

---

## 3. Kubernetes Workload Hardening

All containerized workloads deployed to the platform adhere to the **Kubernetes Restricted Pod Security Standard**:
* `readOnlyRootFilesystem: true`
* `allowPrivilegeEscalation: false`
* `runAsNonRoot: true`
* Capabilities dropped: `ALL` (explicitly adding only required network capabilities if necessary)
* Strict `NetworkPolicies` isolating ingress, application, and database tiers.

---

## 4. AWS EKS Secrets & Key Management Architecture

In the AWS EKS cloud environment, deterministic secret handling and least-privilege key management are enforced across four distinct infrastructure layers:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       AWS EKS SECURITY & SECRETS LAYERS                     │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. Cluster Secrets at Rest (KMS Envelope Encryption)                        │
│    • Dedicated AWS KMS CMK (aws_kms_key.eks_secrets) with annual rotation   │
│    • All Kubernetes Secret objects in etcd are envelope-encrypted           │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. Worker Node Access (Keyless SSM & Deterministic KeyPair)                 │
│    • Primary: AWS Systems Manager (SSM) Session Manager (zero open port 22) │
│    • Fallback: OpenTofu tls_private_key (ED25519) stored in AWS Secrets     │
│      Manager (zero workstation sprawl or disk leakage)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. Pod & Workload Identity (Zero Long-Lived API Keys)                       │
│    • AWS IAM OIDC Provider (aws_iam_openid_connect_provider) for IRSA       │
│    • Pods project short-lived (1-hour) STS assume-role tokens               │
├─────────────────────────────────────────────────────────────────────────────┤
│ 4. Kubeconfig & Administrative Access                                       │
│    • Zero static admin certificates or long-lived tokens on disk            │
│    • Short-lived IAM bearer tokens generated via 'aws eks get-token'        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Layer 1: Cluster Secrets at Rest (AWS KMS Envelope Encryption)
* **KMS CMK:** A dedicated AWS KMS Customer Managed Key (`aws_kms_key.eks_secrets`) with automatic key rotation enabled (`enable_key_rotation = true`).
* **EKS Integration:** Attached via the `encryption_config` block in `aws_eks_cluster`, targeting `resources = ["secrets"]`.
* **Security Outcome:** All Kubernetes Secret objects stored in EKS `etcd` are envelope-encrypted at the hardware level, protecting sensitive workload configs against physical or snapshot compromise.

### Layer 2: Worker Node Access (Keyless SSM & Fallback KeyPair)
* **Primary Keyless Access:** Worker nodes are managed keylessly through **AWS Systems Manager (SSM) Session Manager** (`AmazonSSMManagedInstanceCore` policy). Ingress port 22 is completely closed in all security groups.
* **Deterministic Fallback KeyPair:** For emergency out-of-band console access, OpenTofu generates an `ED25519` keypair (`tls_private_key.node_ssh`). The public key is registered in `aws_key_pair.node_key`, and the private key is piped directly into **AWS Secrets Manager** (`aws_secretsmanager_secret.node_ssh_private_key`). Zero private keys are written to workstation disks or version control.

### Layer 3: Workload Identity (IRSA / Pod Identity)
* **OIDC Identity Federation:** The cluster's OIDC issuer URL is registered as an IAM Identity Provider (`aws_iam_openid_connect_provider`).
* **Zero Static Pod Keys:** Pods assume least-privilege IAM roles via Kubernetes ServiceAccount annotations (`eks.amazonaws.com/role-arn`), receiving temporary, 1-hour STS credentials projected directly into pod memory.

### Layer 4: Administrative Kubeconfig Access
* **Dynamic Bearer Tokens:** Cluster administrators and CI pipelines authenticate using short-lived bearer tokens generated on demand via `aws eks get-token` (AWS CLI `v1beta1` credential exec plugin).
* **Zero Static Certs:** Eliminates static client certificates or hardcoded tokens on developer workstations.
