module "baseline" {
  source = "../../modules/baseline"

  name_prefix         = var.name_prefix
  budget_limit_usd    = var.budget_limit_usd
  budget_alert_emails = var.budget_alert_emails
}
