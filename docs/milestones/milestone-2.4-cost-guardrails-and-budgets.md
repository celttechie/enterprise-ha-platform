# Milestone 2.4: Ephemeral AWS EKS Cost Guardrails & Automated Teardown

## 1. Overview & Objective
Milestone 2.4 completes **Phase 2 (AWS Ephemeral EKS Module with Cost Guardrails)**. The objective is to enforce strict financial governance and automated teardown mechanisms for ephemeral cloud testbeds, guaranteeing that development and CI/CD clusters never incur idle costs or exceed the project's financial budget (as codified in [ADR-0003](../adr/0003-multi-cloud-abstraction-and-spot-cost-guardrails.md) and [ADR-0008](../adr/0008-single-shared-nat-gateway-for-ephemeral-cloud-testbeds.md)).

Key deliverables include:
- **AWS Budgets Cost Guardrail**: A declarative OpenTofu resource (`aws_budgets_budget`) enforcing a **$5.00/month** hard ceiling with dual-tier alerting (80% actual spend and 100% forecasted spend).
- **Automated Teardown & Audit Utility (`scripts/cloud-guardrails/auto-teardown.sh`)**: An executable utility supporting `--audit`, `--ttl <minutes>`, and `--dry-run` to monitor active clusters, NAT gateways, VPCs, and CloudWatch log groups.
- **Makefile Integration**: `make guardrail-check` and `make budget` commands for single-command auditability.

---

## 2. Architecture & Design Decisions

### 2.1 Proactive AWS Budgets Alarm
Rather than relying on retroactive billing alerts, Milestone 2.4 configures AWS Budgets directly via OpenTofu:
- **Resource**: `aws_budgets_budget.cost_guardrail`
- **Budget Type**: `COST`
- **Limit**: `$5.00 USD/Month`
- **Thresholds**:
  - `80% ACTUAL` ($4.00): Warning alert sent to notification subscribers when actual accrued spend reaches 80%.
  - `100% FORECASTED` ($5.00): Critical alert sent when AWS cost forecasting predicts the monthly budget will be exceeded before month-end.
- **Tagging**: Inherits root project tags (`Project = enterprise-ha-platform`, `ManagedBy = OpenTofu`).

```hcl
resource "aws_budgets_budget" "cost_guardrail" {
  count        = var.enable_budget_alarm ? 1 : 0
  name         = "${var.cluster_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.budget_monthly_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_notification_emails
  }
}
```

### 2.2 Automated Teardown Engine (`auto-teardown.sh`)
The automated teardown script is designed for local developer workflows and scheduled cron/CI tasks:
- **Audit Mode (`--audit`)**: Queries active EKS clusters, VPCs, NAT gateways, lingering CloudWatch log groups, and budget status, reporting back spend status.
- **TTL Enforcement Mode (`--ttl <minutes>`)**: Queries the EKS cluster `createdAt` timestamp, computes elapsed runtime, and if runtime exceeds the TTL limit, automatically triggers `make destroy TARGET=aws`.
- **Dry-Run Mode (`--dry-run`)**: Validates cluster age and logs teardown actions without executing destructive API calls.

---

## 3. Operational Usage

### 3.1 Auditing Cloud Spend
```bash
# Via Makefile
make guardrail-check

# Direct script invocation
./scripts/cloud-guardrails/auto-teardown.sh --audit
```

### 3.2 Enforcing Testbed TTL
```bash
# Check if cluster age exceeds 60 minutes and destroy if true
./scripts/cloud-guardrails/auto-teardown.sh --ttl 60

# Dry-run TTL check
./scripts/cloud-guardrails/auto-teardown.sh --ttl 60 --dry-run
```

---

## 4. Verification & Validation
1. **OpenTofu Validation**: Verified with `tofu fmt -check` and `tofu validate` across modules and AWS root environment.
2. **OpenTofu Plan Execution**: Evaluated against live AWS APIs (`56 to add`), confirming the addition of `aws_budgets_budget.cost_guardrail`.
3. **Execution Safety**: Tested `--audit` against zero-resource baseline, confirming accurate zero-cost reporting (`$0.00`) and absence of lingering NAT Gateways or CloudWatch log groups.
4. **Unit Testing**: Added sanity assertions in `tests/test_sanity.py` covering budget templates, guardrail scripts, and milestone documentation.
