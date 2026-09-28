# 0002. S3 backend with the native lockfile, no DynamoDB table

## Status

Accepted

## Context

The inherited code kept state in a local `terraform.tfstate` on one laptop (finding F4). That means no locking, no
history, no encryption at rest under the client's control, and a single point of loss. Terraform 1.10 added
`use_lockfile` to the S3 backend: the lock is an object next to the state, written with a conditional request, so
the DynamoDB lock table that used to be required is no longer needed. Terraform 1.11 made the lockfile generally
available and deprecated `dynamodb_table`.

## Decision

We store every root's state in one S3 bucket created by `after/bootstrap`, one key per root
(`bootstrap/`, `envs/dev/`, `envs/prod/`), with `encrypt = true` and `use_lockfile = true`. The bucket is versioned,
encrypted with a customer managed KMS key, blocks public access, denies non-TLS requests and has `prevent_destroy`.
Backend settings that differ per account (bucket, region) stay out of the code in a git-ignored `backend.hcl`.

## Consequences

- One fewer resource to create, pay for and grant access to.
- Every state write is a new object version, so a bad write can be rolled back from S3 (see the rollback section of
  the migration runbook).
- Terraform 1.11 or later is required everywhere; every root declares `required_version = ">= 1.11.0, < 2.0.0"`.
- The bootstrap stack has to start with local state and migrate itself, because it creates the bucket.

## Compliance

- `terraform validate` in CI fails if a backend block is malformed.
- The plan policy check (ADR 0005) fails on any plan that deletes or replaces `aws_s3_bucket.state`.
- Checkov runs on `after/bootstrap` in CI and fails on an unencrypted or public state bucket.

## Notes

Book reference: *Infrastructure as Code*, 3rd edition, chapter 19 (state and deployment services).
