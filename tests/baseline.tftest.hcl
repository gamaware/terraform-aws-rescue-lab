# Unit tests for modules/baseline. They use a mocked AWS provider, so they
# need no credentials and create nothing.
#
#   terraform init -backend=false   # from the repository root
#   terraform test

# 123456789012 is the example account ID from the AWS documentation.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  # Valid ARNs so mocked applies pass provider validation.
  mock_resource "aws_kms_key" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      arn = "arn:aws:s3:::baseline-test-cloudtrail-123456789012"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:baseline-test-budget-alerts"
    }
  }

  mock_resource "aws_cloudtrail" {
    defaults = {
      arn = "arn:aws:cloudtrail:us-east-1:123456789012:trail/baseline-test-trail"
    }
  }
}

variables {
  name_prefix         = "baseline-test"
  budget_alert_emails = ["alerts@example.com"]
}

run "account_guardrails_are_on" {
  command = plan

  module {
    source = "./modules/baseline"
  }

  assert {
    condition = alltrue([
      aws_s3_account_public_access_block.this.block_public_acls,
      aws_s3_account_public_access_block.this.block_public_policy,
      aws_s3_account_public_access_block.this.ignore_public_acls,
      aws_s3_account_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "All four account-level S3 public access block settings must be true."
  }

  assert {
    condition     = aws_ebs_encryption_by_default.this.enabled
    error_message = "EBS encryption by default must be enabled."
  }
}

run "trail_is_hardened" {
  command = plan

  module {
    source = "./modules/baseline"
  }

  assert {
    condition     = aws_cloudtrail.this.is_multi_region_trail && aws_cloudtrail.this.enable_log_file_validation
    error_message = "The trail must be multi-region with log file validation."
  }

  assert {
    condition     = aws_cloudtrail.this.name == "baseline-test-trail"
    error_message = "The trail name must start with name_prefix so the apply role can manage it."
  }

  assert {
    condition     = aws_s3_bucket.trail.bucket == "baseline-test-cloudtrail-123456789012"
    error_message = "The trail bucket name must include the prefix and the account ID."
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation
    error_message = "The baseline KMS key must rotate."
  }

  assert {
    condition     = !aws_s3_bucket.trail.force_destroy
    error_message = "force_destroy must default to false."
  }
}

run "budget_alerts_every_threshold" {
  # apply against the mock provider so the notification set is known.
  command = apply

  module {
    source = "./modules/baseline"
  }

  variables {
    budget_limit_usd        = 15
    budget_alert_thresholds = [50, 90]
  }

  assert {
    condition     = aws_budgets_budget.monthly.limit_amount == "15.00"
    error_message = "The budget limit must be formatted with two decimals."
  }

  assert {
    condition     = length(aws_budgets_budget.monthly.notification) == 3
    error_message = "Expected one actual alert per threshold plus one forecast alert."
  }

  assert {
    condition     = length(aws_sns_topic_subscription.budget_email) == 1
    error_message = "Expected one email subscription per address."
  }
}

run "rejects_bad_email" {
  command = plan

  module {
    source = "./modules/baseline"
  }

  variables {
    budget_alert_emails = ["not-an-email"]
  }

  expect_failures = [var.budget_alert_emails]
}

run "rejects_bad_prefix" {
  command = plan

  module {
    source = "./modules/baseline"
  }

  variables {
    name_prefix = "Bad_Prefix"
  }

  expect_failures = [var.name_prefix]
}
