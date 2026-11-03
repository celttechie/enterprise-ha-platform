# Milestone 1.1: Local KVM 6-Node HA Cluster Module

* **Status:** Verified & Complete
* **Target Environment:** `local-kvm` (Libvirt / KVM / Talos Linux)
* **Date:** 2026-11-03

---

## 1. Objective & Problem Solved
Provision a realistic, 6-node virtual Kubernetes infrastructure substrate on local hypervisor hardware at **$0 cloud cost** capable of validating:
1. **Control Plane Quorum (etcd HA):** 3 dedicated control plane nodes.
2. **Distributed Block Storage (Longhorn 3x Replication):** 3 dedicated worker nodes with secondary `/dev/vdb` unformatted disks.

---

## 2. Architecture & File Layout

* **Module:** [`infra/modules/kvm-cluster/`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/modules/kvm-cluster)
  * `main.tf`: Defines base OS volume caching, 3 control plane domains, and 3 worker domains with secondary volumes.
  * `variables.tf`: Fully parameterized memory, vCPU, disk size, and deterministic MAC addressing.
  * `outputs.tf`: Exports node domain names and dynamic IP allocations.
* **Environment:** [`infra/environments/local-kvm/`](file:///home/bjarrett/Projects/enterprise-ha-platform/infra/environments/local-kvm)
  * `main.tf`: Instantiates the module.
  * `terraform.tfvars.example`: Sanitized template for local execution.

---

## 3. Verification & Evidence

### A. OpenTofu Validation
```bash
tofu init -backend=false
tofu validate
# Output: Success! The configuration is valid.
```

### B. Automated Test Suite
```bash
pytest -v
# Output:
# tests/test_sanity.py::TestPlatformTemplateSanity::test_doctor_script_execution PASSED
# tests/test_sanity.py::TestPlatformTemplateSanity::test_local_kvm_opentofu_validation PASSED
# tests/test_sanity.py::TestPlatformTemplateSanity::test_required_core_files_exist PASSED
# tests/test_sanity.py::TestPlatformTemplateSanity::test_required_directories_exist PASSED
# 4 passed in 1.42s
```

### C. Security & Sanitization
* Verified with `git log -S "t5600" --all` and regex scan: **0 references to private hardware models or internal network IPs.**
