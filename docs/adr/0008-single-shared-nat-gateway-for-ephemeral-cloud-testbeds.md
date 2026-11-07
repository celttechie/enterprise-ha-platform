# ADR 0008: Single Shared NAT Gateway for Ephemeral Cloud Testbeds

* **Status:** Accepted
* **Date:** 2026-11-06
* **Deciders:** Platform Engineering Team
* **Related:** [ADR-0003: Multi-Cloud Abstraction and Spot Cost Guardrails](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/adr/0003-multi-cloud-abstraction-and-spot-cost-guardrails.md), [Milestone 2.1: Ephemeral AWS EKS Module](file:///home/bjarrett/Projects/enterprise-ha-platform/docs/milestones/milestone-2.1-aws-eks-module.md)

---

## 1. Context and Problem Statement

In **Phase 2 (Milestone 2.1)**, the platform engineering template expands from on-premises/bare-metal KVM hypervisors to public cloud, provisioning an enterprise-grade Kubernetes cluster on AWS Elastic Kubernetes Service (EKS).

Per AWS Well-Architected Framework guidelines and Kubernetes security standards:
1. Worker nodes run in **Private Subnets** with no public IPv4 addresses assigned, isolated from the public internet.
2. Ingress and egress must be strictly decoupled: incoming public traffic arrives via an AWS Application/Network Load Balancer in **Public Subnets**, while outbound egress (container image pulls from registries like Quay/DockerHub, OS security patches, AWS API calls) routes through AWS NAT Gateways.
3. High Availability best practices dictate spreading resources across at least three distinct Availability Zones (`us-east-2a`, `us-east-2b`, `us-east-2c`).

However, AWS charges **$0.045 per NAT Gateway per hour** plus standard data processing charges ($0.045/GB):
* Deploying 1 NAT Gateway per AZ (3 AZs $\times$ $0.045/hr $\times$ 720 hours) incurs a fixed baseline charge of **~$97.20/month (~$3.24/day)** purely for idle subnet connectivity.
* For ephemeral development environments, automated CI testbeds, and transient demonstration clusters that are spun up and torn down rapidly, paying a 3x fixed baseline cost for redundant egress gateways is economically wasteful and directly conflicts with the platform's core tenet: **cost guardrails and sub-$1.00 demonstration runs**.

We need an egress routing architecture that honors enterprise private subnet topology while maximizing cost efficiency for non-production and ephemeral clusters.

---

## 2. Decision Drivers

* **Aggressive Cost Optimization:** Keep ephemeral testbed baseline egress costs under ~$0.05/hr (~$1.08/day), ensuring demo runs and automated pipeline tests cost pennies.
* **Strict Enterprise Network Topology:** Retain three private subnets across three Availability Zones (`us-east-2a`, `us-east-2b`, `us-east-2c`) with standard Kubernetes tags (`kubernetes.io/role/internal-elb = 1`) so workloads and node groups remain fully multi-AZ.
* **Production Portability (Zero Forking):** The infrastructure code must allow instant toggling between single-NAT and multi-NAT topologies via a single variable, without restructuring subnets or route tables.
* **Zero Security Compromise:** Worker nodes must remain strictly private; no public IPs or direct internet gateways in private subnets.

---

## 3. Considered Options

### Option A: Fully Redundant Multi-AZ NAT Gateways (1 per AZ)
* **Architecture:** Provision 3 Elastic IPs and 3 NAT Gateways (one in each public subnet: `us-east-2a`, `us-east-2b`, `us-east-2c`). Each private subnet points its `0.0.0.0/0` route to its local AZ's NAT Gateway.
* **Pros:** Complete AZ failure isolation. If an entire AWS Availability Zone experiences an outage, egress from the remaining two AZs is completely unaffected. Zero cross-AZ data transfer charges for outbound internet traffic.
* **Cons:** Incurs ~$97.20/month (~$0.135/hr) in fixed baseline costs. For a 4-hour ephemeral test run, this adds unnecessary overhead.

### Option B: Single Shared NAT Gateway
* **Architecture:** Provision 1 Elastic IP and 1 NAT Gateway in Public Subnet 1 (`us-east-2a`). All three private subnets across all three AZs point their default `0.0.0.0/0` outbound route to this single shared NAT Gateway.
* **Pros:**
  * **67% cost reduction** in fixed baseline egress charges: from ~$0.135/hr down to ~$0.045/hr (~$32.40/month or ~$1.08/day).
  * Retains full Multi-AZ placement for worker nodes and pods across all 3 private subnets.
  * Ingress via Multi-AZ ALBs is completely unaffected (ALB ingress does not traverse NAT Gateways).
* **Cons:**
  * If `us-east-2a` suffers a catastrophic, zone-wide outage, outbound internet egress for nodes in `us-east-2b` and `us-east-2c` is disrupted until recovery.
  * Outbound internet traffic originating from nodes in `us-east-2b` and `us-east-2c` incurs nominal inter-AZ data transfer fees ($0.01/GB). In practice, for container pull caches and API calls, this cost is negligible compared to the $64.80/month fixed NAT savings.

### Option C: NAT Instance (EC2 `t4g.nano` with iptables masquerade)
* **Architecture:** Replace AWS managed NAT Gateway with an EC2 spot/on-demand instance running Linux IP forwarding and SNAT.
* **Pros:** Reduces baseline cost further to ~$3.00/month for a `t4g.nano`.
* **Cons:** Introduces operational overhead, OS patching, software maintenance, and single-instance bandwidth/performance bottlenecks. Incompatible with enterprise-grade managed platform patterns.

---

## 4. Decision Outcome

**Chosen Option:** **Option B** (Single Shared NAT Gateway), parameterized via the OpenTofu variable `single_nat_gateway`.

### Implementation Specification:
1. **Default Configuration:** `single_nat_gateway = true` (default for ephemeral testbeds and demo clusters).
   - Allocates 1 `aws_eip` and 1 `aws_nat_gateway` in Public Subnet 1 (`us-east-2a`).
   - Associates all 3 private subnets (`10.0.10.0/24`, `10.0.20.0/24`, `10.0.30.0/24`) with a single private route table directing `0.0.0.0/0` to the shared NAT Gateway.
2. **Production Toggle:** Setting `single_nat_gateway = false` in `terraform.tfvars`:
   - Allocates 3 `aws_eip`s and 3 `aws_nat_gateway`s (one per public subnet).
   - Creates 3 independent private route tables mapping each private subnet to its respective AZ NAT Gateway.

### Summary Cost Analysis:

| Configuration | NAT Gateways | Baseline Cost / Hr | Baseline Cost / Month | 4-Hour Test Run Cost | Egress AZ Isolation |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Multi-NAT (Prod)** | 3 | $0.135 | $97.20 | $0.54 | 100% (Per-AZ) |
| **Single Shared NAT (Ephemeral)** | **1** | **$0.045** | **$32.40** | **$0.18** | Shared AZ (`us-east-2a`) |

---

## 5. Consequences & Mitigations

* **AZ Outage Risk:** In the unlikely event of a complete AWS AZ outage affecting `us-east-2a`, outbound internet egress is interrupted for all private workloads.
  * *Mitigation:* This is acceptable for ephemeral testbed environments. For mission-critical production deployments, the configuration is seamlessly switched via `single_nat_gateway = false`.
* **Cross-AZ Data Transfer Charges:** Cross-AZ egress incurs standard AWS inter-AZ transfer charges ($0.01/GB).
  * *Mitigation:* EKS workloads pull images predominantly during initialization; intra-cluster service-to-service traffic never traverses the NAT Gateway. The $64.80/month fixed savings far outweigh pennies in inter-AZ egress transfer.
