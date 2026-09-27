variable "region" {
  description = "AWS region for the state bucket and the KMS key."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for every resource name. The apply role can only manage resources that start with it."
  type        = string
  default     = "baseline-lab"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.name_prefix))
    error_message = "name_prefix must be 3-24 characters of lowercase letters, digits and hyphens."
  }
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, in owner/name form."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like owner/name."
  }
}

variable "apply_environment" {
  description = "GitHub environment whose jobs may assume the apply role. It should have required reviewers."
  type        = string
  default     = "production"
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set to false if the account already has one."
  type        = bool
  default     = true
}
