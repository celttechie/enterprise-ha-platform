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
            "infra/modules/aws-eks",
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
            "docs/adr/0008-single-shared-nat-gateway-for-ephemeral-cloud-testbeds.md",
            "docs/milestones/milestone-2.1-aws-eks-module.md",
            "docs/milestones/milestone-2.2-aws-eks-spot-nodegroup.md",
            "docs/milestones/milestone-2.3-aws-lbc-and-ebs-csi.md",
            "docs/milestones/milestone-2.4-cost-guardrails-and-budgets.md",
            "docs/milestones/milestone-3.1-gcp-gke-cluster.md",
            "docs/security/security-model.md",
            "docs/operations/demonstration-runbook.md",
            "scripts/cloud-guardrails/auto-teardown.sh",
            "infra/modules/kvm-cluster/main.tf",
            "infra/modules/kvm-cluster/variables.tf",
            "infra/modules/kvm-cluster/outputs.tf",
            "infra/modules/aws-eks/variables.tf",
            "infra/modules/aws-eks/vpc.tf",
            "infra/modules/aws-eks/kms.tf",
            "infra/modules/aws-eks/iam.tf",
            "infra/modules/aws-eks/security_groups.tf",
            "infra/modules/aws-eks/eks.tf",
            "infra/modules/aws-eks/nodegroup.tf",
            "infra/modules/aws-eks/addons.tf",
            "infra/modules/aws-eks/ebs_csi.tf",
            "infra/modules/aws-eks/lbc_iam.tf",
            "infra/modules/aws-eks/budget.tf",
            "infra/modules/aws-eks/outputs.tf",
            "infra/modules/gcp-gke/variables.tf",
            "infra/modules/gcp-gke/vpc.tf",
            "infra/modules/gcp-gke/cluster.tf",
            "infra/modules/gcp-gke/outputs.tf",
            "infra/environments/local-kvm/main.tf",
            "infra/environments/local-kvm/talos.tf",
            "infra/environments/local-kvm/variables.tf",
            "infra/environments/local-kvm/outputs.tf",
            "infra/environments/local-kvm/terraform.tfvars.example",
            "infra/environments/local-kvm/talos/.gitignore",
            "infra/environments/aws/main.tf",
            "infra/environments/aws/variables.tf",
            "infra/environments/aws/outputs.tf",
            "infra/environments/aws/terraform.tfvars.example",
            "infra/environments/gcp/main.tf",
            "infra/environments/gcp/variables.tf",
            "infra/environments/gcp/outputs.tf",
            "infra/environments/gcp/terraform.tfvars.example",
            "platform/cni/cilium/values.yaml",
            "platform/storage/longhorn/namespace.yaml",
            "platform/storage/longhorn/values.yaml",
            "platform/storage/ebs-csi/storageclass.yaml",
            "platform/ingress/aws-lbc/values.yaml",
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

    def test_auto_teardown_script_execution(self):
        teardown_path = os.path.join(REPO_ROOT, "scripts", "cloud-guardrails", "auto-teardown.sh")
        res = subprocess.run([teardown_path, "--help"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"auto-teardown.sh --help failed:\n{res.stdout}\n{res.stderr}")
        self.assertIn("Usage: auto-teardown.sh", res.stdout)

    def test_local_kvm_opentofu_validation(self):
        if not shutil.which("tofu") and not shutil.which("terraform"):
            self.skipTest("Neither tofu nor terraform is installed")
        cmd = "tofu" if shutil.which("tofu") else "terraform"
        env_dir = os.path.join(REPO_ROOT, "infra", "environments", "local-kvm")
        init_res = subprocess.run([cmd, "init", "-backend=false"], cwd=env_dir, capture_output=True, text=True)
        self.assertEqual(init_res.returncode, 0, f"{cmd} init failed:\n{init_res.stderr}\n{init_res.stdout}")
        val_res = subprocess.run([cmd, "validate"], cwd=env_dir, capture_output=True, text=True)
        self.assertEqual(val_res.returncode, 0, f"{cmd} validate failed:\n{val_res.stderr}\n{val_res.stdout}")

    def test_aws_eks_opentofu_validation(self):
        if not shutil.which("tofu") and not shutil.which("terraform"):
            self.skipTest("Neither tofu nor terraform is installed")
        cmd = "tofu" if shutil.which("tofu") else "terraform"
        env_dir = os.path.join(REPO_ROOT, "infra", "environments", "aws")
        init_res = subprocess.run([cmd, "init", "-backend=false"], cwd=env_dir, capture_output=True, text=True)
        self.assertEqual(init_res.returncode, 0, f"{cmd} init failed:\n{init_res.stderr}\n{init_res.stdout}")
        val_res = subprocess.run([cmd, "validate"], cwd=env_dir, capture_output=True, text=True)
        self.assertEqual(val_res.returncode, 0, f"{cmd} validate failed:\n{val_res.stderr}\n{val_res.stdout}")

    def test_gcp_gke_opentofu_validation(self):
        if not shutil.which("tofu") and not shutil.which("terraform"):
            self.skipTest("Neither tofu nor terraform is installed")
        cmd = "tofu" if shutil.which("tofu") else "terraform"
        env_dir = os.path.join(REPO_ROOT, "infra", "environments", "gcp")
        init_res = subprocess.run([cmd, "init", "-backend=false"], cwd=env_dir, capture_output=True, text=True)
        self.assertEqual(init_res.returncode, 0, f"{cmd} init failed:\n{init_res.stderr}\n{init_res.stdout}")
        val_res = subprocess.run([cmd, "validate"], cwd=env_dir, capture_output=True, text=True)
        self.assertEqual(val_res.returncode, 0, f"{cmd} validate failed:\n{val_res.stderr}\n{val_res.stdout}")


if __name__ == "__main__":
    unittest.main()
