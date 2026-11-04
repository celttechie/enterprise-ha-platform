# Enterprise HA Platform — Implementation Plan

[![CI Status](https://img.shields.io/badge/CI-Passing-brightgreen.svg)](#)
[![Security Scan](https://img.shields.io/badge/Security-Gitleaks%20Verified-blue.svg)](#)
[![Architecture](https://img.shields.io/badge/Architecture-Decoupled%20Three--Tier-orange.svg)](#)
[![Multi-Cloud](https://img.shields.io/badge/Targets-Local%20KVM%20%7C%20AWS%20%7C%20GCP-teal.svg)](#)

---

## 🎯 Executive Summary & Objectives

Demonstrate enterprise High Availability, event-driven horizontal scalability, and zero-downtime resilience across three distinct infrastructure targets:
1. **Local KVM Hypervisor ($0.00 cost):** 3-node Control Plane + 3-node Worker pool running on KVM/Libvirt with virtual control plane VIP failover and Longhorn distributed storage.
2. **AWS EKS Ephemeral:** Multi-AZ cluster utilizing Spot Instances and cost guardrails (single shared NAT Gateway, automated teardown).
3. **GCP GKE Ephemeral:** Zonal cluster utilizing Google Cloud's $0 cluster management fee waiver and Preemptible/Spot NodePools.

---

## 🗺️ Milestone Roadmap

### Phase 1: Local KVM High Availability ($0 Baseline)
- [x] **M1.1**: Define OpenTofu module `infra/modules/kvm-cluster` (3 Control Plane + 3 Worker VMs on network bridge with secondary disks for Longhorn).
- [x] **M1.2**: Implement virtual control plane floating IP (VIP failover and Talos HA configs).
- [x] **M1.3**: Deploy Longhorn Distributed Block Storage with 3x volume replication across virtual workers.
- [x] **M1.4**: Validate control plane quorum survival by terminating CP-1 during active API queries.

### Phase 2: Ephemeral AWS EKS Module with Cost Guardrails
- [ ] **M2.1**: Define OpenTofu module `infra/modules/aws-eks` (VPC with single shared NAT Gateway, EKS Cluster).
- [ ] **M2.2**: Configure Spot NodeGroup (`t3.medium` / `t4g.medium`) with AWS Pod Identity / IRSA.
- [ ] **M2.3**: Deploy AWS Load Balancer Controller (ALB/NLB) and EBS CSI Driver.
- [ ] **M2.4**: Implement automated teardown safeguards and AWS Budget alarms ($5.00 limit).

### Phase 3: Ephemeral GCP GKE Module (Parity & Free Tier)
- [ ] **M3.1**: Define OpenTofu module `infra/modules/gcp-gke` (VPC and Zonal GKE Cluster for $0 management fee).
- [ ] **M3.2**: Configure Spot NodePool with Google Cloud Workload Identity Federation.
- [ ] **M3.3**: Configure GKE Gateway API and GCP Compute Persistent Disk CSI Driver.

### Phase 4: Common Kubernetes Platform Services Layer
- [ ] **M4.1**: Standardize Ingress Gateway (Envoy Gateway / Ingress-Nginx) across all three targets.
- [ ] **M4.2**: Deploy Metrics Server and **KEDA** (Kubernetes Event-Driven Autoscaling) operator.
- [ ] **M4.3**: Deploy CloudNative-PG Operator for automated PostgreSQL primary/replica failover.
- [ ] **M4.4**: Deploy Prometheus & Grafana with pre-configured HA and autoscaling dashboards.

### Phase 5: High-Throughput Workload & Autoscaling Tier
- [ ] **M5.1**: Package decoupled microservice application (Stateless Ingress API + Redis/NATS Queue + Worker Pool).
- [ ] **M5.2**: Configure `PodDisruptionBudgets` (PDB) and `topologySpreadConstraints` / `podAntiAffinity`.
- [ ] **M5.3**: Author KEDA `ScaledObject` triggering worker scaling (2 $\rightarrow$ 25 replicas) on queue depth and request rate.

### Phase 6: Automated Chaos Drills & Media Capture
- [ ] **M6.1**: Implement `k6` load generation script simulating 500+ concurrent users / 2,000 RPS.
- [ ] **M6.2**: Author `workloads/chaos-drills/run-drill.sh` automating the Black Friday surge + node termination.
- [ ] **M6.3**: Verify zero dropped requests (100% HTTP 200, 0% 5xx) during node crash.
- [ ] **M6.4**: Record terminal animation (`k9s` split-screen) and export Grafana dashboard snapshots for publication.
