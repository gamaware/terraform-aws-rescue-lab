# before/

The inherited codebase, kept as received from the fictional client "Harbor Goods". It is intentionally wrong: every
problem here is a numbered finding in [`report/REPORT.md`](../report/REPORT.md), and
[`after/`](../after/) is the repaired version.

```text
dev/main.tf    copy of prod with hand edits (versioning, force_destroy, a variable)
prod/main.tf   public uploads bucket, wildcard IAM policy, a resource rename without a moved block
```

Both folders keep their state in a local `terraform.tfstate` on one engineer's laptop, so there is no state file in
the repository and no locking.

The code must stay valid Terraform (`terraform validate` runs on it in CI), because the scanners need to parse it.
Its Checkov and tflint findings are the point, so both tools skip this folder in the blocking checks and run on it in
the non-blocking `before-findings` job, which uploads the reports as a build artifact.
