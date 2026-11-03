# ADR 0002: Decoupled Monorepo Architecture for Multi-Cloud Platform

* **Status:** Accepted
* **Date:** 2026-11-03
* **Deciders:** Platform Engineering Team

---

## 1. Context and Problem Statement
When developing a platform that supports multiple environments (local KVM hypervisor, AWS EKS, and GCP GKE), should the Infrastructure as Code (IaC), Kubernetes platform services (GitOps add-ons), and demo workloads be stored across multiple independent Git repositories (Polyrepo) or unified within a single repository (Monorepo)?

---

## 2. Decision Drivers
* **Clonability & Evaluation:** External users, hiring managers, and engineers must be able to clone the project and stand up a working demonstration in minutes without managing multi-repo sync.
* **Separation of Concerns:** Must model real enterprise team boundaries (Infra vs. Platform vs. Application).
* **Version Drift:** Changes in infrastructure outputs (e.g., OIDC issuer ARNs, subnet tags) must not break platform manifests due to mismatched commits.
* **Testing & CI:** Pull requests must validate end-to-end integration across tiers in a single pipeline.

---

## 3. Considered Options
* **Option A: Polyrepo (3 Repositories):** `repo-infra`, `repo-platform-services`, `repo-workloads`.
* **Option B: Coupled Monorepo:** Everything mixed into one top-level folder with Terraform invoking Helm and Kubernetes manifests directly in a single state file.
* **Option C: Decoupled Monorepo (Three-Tiered):** A single Git repository with strict directory isolation:
  * `infra/`: OpenTofu modules and per-environment roots.
  * `platform/`: Provider-agnostic Kubernetes manifests/Helm charts.
  * `workloads/`: Applications, KEDA ScaledObjects, and load generators.

---

## 4. Decision Outcome
**Chosen Option:** Option C (Decoupled Monorepo).

The repository adopts a strict three-tier layout. Tiers are coordinated through the root `Makefile` and automation scripts, but maintain clean boundaries.

### Positive Consequences:
* **Atomic Versioning:** Every Git commit represents a fully validated, mutually compatible snapshot of Infrastructure, Platform, and Applications.
* **Zero Cross-Repo Friction:** One `git clone` gives the user everything needed to run `make doctor` and `make deploy`.
* **Future Extractability:** If an enterprise demands migrating `infra/` to a corporate central repo, the directory is completely self-contained and easily split.

### Negative Consequences / Trade-offs:
* CI pipeline must be smart enough to filter which tests run based on modified paths (`infra/**` vs. `platform/**`).
