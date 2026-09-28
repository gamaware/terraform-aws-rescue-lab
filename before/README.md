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

The code must stay valid Terraform (`terraform validate` runs on it in `make verify`), because the scanners need to
parse it. `make findings` scans this folder with the same Checkov and tflint configuration as `after/` and fails unless
the results match `report/evidence/` exactly
([ADR 0007](../docs/adr/0007-assert-intentional-findings.md)).
