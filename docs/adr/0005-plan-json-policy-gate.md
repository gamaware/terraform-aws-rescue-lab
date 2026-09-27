# ADR 0005: Block plans that delete or replace stateful resources

## Status

Accepted

## Context

Checkov and tflint read code. They cannot see that a harmless-looking rename makes Terraform destroy a bucket, because
that depends on what is in state. Only the plan knows. A human reviewer can miss one `-/+` line in a 400-line plan.

## Decision

Every PR plan is converted with `terraform show -json` and checked by `scripts/check-plan.sh`. The script fails when
any resource of a stateful type (`aws_s3_bucket`, `aws_kms_key`, `aws_dynamodb_table`, `aws_db_instance`,
`aws_rds_cluster`, `aws_efs_file_system`) has `delete` in its actions, which covers both deletes and replacements. That
includes the Terraform state bucket in `after/bootstrap`. Other deletes pass, listed for the reviewer. The script
uses only `jq`, so it runs the same way locally and in CI.

## Consequences

- A missing `moved` block fails the PR instead of reaching an apply.
- A deliberate removal of a stateful resource needs its own PR that changes the protected list or runs outside this
  gate, with the data backup plan written down. That friction is the point.
- The check is only as good as its type list; new stateful types have to be added.

## Compliance

- `scripts/tests/test-check-plan.sh` runs the script against fixtures, including a replaced state bucket and a rename
  without a move, in pre-commit and CI.
- The `plan` workflow runs the check for each root before posting the plan comment.

## Notes

A policy engine (OPA/conftest) would allow richer rules. For one rule, `jq` is easier to read and has no extra
dependency. Book references: *Infrastructure as Code*, 3rd edition, chapter 18; *Policy as Code*, chapter 12.
