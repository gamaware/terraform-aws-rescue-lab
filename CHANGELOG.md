# Changelog

All notable changes to this repository. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the module in `after/modules/app-storage` follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `make verify`: one offline entry point for local runs and CI (tool versions, fmt, validate, `terraform test`,
  asserted findings, plan gate fixtures, shell lint, PDF check).
- `scripts/check-findings.sh` and `report/evidence/`: `before/` must fail exactly the recorded Checkov and tflint
  findings, the report may cite only real ones, and `after/` must have none (ADR 0007).
- `report/REPORT.pdf`, generated from `report/REPORT.md` with pandoc and Typst and checked byte for byte.
- `make demo` (moto started and stopped for the migration replay) and `make test-live` (maintainer-only online test
  with guaranteed teardown).
- Context and state migration diagrams in `docs/diagrams/`, the cover image, the social preview (spec and render), ADRs
  0007 and 0008, `.editorconfig`, `.claude/` hooks that format edited files and protect generated ones, and an OSSF
  Scorecard workflow.
- `before/`: inherited Harbor Goods codebase with local state, copy-pasted environments, a public bucket, a wildcard
  IAM policy and a rename that would destroy the prod bucket.
- `report/REPORT.md`: ten findings ranked by risk, with tool evidence, fix and repair order.
- `after/modules/app-storage` 0.1.0: private, versioned, KMS-encrypted uploads bucket, access log bucket and a
  least-privilege application role, with input validation, `examples/basic` and mocked `terraform test`.
- `after/envs/dev` and `after/envs/prod`: thin roots with the S3 backend, `use_lockfile`, `moved`, `removed` and
  `import` blocks.
- `migration/`: local-to-S3 state migration runbook with verification and rollback, replayable against moto.
- `scripts/check-plan.sh`: plan JSON gate that blocks deletes and replacements of stateful resources.
- `examples/workflows/plan.yml` (plan-on-PR with the read-only OIDC role and the plan gate) and `drift.yml`.
- ADRs 0001-0006, CODEOWNERS, SECURITY.md.

### Changed

- README follows the portfolio template: what this proves, deliverable links, scenario and acceptance criteria,
  architecture, verification, repository map, decisions, gates, limits.
- `report/diagnostic-report.md` renamed to `report/REPORT.md`; CODEOWNERS moved to the repository root.
- `plan.yml` and `drift.yml` moved to `examples/workflows/`; this repository's CI has no cloud access (ADR 0008).
- `ci.yml` is a thin caller: `make verify` plus the shared lint, secret and security workflows from
  `gamaware/.github`, pinned by commit SHA. The non-blocking `before-findings` job is replaced by the asserted findings.
- `.checkov.yaml` no longer skips `before/`.

- Repository renamed from `terraform-aws-baseline-lab` to `terraform-aws-rescue-lab`. The account baseline module and
  the sandbox environment were removed; `bootstrap` moved to `after/bootstrap`.
- Checkov runs from a pinned pip install (3.2.529) instead of the old container action, which ignored inline skips.

### Removed

- `CONTRIBUTING.md`, issue templates and the PR template: inherited from `gamaware/.github`.
- The apply role and `apply.yml`. See ADR 0001.
