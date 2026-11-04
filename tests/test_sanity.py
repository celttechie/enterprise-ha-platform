#!/usr/bin/env python3
"""Sanity and baseline structure verification tests for enterprise-ha-platform."""

import os
import shutil
import subprocess
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


class TestPlatformTemplateSanity(unittest.TestCase):
    """Validate repository layout, core template compliance, and IaC."""

    def test_required_directories_exist(self):
        required_dirs = [
            "infra",
            "infra/modules",
            "infra/modules/kvm-cluster",
            "infra/environments/local-kvm",
            "infra/environments/aws",
            "infra/environments/gcp",
            "platform",
            "platform/cni",
            "platform/cni/cilium",
            "platform/ingress",
            "platform/autoscaling",
            "platform/storage",
            "platform/storage/longhorn",
            "platform/observability",
            "workloads",
            "workloads/chaos-drills",
            "docs",
            "docs/adr",
            "docs/milestones",
            "docs/security",
            "docs/operations",
            "scripts",
            ".github",
            ".github/workflows",
        ]
        for d in required_dirs:
            full_path = os.path.join(REPO_ROOT, d)
            self.assertTrue(os.path.isdir(full_path), f"Required directory missing: {d}")

    def test_required_core_files_exist(self):
        required_files = [
            "Makefile",
            "README.md",
            "pyproject.toml",
            ".gitignore",
            ".pre-commit-config.yaml",
            ".github/PULL_REQUEST_TEMPLATE.md",
            ".github/workflows/ci.yml",
            "scripts/doctor.py",
            "docs/IMPLEMENTATION_PLAN.md",
            "docs/adr/0001-record-architecture-decisions.md",
            "docs/adr/0002-decoupled-monorepo-tiering.md",
            "docs/adr/0003-multi-cloud-abstraction-and-spot-cost-guardrails.md",
            "docs/adr/0004-event-driven-autoscaling-with-keda.md",
            "docs/adr/0005-environment-neutrality-and-variable-driven-infrastructure.md",
            "docs/milestones/milestone-1.1-kvm-cluster-module.md",
            "docs/milestones/milestone-1.2-talos-ha-vip.md",
            "docs/milestones/milestone-1.3-cilium-and-longhorn-storage.md",
            "docs/milestones/milestone-1.4-control-plane-quorum-chaos.md",
            "docs/adr/0006-native-talos-configuration-via-opentofu-provider.md",
            "docs/adr/0007-control-plane-load-balancing-and-fast-vip-failover.md",
            "docs/security/security-model.md",
            "docs/operations/demonstration-runbook.md",
            "infra/modules/kvm-cluster/main.tf",
            "infra/modules/kvm-cluster/variables.tf",
            "infra/modules/kvm-cluster/outputs.tf",
            "infra/environments/local-kvm/main.tf",
            "infra/environments/local-kvm/talos.tf",
            "infra/environments/local-kvm/variables.tf",
            "infra/environments/local-kvm/outputs.tf",
            "infra/environments/local-kvm/terraform.tfvars.example",
            "infra/environments/local-kvm/talos/.gitignore",
            "platform/cni/cilium/values.yaml",
            "platform/storage/longhorn/namespace.yaml",
            "platform/storage/longhorn/values.yaml",
            "workloads/chaos-drills/validate-cp-quorum-chaos.sh",
        ]
        for f in required_files:
            full_path = os.path.join(REPO_ROOT, f)
            self.assertTrue(os.path.isfile(full_path), f"Required file missing: {f}")
            self.assertGreater(os.path.getsize(full_path), 0, f"File is empty: {f}")

    def test_doctor_script_execution(self):
        doctor_path = os.path.join(REPO_ROOT, "scripts", "doctor.py")
        res = subprocess.run([doctor_path], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"doctor.py failed with output:\n{res.stdout}\n{res.stderr}")
        self.assertIn("PLATFORM REPOSITORY PRE-FLIGHT AUDITOR", res.stdout)

    def test_local_kvm_opentofu_validation(self):
        if not shutil.which("tofu") and not shutil.which("terraform"):
            self.skipTest("Neither tofu nor terraform is installed")
        cmd = "tofu" if shutil.which("tofu") else "terraform"
        env_dir = os.path.join(REPO_ROOT, "infra", "environments", "local-kvm")
        init_res = subprocess.run([cmd, "init", "-backend=false"], cwd=env_dir, capture_output=True, text=True)
        self.assertEqual(init_res.returncode, 0, f"{cmd} init failed:\n{init_res.stderr}\n{init_res.stdout}")
        val_res = subprocess.run([cmd, "validate"], cwd=env_dir, capture_output=True, text=True)
        self.assertEqual(val_res.returncode, 0, f"{cmd} validate failed:\n{val_res.stderr}\n{val_res.stdout}")


if __name__ == "__main__":
    unittest.main()
