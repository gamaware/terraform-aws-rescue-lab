# Inherited code, kept exactly as received. Do not fix it here: every problem
# in this file is a finding in report/REPORT.md, and after/ holds
# the repaired version.

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Renamed from "uploads_bucket" to "uploads" to match the dev folder.
resource "aws_s3_bucket" "uploads" {
  bucket = "harbor-prod-uploads"
}

resource "aws_s3_bucket_ownership_controls" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

# Product images are served straight from the bucket.
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  acl    = "public-read" # nosemgrep: s3-public-read-bucket (intentional, finding F1)

  depends_on = [
    aws_s3_bucket_ownership_controls.uploads,
    aws_s3_bucket_public_access_block.uploads,
  ]
}

resource "aws_s3_bucket_policy" "uploads" {
  bucket = aws_s3_bucket.uploads.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::harbor-prod-uploads/*"
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.uploads]
}

resource "aws_iam_role" "app" {
  name = "harbor-prod-app"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      },
    ]
  })
}

# TODO: tighten later, the app kept failing with AccessDenied.
resource "aws_iam_role_policy" "app" {
  name = "app-access"
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # nosemgrep: no-iam-admin-privileges (intentional, finding F2)
        Effect   = "Allow"
        Action   = "*" # nosemgrep: no-iam-star-actions (intentional, finding F2)
        Resource = "*"
      },
    ]
  })
}

output "uploads_bucket" {
  value = aws_s3_bucket.uploads.bucket
}
