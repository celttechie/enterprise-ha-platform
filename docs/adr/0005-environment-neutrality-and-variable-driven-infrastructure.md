# ADR 0005: Environment Neutrality and Variable-Driven Infrastructure

* **Status:** Accepted
* **Date:** 2026-11-03
* **Deciders:** Platform Engineering Team

---

## 1. Context and Problem Statement
Infrastructure repositories frequently risk leaking private hardware identities, internal hostnames, and local network IP addresses into version control. In a multi-cloud or open-source context, hardcoding host-specific parameters binds the code to a single machine and poses security and privacy risks.

---

## 2. Decision Drivers
* **Portability:** Code must be clonable and executable by any engineer on any standard Linux KVM host without modification.
* **Privacy & Zero-Leakage:** Zero personal hostnames, server models, or private network IPs in git history or tracked files.
* **Declarative Configuration:** All target-specific attributes (URI, bridge names, MAC allocations, storage pools) must be externalized into variables.

---

## 3. Considered Options
* **Option A: Hardcoded Local Paths/URIs:** Convenient for local rapid prototyping, but violates security standards and leaks private topology.
* **Option B: Environment-Specific Git Branches:** Separate branches for home vs. cloud. (Rejected: High merge friction and branch drift).
* **Option C: Variable-Driven Abstraction with Generic Defaults:**
  * Generic module names (`infra/modules/kvm-cluster`, `infra/environments/local-kvm`).
  * Generic variable defaults (`libvirt_uri = "qemu:///system"`).
  * Host-specific connection URIs, storage pools, and network bridges injected via `terraform.tfvars` (which is strictly `.gitignore`d).
  * Sanitized `terraform.tfvars.example` provided as an illustrative template.

---

## 4. Decision Outcome
**Chosen Option:** Option C (Variable-Driven Abstraction).

### Positive Consequences:
* The codebase is 100% portable across different hypervisors.
* Public Git history contains zero trace of internal hardware topology.
* Conforms with enterprise security and SOC2 compliance standards for infrastructure code.

### Negative Consequences / Trade-offs:
* Requires developers to copy `terraform.tfvars.example` to `terraform.tfvars` when targeting remote hypervisors over SSH.
