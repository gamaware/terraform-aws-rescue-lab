# Maps every address in the old flat state (before/prod) to its place in the
# module. Terraform reads these during plan and moves the state entries instead
# of destroying and recreating the resources. Keep them until every copy of the
# old state has been migrated; they are harmless afterwards.

# Someone renamed uploads_bucket to uploads in code without a moved block, so the
# old plan wanted to destroy the bucket (finding F3). This chain fixes both steps.
moved {
  from = aws_s3_bucket.uploads_bucket
  to   = aws_s3_bucket.uploads
}

moved {
  from = aws_s3_bucket.uploads
  to   = module.storage.aws_s3_bucket.this
}

moved {
  from = aws_s3_bucket_ownership_controls.uploads
  to   = module.storage.aws_s3_bucket_ownership_controls.this
}

moved {
  from = aws_s3_bucket_public_access_block.uploads
  to   = module.storage.aws_s3_bucket_public_access_block.this
}

moved {
  from = aws_s3_bucket_policy.uploads
  to   = module.storage.aws_s3_bucket_policy.this
}

moved {
  from = aws_iam_role.app
  to   = module.storage.aws_iam_role.app
}

moved {
  from = aws_iam_role_policy.app
  to   = module.storage.aws_iam_role_policy.app
}

# BucketOwnerEnforced (set by the module) disables ACLs, so the old public-read
# ACL resource is dropped from state without an API call. Reset the ACL to
# private first: see migration/README.md, step 5.
removed {
  from = aws_s3_bucket_acl.uploads

  lifecycle {
    destroy = false
  }
}
