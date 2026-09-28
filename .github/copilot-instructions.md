# Copilot review instructions

- `before/` is intentionally insecure evidence for `report/REPORT.md`. Do not suggest fixing it.
- In `after/`, flag wildcard IAM actions or resources, missing input validation, missing tags, and any change to a
  resource name that `moved` blocks depend on. Exception: the KMS key policy statement that gives the account root
  `kms:*` on `"*"` is the AWS default key policy and stays. `Deny` statements may use wildcard actions, resources
  or principals, since they only remove access.
- In workflows, require SHA-pinned actions, `permissions: {}` at the top, only the permissions each job needs, and
  `env` instead of inline `${{ }}` expressions in `run` steps. There must be no AWS role other than the read-only
  plan role.
- Shell scripts must pass shellcheck and quote every variable.
