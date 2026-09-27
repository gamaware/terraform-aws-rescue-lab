# -----------------------------------------------------------------------------
# One CI role, read-only: pull requests and the scheduled drift check run
# terraform plan with it. There is deliberately no apply role in this repo
# (docs/adr/0001-read-only-diagnosis.md): fixes reach AWS through the client's
# own reviewed pipeline.
# -----------------------------------------------------------------------------

locals {
  state_objects = "${aws_s3_bucket.state.arn}/*"
  lock_objects  = "${aws_s3_bucket.state.arn}/*.tflock"
}

# --- Trust policies ----------------------------------------------------------

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc}:sub"
      values = [
        "repo:${var.github_repository}:pull_request",
        "repo:${var.github_repository}:ref:refs/heads/main",
      ]
    }
  }
}

# --- State access -----------------------------------------------------------

data "aws_iam_policy_document" "state_read" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = [local.state_objects]
  }

  # plan still takes the lock, so the read-only role writes lock files only.
  statement {
    sid       = "ManageLockFile"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = [local.lock_objects]
  }

  statement {
    sid       = "UseStateKey"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.state.arn]
  }
}

# --- Plan role ---------------------------------------------------------------

resource "aws_iam_role" "plan" {
  name                 = "${var.name_prefix}-github-plan"
  description          = "Read-only role for terraform plan from GitHub Actions"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform-state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.state_read.json
}

# ReadOnlyAccess also reads data, not only configuration. terraform plan for
# this repository needs neither, so a PR that sneaks code into the plan job
# still cannot read objects, parameters or secrets.
data "aws_iam_policy_document" "plan_deny_data" {
  statement {
    sid           = "DenyObjectReadsOutsideState"
    effect        = "Deny"
    actions       = ["s3:GetObject", "s3:GetObjectVersion"]
    not_resources = [local.state_objects]
  }

  statement {
    sid    = "DenyParameterAndSecretReads"
    effect = "Deny"
    actions = [
      "secretsmanager:GetSecretValue",
      "ssm:GetParameter",
      "ssm:GetParameterHistory",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "plan_deny_data" {
  name   = "deny-data-reads"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_deny_data.json
}
