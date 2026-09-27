# Copilot review instructions

- `before/` is intentionally insecure evidence for `report/REPORT.md`. Do not suggest fixing it.
- In `after/`, flag wildcard IAM actions or resources, missing input validation, missing tags, and any change to a
  resource name that `moved` blocks depend on.
- In workflows, require SHA-pinned actions, `permissions: {}` at the top, per-job least privilege, and `env` instead
  of inline `${{ }}` expressions in `run` steps. There must be no AWS role other than the read-only plan role.
- Shell scripts must pass shellcheck and quote every variable.
