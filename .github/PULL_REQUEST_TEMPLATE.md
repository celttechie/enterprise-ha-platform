## 📋 Pull Request Summary

<!-- Provide a brief, high-level summary of what this change accomplishes. -->

---

### 🔍 Change Classification
- [ ] 🚀 New Feature / Platform Capability
- [ ] 🛠️ Infrastructure as Code (IaC) Modification
- [ ] 🛡️ Security / Compliance / Hardening
- [ ] 🐛 Bugfix / Incident Remediation
- [ ] 📚 Documentation / ADR Addition

---

### 💥 Blast Radius & Target Environments
<!-- Which environments could be impacted by this change? -->
- [ ] Local KVM Hypervisor (`local-kvm`)
- [ ] AWS Cloud (`aws`)
- [ ] GCP Cloud (`gcp`)
- [ ] Shared Platform / GitOps Manifests (`platform/`)
- [ ] Workloads / Load Testing (`workloads/`)

---

### 🧪 Verification & Evidence
<!-- Provide terminal output, test results, or screenshots demonstrating that the change works. -->
- **Sanity / Doctor Check:** `make doctor` output verified? [Yes/No]
- **CI Lint / Test:** `make ci` passed locally? [Yes/No]
- **Evidence / Diff / Plan Summary:**
```text
(Paste relevant tofu plan, test summary, or k9s/k6 output here)
```

---

### 🔄 Rollback Strategy
<!-- What exact command or procedure reverts this change if it fails in production? -->
1. Revert commit / restore previous OpenTofu state.
2. Command: `tofu apply -var-file=...` / `git revert <sha>`

---

### ✅ Contributor Checklist
- [ ] I have maintained zero-leakage security posture (no credentials or private keys added).
- [ ] If this PR introduces a significant design decision, an **ADR** has been added to `docs/adr/`.
- [ ] Pre-commit hooks (`make lint` / `pre-commit run --all-files`) pass cleanly.
- [ ] Documentation has been updated to reflect new features or procedures.
