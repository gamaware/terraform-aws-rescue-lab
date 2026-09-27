variable "name_prefix" {
  description = "Company or product prefix. Every resource name starts with name_prefix and environment, so changing either replaces the buckets."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-22 characters of lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name, used in resource names and the Environment tag."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging or prod."
  }
}

variable "tags" {
  description = "Tags for every resource in the module. Owner and CostCenter are required so spend can be traced."
  type        = map(string)

  validation {
    condition     = alltrue([for key in ["Owner", "CostCenter"] : trimspace(lookup(var.tags, key, "")) != ""])
    error_message = "tags must include non-empty Owner and CostCenter values."
  }
}

variable "app_role_service" {
  description = "AWS service principal allowed to assume the application role, for example ec2.amazonaws.com."
  type        = string
  default     = "ec2.amazonaws.com"

  validation {
    condition     = can(regex("^[a-z0-9.-]+\\.amazonaws\\.com$", var.app_role_service))
    error_message = "app_role_service must be an AWS service principal such as ec2.amazonaws.com."
  }
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep previous versions of uploaded objects before they expire."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_retention_days >= 7 && var.noncurrent_version_retention_days <= 3650
    error_message = "noncurrent_version_retention_days must be between 7 and 3650."
  }
}

variable "access_log_retention_days" {
  description = "Days to keep S3 server access logs."
  type        = number
  default     = 365

  validation {
    condition     = var.access_log_retention_days >= 30 && var.access_log_retention_days <= 3650
    error_message = "access_log_retention_days must be between 30 and 3650."
  }
}

variable "force_destroy" {
  description = "Let terraform destroy delete non-empty buckets. Allowed only outside prod."
  type        = bool
  default     = false

  validation {
    condition     = !(var.force_destroy && var.environment == "prod")
    error_message = "force_destroy cannot be true when environment is prod."
  }
}
