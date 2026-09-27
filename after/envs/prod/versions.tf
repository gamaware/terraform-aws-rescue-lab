terraform {
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.66"
    }
  }

  # Partial configuration: bucket and region come from backend.hcl locally and
  # from -backend-config flags in CI. use_lockfile needs Terraform 1.11 or later
  # and replaces the DynamoDB lock table.
  backend "s3" {
    key          = "envs/prod/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      ManagedBy  = "terraform"
      Repository = "terraform-aws-rescue-lab"
      Stack      = "envs/prod"
    }
  }
}
