# Changelog

All notable changes to this repository. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the module in `after/modules/app-storage` follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `before/`: inherited Harbor Goods codebase with local state, copy-pasted environments, a public bucket, a wildcard
  IAM policy and a rename that would destroy the prod bucket.
- `report/REPORT.md`: ten findings ranked by risk, with tool evidence, fix and repair order.
- `after/modules/app-storage` 0.1.0: private, versioned, KMS-encrypted uploads bucket, access log bucket and a
  least-privilege application role, with input validation, `examples/basic` and mocked `terraform test`.
- `after/envs/dev` and `after/envs/prod`: thin roots with the S3 backend, `use_lockfile`, `moved`, `removed` and
  `import` blocks.
- `migration/`: local-to-S3 state migration runbook with verification and rollback, replayable against moto.
- `scripts/check-plan.sh`: plan JSON gate that blocks deletes and replacements of stateful resources.
- CI: `ci.yml` (fmt, validate, test, tflint, Checkov, actionlint, zizmor), non-blocking `before-findings` report,
  `plan.yml` with the read-only OIDC role and the plan gate, `drift.yml`.
- ADRs 0001-0006, CODEOWNERS, SECURITY.md, CONTRIBUTING.md, PR and issue templates.

### Changed

- Repository renamed from `terraform-aws-baseline-lab` to `terraform-aws-rescue-lab`. The account baseline module and
  the sandbox environment were removed; `bootstrap` moved to `after/bootstrap`.
- Checkov runs from a pinned pip install (3.2.529) instead of the old container action, which ignored inline skips.

### Removed

- The apply role and `apply.yml`. See ADR 0001.
