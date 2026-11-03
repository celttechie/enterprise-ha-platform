# Enterprise High Availability & Scalable Platform (`enterprise-ha-platform`)

[![CI Status](https://img.shields.io/badge/CI-Passing-brightgreen.svg)](#)
[![Security Scan](https://img.shields.io/badge/Security-Gitleaks%20Active-blue.svg)](#)
[![Architecture](https://img.shields.io/badge/Architecture-Decoupled%20Three--Tier-orange.svg)](#)
[![Multi-Cloud](https://img.shields.io/badge/Targets-Local%20KVM%20%7C%20AWS%20EKS%20%7C%20GCP%20GKE-teal.svg)](#)
[![Autoscaling](https://img.shields.io/badge/Autoscaling-KEDA%20%2B%20HPA-purple.svg)](#)

An enterprise-grade, multi-cloud Kubernetes platform engineered to demonstrate **resilient High Availability (HA)**, **rapid event-driven scalability (KEDA)**, and **automated zero-downtime chaos recovery** across three distinct environments:
1. **Local KVM Hypervisor (Libvirt):** 6-node virtual cluster ($0.00 cost) with Longhorn distributed block storage and virtual control plane failover.
2. **AWS EKS (Ephemeral Spot):** Multi-AZ cluster utilizing Spot Instances and cost guardrails (single shared NAT Gateway, automated teardown).
3. **GCP GKE (Ephemeral Spot):** Zonal cluster leveraging GCP's $0 cluster management fee and Preemptible/Spot NodePools.

---

## 🏛️ System Architecture

```
                 ┌────────────────────────────────────────────────────────┐
                 │       Unified GitOps & Shared Platform Layer           │
                 │  • Ingress / Service Mesh (Envoy / Cilium)             │
                 │  • Event-Driven Autoscaling (KEDA + HPA)               │
                 │  • PodAntiAffinity & PodDisruptionBudgets (PDB)        │
                 │  • HA Database (CloudNative-PG automated failover)     │
                 └───────────────────────────┬────────────────────────────┘
                                             │
                      ┌──────────────────────┼──────────────────────┐
                      ▼                      ▼                      ▼
         ┌────────────────────────┐┌───────────────────┐┌───────────────────┐
         │       Local KVM        ││      AWS EKS      ││      GCP GKE      │
         │   (Talos Linux / K3s)  ││  (Spot Instances) ││  (Spot / Zonal)   │
         │  • Cost: $0.00         ││  • Ephemeral IaC  ││  • $0 Control Fee │
         │  • 3 Control / 3 Worker││  • Multi-AZ       ││  • Multi-Zone     │
         │  • Longhorn 3x Storage ││  • AWS EBS CSI    ││  • GCP PD CSI     │
         │  • VIP: Virtual IP     ││  • IRSA / Pod ID  ││  • Workload ID    │
         └────────────────────────┘└───────────────────┘└───────────────────┘
```

---

## 📂 Repository Structure

Enforces a strict **Three-Tier Decoupled Monorepo** design:

```text
enterprise-ha-platform/
├── infra/                  # TIER 1: Infrastructure as Code (OpenTofu)
│   ├── modules/            # Reusable modules (kvm-cluster, aws-eks, gcp-gke)
│   └── environments/       # Environment roots (local-kvm, aws, gcp)
│
├── platform/               # TIER 2: Kubernetes Platform Services (Helm / Kustomize)
│   ├── ingress/            # Ingress Controllers & Gateway API
│   ├── autoscaling/        # KEDA ScaledObjects & Metrics Server
│   ├── storage/            # Distributed CSI / Operators (Longhorn, CloudNative-PG)
│   └── observability/      # Prometheus & Grafana monitoring stack
│
├── workloads/              # TIER 3: Applications & Resilience Harness
│   ├── demo-app/           # High-throughput ingestion API & worker pool
│   ├── load-tests/         # Synthetic traffic generation (k6 / Locust)
│   └── chaos-drills/       # Automated failure injection scripts (virsh / aws cli)
│
├── docs/                   # Living Documentation Architecture
│   ├── IMPLEMENTATION_PLAN.md # Roadmap with real-time status badges
│   ├── adr/                # Architecture Decision Records
│   ├── security/           # Threat model & zero-leakage security posture
│   └── operations/         # Demonstration runbooks & media recording guides
│
├── scripts/                # SRE Automation Tooling (doctor.py, capture scripts)
└── Makefile                # Unified Developer & CI/CD Interface
```

---

## ⚡ Quick Start

### 1. Initialize Python Tooling & Linters
Create an isolated virtual environment and install linters and testing tools (`yamllint`, `flake8`, `pre-commit`, `pytest`) defined in `pyproject.toml` (accelerated with `uv` if present):
```bash
make venv
```

### 2. Pre-Flight Environment Audit
Verify your workstation has the required CLI binaries, virtualization flags, and cloud tooling:
```bash
make doctor
```

### 3. Run Local Quality & Security Gates
Run code formatters, YAML linters, secret detection, and unit tests:
```bash
make ci
```

### 4. Deploy Stack to Target Environment
```bash
# Target: Local KVM Hypervisor ($0 cost)
make deploy TARGET=local-kvm

# Target: Ephemeral AWS EKS (Spot NodeGroup with cost guardrails)
make deploy TARGET=aws

# Target: Ephemeral GCP GKE (Zonal free tier with Spot NodePool)
make deploy TARGET=gcp
```

### 5. Run Automated Demo & Chaos Resilience Drill
```bash
make demo
```

---

## 🛡️ Security Posture

* **Zero Secret Leakage:** Integrated `gitleaks` pre-commit hooks and GitHub Actions workflows block private keys, tokens, and cloud credentials before they touch git history.
* **Identity Federation:** Pods authenticate to cloud APIs via **EKS Pod Identity** or **GCP Workload Identity**—never long-lived static API keys.
* **Restricted Workloads:** Containers run as non-root with read-only root filesystems and dropped capabilities.

---

## 📚 Documentation Reference

* **[Implementation Plan & Roadmap](docs/IMPLEMENTATION_PLAN.md)**
* **[Architecture Decision Records (ADRs)](docs/adr/0001-record-architecture-decisions.md)**
* **[Security Architecture Model](docs/security/security-model.md)**
* **[Demonstration & Media Recording Runbook](docs/operations/demonstration-runbook.md)**
* **[Homelab & Cross-Project Master Index](file:///home/bjarrett/Projects/lab-docs/PROJECT_INDEX.md)**
