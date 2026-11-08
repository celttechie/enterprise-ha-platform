# AWS Budget Guardrail ($5.00/Month Limit) (Milestone 2.4)

resource "aws_budgets_budget" "cost_guardrail" {
  count        = var.enable_budget_alarm ? 1 : 0
  name         = "${var.cluster_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.budget_monthly_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Warning Alert: 80% of Actual Monthly Spend ($4.00 on a $5.00 budget)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.budget_notification_emails
  }

  # Critical Alert: 100% of Forecasted Monthly Spend ($5.00 on a $5.00 budget)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.budget_notification_emails
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-monthly-budget"
    }
  )
}
