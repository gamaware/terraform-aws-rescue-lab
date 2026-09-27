variable "region" {
  description = "AWS region for the baseline resources."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for every resource name. Must match the bootstrap name_prefix."
  type        = string
  default     = "baseline-lab"
}

variable "budget_limit_usd" {
  description = "Monthly cost budget in USD."
  type        = number
  default     = 20
}

variable "budget_alert_emails" {
  description = "Email addresses for budget alerts. In CI this comes from the BUDGET_ALERT_EMAIL secret."
  type        = list(string)
  default     = []
  sensitive   = true
}
