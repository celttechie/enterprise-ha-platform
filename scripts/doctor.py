#!/usr/bin/env python3
"""
Platform Engineering Environment Auditor (doctor.py)

Comprehensive diagnostic tool to verify CLI binaries, hardware virtualization,
cloud connectivity, and container runtimes required for multi-cloud platform work.
"""

import shutil
import subprocess
import sys

CRITICAL_TOOLS = [
    ("tofu", "OpenTofu (IaC) - or terraform"),
    ("kubectl", "Kubernetes CLI"),
    ("helm", "Helm Package Manager"),
    ("python3", "Python 3 Runtime"),
]

OPTIONAL_PLATFORM_TOOLS = [
    ("aws", "AWS Command Line Interface"),
    ("gcloud", "Google Cloud SDK CLI"),
    ("k9s", "Kubernetes Terminal UI (for Live Demos)"),
    ("ffmpeg", "Video/GIF Processing (for Media Recording)"),
    ("virsh", "Libvirt / KVM CLI (for Local KVM Hypervisor)"),
    ("docker", "Docker Container Runtime"),
    ("talosctl", "Talos Linux Management CLI"),
]


def check_kvm():
    """Check if hardware virtualization (VT-x / AMD-V) is exposed to the OS."""
    try:
        with open("/proc/cpuinfo") as f:
            content = f.read()
            if "vmx" in content or "svm" in content:
                return True, "Hardware virtualization flags present (vmx/svm)"
            return False, "No hardware virtualization flags found"
    except Exception as e:
        return False, str(e)


def check_aws_auth():
    """Verify if AWS credentials/configuration is active."""
    if not shutil.which("aws"):
        return False, "AWS CLI not installed"
    try:
        res = subprocess.run(["aws", "sts", "get-caller-identity"],
                             capture_output=True, text=True, timeout=5)
        if res.returncode == 0:
            return True, "AWS credentials active and authenticated"
        return False, "AWS credentials not configured or expired"
    except Exception as e:
        return False, f"AWS auth check skipped: {e}"


def main():
    print("=======================================================================")
    print("      PLATFORM REPOSITORY PRE-FLIGHT AUDITOR (make doctor)             ")
    print("=======================================================================")

    failed_critical = False

    print("\n[1] Critical Core Tooling:")
    for tool, desc in CRITICAL_TOOLS:
        path = shutil.which(tool)
        if not path and tool == "tofu":
            path = shutil.which("terraform")
            if path:
                tool = "terraform"

        if path:
            print(f"  \033[32m[PASS]\033[0m {tool:<12} - {desc} ({path})")
        else:
            print(f"  \033[31m[FAIL]\033[0m {tool:<12} - {desc} (MISSING)")
            failed_critical = True

    print("\n[2] Cloud & Demonstration Tooling:")
    for tool, desc in OPTIONAL_PLATFORM_TOOLS:
        path = shutil.which(tool)
        if path:
            print(f"  \033[32m[PASS]\033[0m {tool:<12} - {desc} ({path})")
        else:
            print(f"  \033[33m[INFO]\033[0m {tool:<12} - {desc} (Not installed / Optional)")

    print("\n[3] Hardware Virtualization (KVM):")
    kvm_ok, kvm_msg = check_kvm()
    status_color = "\033[32m[PASS]\033[0m" if kvm_ok else "\033[33m[WARN]\033[0m"
    print(f"  {status_color} KVM: {kvm_msg}")

    print("\n[4] Cloud Identity & Credentials:")
    aws_ok, aws_msg = check_aws_auth()
    status_color = "\033[32m[PASS]\033[0m" if aws_ok else "\033[33m[INFO]\033[0m"
    print(f"  {status_color} AWS STS: {aws_msg}")

    print("\n=======================================================================")
    if failed_critical:
        print("\033[31m[ERROR] One or more critical tools are missing. Review above.\033[0m")
        sys.exit(1)
    else:
        print("\033[32m[SUCCESS] Core platform environment ready!\033[0m")
        sys.exit(0)


if __name__ == "__main__":
    main()
