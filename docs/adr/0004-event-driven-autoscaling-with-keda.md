# ADR 0004: Event-Driven Autoscaling with KEDA and Standard HPA

* **Status:** Accepted
* **Date:** 2026-11-03
* **Deciders:** Platform Engineering Team

---

## 1. Context and Problem Statement
Standard Kubernetes Horizontal Pod Autoscaler (HPA) natively scales pods based on resource utilization (CPU and Memory). However, in high-throughput enterprise systems (telemetry ingestion, API message backlogs, queue processing), CPU metrics lag behind real demand, leading to dropped messages, high latency, and delayed scale-out.

---

## 2. Decision Drivers
* Rapid, proactive scaling in response to incoming traffic surges before CPU spikes.
* Support for queue backlog depth (e.g. Redis, NATS, AWS SQS, GCP Pub/Sub).
* Native Kubernetes integration without proprietary agent lock-in.

---

## 3. Considered Options
* **Option A: Standard HPA with CPU/Memory Only:** Reactive, lags by 60–90 seconds during sudden traffic spikes.
* **Option B: Custom Prometheus Metrics Adapter:** Complex custom configuration, brittle PromQL scrapers.
* **Option C: KEDA (Kubernetes Event-Driven Autoscaling):** CNCF graduated project that dynamically feeds native HPA with event triggers (queue length, HTTP request rate, Kafka/Redis topics) while supporting scale-to-zero.

---

## 4. Decision Outcome
**Chosen Option:** Option C (KEDA + HPA).

KEDA is deployed to Tier 2 (`platform/autoscaling`) as the primary autoscaling controller. Workload pods use KEDA `ScaledObject` definitions to scale horizontally on queue depth and request concurrency.

### Positive Consequences:
* Instant scale-out (< 5 seconds) when message backlogs begin accumulating.
* Standardized YAML definitions that function identically on Local KVM, AWS, and GCP.
* Scale-to-baseline (or scale-to-zero) when traffic subsides, minimizing cloud compute costs.

### Negative Consequences / Trade-offs:
* Adds KEDA CRD and operator dependencies to the platform tier.
