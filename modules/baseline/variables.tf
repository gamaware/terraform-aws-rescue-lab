variable "name_prefix" {
  description = "Prefix for every resource name. Must match the prefix the bootstrap apply role was scoped to."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.name_prefix))
    error_message = "name_prefix must be 3-24 characters of lowercase letters, digits and hyphens."
  }
}

variable "budget_limit_usd" {
  description = "Monthly cost budget in USD."
  type        = number
  default     = 20

  validation {
    condition     = var.budget_limit_usd > 0
    error_message = "budget_limit_usd must be greater than zero."
  }
}

variable "budget_alert_thresholds" {
  description = "Percentages of the budget that trigger an alert. Actual spend for each, plus a forecast alert at 100."
  type        = list(number)
  default     = [50, 80, 100]
}

variable "budget_alert_emails" {
  description = "Email addresses subscribed to the budget alert SNS topic. Each address must confirm the subscription."
  type        = list(string)
  default     = []
  sensitive   = true

  validation {
    condition     = alltrue([for e in var.budget_alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "Every entry in budget_alert_emails must be an email address."
  }
}

variable "cloudtrail_log_retention_days" {
  description = "Days to keep CloudTrail log files before they expire."
  type        = number
  default     = 365
}

variable "force_destroy_trail_bucket" {
  description = "Allow terraform destroy to empty the CloudTrail bucket. Keep false outside a throwaway lab."
  type        = bool
  default     = false
}
