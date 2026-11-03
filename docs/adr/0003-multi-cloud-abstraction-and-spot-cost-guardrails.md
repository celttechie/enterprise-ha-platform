# ADR 0003: Multi-Cloud Abstraction and Spot Cost Guardrails

* **Status:** Accepted
* **Date:** 2026-11-03
* **Deciders:** Platform Engineering Team

---

## 1. Context and Problem Statement
To demonstrate multi-cloud Kubernetes capabilities across AWS, GCP, and local hardware without incurring prohibitive cloud costs (e.g. standard multi-AZ EKS clusters often cost $150+/month), the architecture must enforce strict cost guardrails while maintaining realistic enterprise high availability.

---

## 2. Decision Drivers
* **Cloud Spend Minimization:** AWS and GCP demo runs must cost under $1.00 per test cycle.
* **Architecture Authenticity:** Demonstrations must use real multi-AZ failure domains, Spot node pricing, and native CSI/Ingress integrations.
* **Multi-Cloud Parity:** IaC must cleanly abstract the underlying cloud while keeping Kubernetes platform and application manifests 100% provider-agnostic.

---

## 3. Considered Options
* **Option A: 24/7 Managed Cloud Clusters:** Run EKS and GKE continuously. (Rejected: $150–$250/month in idle cloud spend).
* **Option B: Pure Local Simulation (KinD / Minikube):** Emulate everything in Docker on a single laptop. (Rejected: Lacks real cloud IAM, multi-AZ failure domains, and cloud-native CSI storage drivers).
* **Option C: Hybrid Model (Local KVM 24/7 + Ephemeral Cloud Spot with Guardrails):**
  * Local KVM hypervisor runs at $0 cloud spend for continuous iteration, Longhorn replication, and failure drills.
  * AWS and GCP clusters are ephemeral: stood up on Spot instances with single shared NAT gateways for 1–2 hour test runs, automated teardown, and $5.00 AWS Budget alarms.

---

## 4. Decision Outcome
**Chosen Option:** Option C (Hybrid Model).

### Positive Consequences:
* Zero ongoing monthly cloud bills.
* Demos on AWS EKS and GCP GKE cost pennies per execution.
* Real cloud IAM (AWS EKS Pod Identity / GCP Workload Identity) is validated in actual cloud environments.

### Negative Consequences / Trade-offs:
* Cloud demos require a ~10-minute spin-up time (`tofu apply`) before testing can begin.
