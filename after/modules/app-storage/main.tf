data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  partition   = data.aws_partition.current.partition
  base_name   = "${var.name_prefix}-${var.environment}"
  bucket_name = "${local.base_name}-uploads"
  log_bucket  = "${local.base_name}-access-logs"
  tags        = merge(var.tags, { Environment = var.environment })
}

# -----------------------------------------------------------------------------
# KMS key for the uploads bucket
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
}

resource "aws_kms_key" "this" {
  description             = "Encrypts objects in ${local.bucket_name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.key.json
  tags                    = local.tags
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.bucket_name}"
  target_key_id = aws_kms_key.this.key_id
}

# -----------------------------------------------------------------------------
# Uploads bucket: private, versioned, KMS-encrypted, TLS only, access-logged
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  # checkov:skip=CKV_AWS_144:Cross-region replication is a disaster-recovery decision recorded as out of scope in the report.
  # checkov:skip=CKV2_AWS_62:No consumer for object events; add notifications when a consumer exists.
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = local.tags
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_logging" "this" {
  bucket        = aws_s3_bucket.this.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "${local.bucket_name}/"

  depends_on = [aws_s3_bucket_policy.logs]
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
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

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json

  depends_on = [aws_s3_bucket_public_access_block.this]
}

# -----------------------------------------------------------------------------
# Access log bucket. S3 server access logging supports SSE-S3 only on the
# target bucket, so this bucket cannot use the KMS key above.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "logs" {
  # checkov:skip=CKV_AWS_18:This is the access log target; logging it to itself would loop.
  # checkov:skip=CKV_AWS_144:Cross-region replication of access logs is out of scope, as for the uploads bucket.
  # checkov:skip=CKV_AWS_145:S3 server access log delivery supports SSE-S3 only on the target bucket.
  # checkov:skip=CKV2_AWS_62:No consumer for object events on a log bucket.
  bucket        = local.log_bucket
  force_destroy = var.force_destroy
  tags          = local.tags
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.access_log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs]
}

data "aws_iam_policy_document" "logs" {
  statement {
    sid       = "S3ServerAccessLogsDelivery"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/${local.bucket_name}/*"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
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

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs.json

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

# -----------------------------------------------------------------------------
# Application role: read and write objects in the uploads bucket, nothing else
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "app_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [var.app_role_service]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.base_name}-app"
  description        = "Application access to ${local.bucket_name}"
  assume_role_policy = data.aws_iam_policy_document.app_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "ListUploads"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    sid       = "ReadWriteUploads"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    sid       = "UseUploadsKey"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.this.arn]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "app-access"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}
