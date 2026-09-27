# -----------------------------------------------------------------------------
# Two CI roles:
#   plan  - read-only, assumed by pull requests and the scheduled drift check
#   apply - assumed only by jobs that run in the protected GitHub environment
# -----------------------------------------------------------------------------

locals {
  state_objects = "${aws_s3_bucket.state.arn}/*"
  lock_objects  = "${aws_s3_bucket.state.arn}/*.tflock"
  prefix_arn    = "arn:${local.partition}"
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

data "aws_iam_policy_document" "apply_trust" {
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

    # Jobs that declare an environment get this subject instead of the branch
    # ref, so only the approved environment can reach the apply role.
    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc}:sub"
      values   = ["repo:${var.github_repository}:environment:${var.apply_environment}"]
    }
  }
}

# --- State access shared by both roles --------------------------------------

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

data "aws_iam_policy_document" "state_write" {
  source_policy_documents = [data.aws_iam_policy_document.state_read.json]

  statement {
    sid       = "WriteState"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = [local.state_objects]
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
  policy_arn = "${local.prefix_arn}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "terraform-state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.state_read.json
}

# --- Apply role --------------------------------------------------------------

# Write access is limited to what modules/baseline creates, matched by the
# name prefix or by the Stack and Project tags. Account-level settings have no
# resource ARN, so those statements use "*".
data "aws_iam_policy_document" "apply_baseline" {
  statement {
    sid = "ManageBaselineBuckets"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
    ]
    resources = ["${local.prefix_arn}:s3:::${var.name_prefix}-*"]
  }

  # The state bucket and its key share the name prefix and Project tag, so
  # explicit denies keep the apply role away from them.
  statement {
    sid    = "ProtectStateBucket"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket*",
      "s3:PutBucket*",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutReplicationConfiguration",
    ]
    resources = [aws_s3_bucket.state.arn]
  }

  statement {
    sid    = "ProtectBootstrapKeys"
    effect = "Deny"
    actions = [
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:DisableKey",
      "kms:DisableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateAlias",
      "kms:UpdateKeyDescription",
    ]
    resources = [
      aws_kms_key.state.arn,
      "${local.prefix_arn}:kms:*:${local.account_id}:${aws_kms_alias.state.name}",
    ]
  }

  statement {
    sid = "AccountLevelSettings"
    actions = [
      "ec2:DisableEbsEncryptionByDefault",
      "ec2:EnableEbsEncryptionByDefault",
      "s3:PutAccountPublicAccessBlock",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ManageTrail"
    actions = [
      "cloudtrail:AddTags",
      "cloudtrail:CreateTrail",
      "cloudtrail:DeleteTrail",
      "cloudtrail:PutEventSelectors",
      "cloudtrail:RemoveTags",
      "cloudtrail:StartLogging",
      "cloudtrail:StopLogging",
      "cloudtrail:UpdateTrail",
    ]
    resources = ["${local.prefix_arn}:cloudtrail:*:${local.account_id}:trail/${var.name_prefix}-*"]
  }

  statement {
    sid = "ManageAlertTopic"
    actions = [
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:TagResource",
      "sns:Unsubscribe",
      "sns:UntagResource",
    ]
    resources = ["${local.prefix_arn}:sns:*:${local.account_id}:${var.name_prefix}-*"]
  }

  statement {
    sid = "ManageBudget"
    actions = [
      "budgets:ModifyBudget",
      "budgets:TagResource",
      "budgets:UntagResource",
    ]
    resources = ["${local.prefix_arn}:budgets::${local.account_id}:budget/${var.name_prefix}-*"]
  }

  # modules/baseline tags its key with Stack = baseline. The bootstrap key
  # carries Stack = bootstrap, so it never matches these statements.
  statement {
    sid       = "CreateTaggedKey"
    actions   = ["kms:CreateKey", "kms:TagResource"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Stack"
      values   = ["baseline"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/Project"
      values   = [var.name_prefix]
    }
  }

  statement {
    sid = "ManageTaggedKey"
    actions = [
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:EnableKeyRotation",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateKeyDescription",
    ]
    resources = ["${local.prefix_arn}:kms:*:${local.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Stack"
      values   = ["baseline"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.name_prefix]
    }
  }

  statement {
    sid       = "ManageKeyAlias"
    actions   = ["kms:CreateAlias", "kms:DeleteAlias"]
    resources = ["${local.prefix_arn}:kms:*:${local.account_id}:alias/${var.name_prefix}-*"]
  }
}

resource "aws_iam_role" "apply" {
  name                 = "${var.name_prefix}-github-apply"
  description          = "Applies the account baseline from the protected GitHub environment"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "apply_readonly" {
  role       = aws_iam_role.apply.name
  policy_arn = "${local.prefix_arn}:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "apply_state" {
  name   = "terraform-state"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.state_write.json
}

resource "aws_iam_role_policy" "apply_baseline" {
  name   = "baseline-resources"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_baseline.json
}
