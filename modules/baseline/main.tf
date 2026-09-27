data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  partition    = data.aws_partition.current.partition
  region       = data.aws_region.current.region
  trail_name   = "${var.name_prefix}-trail"
  trail_arn    = "arn:${local.partition}:cloudtrail:${local.region}:${local.account_id}:trail/${local.trail_name}"
  trail_bucket = "${var.name_prefix}-cloudtrail-${local.account_id}"
}

# -----------------------------------------------------------------------------
# Account-level guardrails
# -----------------------------------------------------------------------------

resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Applies to new EBS volumes and snapshot copies in this region, using the
# AWS managed aws/ebs key.
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# -----------------------------------------------------------------------------
# KMS key for CloudTrail logs and the budget alert topic
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "key" {
  # This document is a KMS key policy, where Resource "*" means "this key only".
  # checkov:skip=CKV_AWS_109:Key policy; "*" is scoped to the key it is attached to.
  # checkov:skip=CKV_AWS_111:Key policy; "*" is scoped to the key it is attached to.
  # checkov:skip=CKV_AWS_356:Key policy; "*" is scoped to the key it is attached to.
  statement {
    sid       = "AccountAdministration"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid       = "CloudTrailEncryptLogs"
    actions   = ["kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:${local.partition}:cloudtrail:*:${local.account_id}:trail/*"]
    }
  }

  statement {
    sid       = "CloudTrailDescribeKey"
    actions   = ["kms:DescribeKey"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    sid       = "BudgetsPublishToEncryptedTopic"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "Encrypts ${var.name_prefix} CloudTrail logs and budget alerts"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.key.json

  # The bootstrap apply role may only manage keys that carry this tag.
  tags = {
    Stack = "baseline"
  }
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.name_prefix}-baseline"
  target_key_id = aws_kms_key.this.key_id
}

# -----------------------------------------------------------------------------
# CloudTrail bucket
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "trail" {
  # checkov:skip=CKV_AWS_144:Single-account lab; cross-region replication of audit logs belongs in a log archive account.
  # checkov:skip=CKV_AWS_18:Access logging for the log bucket would need another bucket; the trail already records bucket API calls.
  # checkov:skip=CKV2_AWS_62:Nothing consumes object-created events for this bucket.
  bucket        = local.trail_bucket
  force_destroy = var.force_destroy_trail_bucket
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket = aws_s3_bucket.trail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    id     = "expire-trail-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.cloudtrail_log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid       = "CloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "CloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail.arn}/AWSLogs/${local.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.trail.arn,
      "${aws_s3_bucket.trail.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.trail_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.trail]
}

# -----------------------------------------------------------------------------
# CloudTrail
# -----------------------------------------------------------------------------

resource "aws_cloudtrail" "this" {
  # checkov:skip=CKV2_AWS_10:CloudWatch Logs delivery adds ingestion cost; the lab reads logs from S3 or Event history.
  # checkov:skip=CKV_AWS_252:Per-file delivery notifications are noise for a single lab account.
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.trail.id
  kms_key_id                    = aws_kms_key.this.arn
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.trail]
}

# -----------------------------------------------------------------------------
# Budget alert
# -----------------------------------------------------------------------------

resource "aws_sns_topic" "budget_alerts" {
  name              = "${var.name_prefix}-budget-alerts"
  kms_master_key_id = aws_kms_key.this.arn
}

data "aws_iam_policy_document" "budget_alerts" {
  statement {
    sid       = "AllowBudgetsPublish"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.budget_alerts.arn]

    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "budget_alerts" {
  arn    = aws_sns_topic.budget_alerts.arn
  policy = data.aws_iam_policy_document.budget_alerts.json
}

# The addresses are sensitive, so they are indexed by position and only the
# count is revealed in plans.
resource "aws_sns_topic_subscription" "budget_email" {
  count = nonsensitive(length(var.budget_alert_emails))

  topic_arn = aws_sns_topic.budget_alerts.arn
  protocol  = "email"
  endpoint  = var.budget_alert_emails[count.index]
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.name_prefix}-monthly"
  budget_type  = "COST"
  limit_amount = format("%.2f", var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = toset(var.budget_alert_thresholds)

    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value
      threshold_type            = "PERCENTAGE"
      notification_type         = "ACTUAL"
      subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
    }
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.budget_alerts.arn]
  }

  depends_on = [aws_sns_topic_policy.budget_alerts]
}
