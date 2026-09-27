# Offline tests for the app-storage module. The AWS provider is mocked, so they
# need no credentials and create nothing:
#
#   cd after/modules/app-storage
#   terraform init -backend=false
#   terraform test
#
# Each run checks a risk from report/diagnostic-report.md, not a restatement of
# the code: public exposure, missing encryption, wildcard IAM, names that would
# force a replacement, and inputs that must be rejected.

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
      arn = "arn:aws:s3:::harbor-test-uploads"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/harbor-test-app"
    }
  }
}

variables {
  name_prefix = "harbor"
  environment = "dev"
  tags = {
    Owner      = "platform-team"
    CostCenter = "cc-0000"
  }
}

run "uploads_bucket_is_private" {
  command = plan

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "All four public access block settings must be true on the uploads bucket (finding F1)."
  }

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.this.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be disabled with BucketOwnerEnforced, so no ACL can make an object public."
  }

  assert {
    condition     = one(data.aws_iam_policy_document.bucket.statement).effect == "Deny"
    error_message = "The uploads bucket policy may only contain the TLS deny statement, never an Allow."
  }
}

run "uploads_bucket_is_encrypted_and_versioned" {
  command = plan

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "The uploads bucket must use SSE-KMS (finding F5)."
  }

  assert {
    condition     = aws_kms_key.this.enable_key_rotation
    error_message = "The uploads KMS key must rotate."
  }

  assert {
    condition     = one(aws_s3_bucket_versioning.this.versioning_configuration).status == "Enabled"
    error_message = "Versioning must be on so an overwrite or delete can be undone."
  }
}

run "app_policy_has_no_wildcards" {
  # apply against the mock provider, so the bucket and key ARNs are known.
  command = apply

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.app.statement :
      alltrue([for a in s.actions : a != "*" && !endswith(a, ":*")])
    ])
    error_message = "The application policy must list actions explicitly (finding F2)."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.app.statement : !contains(s.resources, "*")
    ])
    error_message = "The application policy must name its resources, never \"*\"."
  }
}

run "names_match_the_existing_resources" {
  # Bucket and role names force replacement when they change. These must equal
  # the names the inherited code created, or the moved blocks cannot help.
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = aws_s3_bucket.this.bucket == "harbor-prod-uploads"
    error_message = "The uploads bucket name must stay <prefix>-<environment>-uploads."
  }

  assert {
    condition     = aws_s3_bucket.logs.bucket == "harbor-prod-access-logs"
    error_message = "The log bucket name must stay <prefix>-<environment>-access-logs, the name the import block expects."
  }

  assert {
    condition     = aws_iam_role.app.name == "harbor-prod-app"
    error_message = "The role name must stay <prefix>-<environment>-app."
  }

  assert {
    condition     = !aws_s3_bucket.this.force_destroy
    error_message = "force_destroy must default to false."
  }
}

run "every_resource_that_supports_tags_is_tagged" {
  command = plan

  assert {
    condition = alltrue([
      for t in [aws_s3_bucket.this.tags, aws_s3_bucket.logs.tags, aws_kms_key.this.tags, aws_iam_role.app.tags] :
      t["Owner"] == "platform-team" && t["CostCenter"] == "cc-0000" && t["Environment"] == "dev"
    ])
    error_message = "Buckets, key and role must carry Owner, CostCenter and Environment (finding F10)."
  }
}

run "rejects_missing_cost_center" {
  command = plan

  variables {
    tags = {
      Owner = "platform-team"
    }
  }

  expect_failures = [var.tags]
}

run "rejects_force_destroy_in_prod" {
  command = plan

  variables {
    environment   = "prod"
    force_destroy = true
  }

  expect_failures = [var.force_destroy]
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "production"
  }

  expect_failures = [var.environment]
}

run "basic_example_works" {
  # The example doubles as a fixture: if it stops working, the docs are wrong.
  command = apply

  module {
    source = "./examples/basic"
  }

  assert {
    condition     = output.bucket_name == "example-dev-uploads"
    error_message = "The basic example should create example-dev-uploads."
  }
}
