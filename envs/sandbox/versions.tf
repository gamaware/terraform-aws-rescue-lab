terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial configuration: bucket and region come from backend.hcl locally or
  # from -backend-config flags in CI. use_lockfile needs Terraform 1.10 or later.
  backend "s3" {
    key          = "envs/sandbox/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.name_prefix
      Environment = "sandbox"
      ManagedBy   = "terraform"
    }
  }
}
