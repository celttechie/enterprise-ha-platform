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
