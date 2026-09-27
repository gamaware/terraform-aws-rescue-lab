# Contributing

Issues and pull requests are welcome. The repository is a portfolio piece, so changes should keep it small, correct
and easy to read.

## Setup

- Terraform 1.10 or later (CI uses 1.14.5), tflint 0.61, Checkov 3.2, jq, shellcheck
- `pre-commit install && pre-commit install --hook-type commit-msg`

## Workflow

1. Branch from `main`; never commit to `main` directly.
2. Keep `before/` as it is. It is the inherited codebase, and its findings are referenced by number in the report.
   If you change it, update `report/diagnostic-report.md` in the same PR.
3. Changes to `after/` must leave Checkov and tflint at zero failures and `terraform test` green. A Checkov skip is
   allowed only inline, next to the resource, with the reason.
4. Run `pre-commit run --all-files` before pushing.
5. Use Conventional Commits (`feat:`, `fix:`, `docs:`, `ci:`, `chore:`, `refactor:`, `test:`).
6. Record significant decisions as an ADR in `docs/adr/` and add a line to `CHANGELOG.md`.

## Review

Every PR needs one approving review from a code owner (`.github/CODEOWNERS`), passing checks and resolved
conversations. The plan comment is part of the review: read the summary line and the policy check result.
