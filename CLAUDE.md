# CLAUDE.md

Portfolio repository for a Terraform rescue service: diagnose an inherited codebase, rank findings, fix it, migrate
local state to S3. The client ("Harbor Goods") is fictional.

## Layout rules

- `before/` is evidence. Do not fix it. It must stay valid Terraform and keep its Checkov and tflint findings. If it
  changes, update the finding numbers, line references and counts in `report/REPORT.md`.
- `after/` must stay at zero Checkov failures, zero tflint issues and green `terraform test`. Checkov skips go inline
  with a reason, never in `.checkov.yaml`.
- Resource names in `after/modules/app-storage` must match the names `before/` created, or `moved` blocks turn into
  replacements. The module tests assert them.
- Every address change in `after/envs/*` needs a `moved` block; `scripts/check-plan.sh` fails on stateful deletes.
- Output excerpts in `migration/README.md` come from `migration/demo/run-local-demo.sh`. Rerun it (`make demo`) after
  changing `before/prod`, `after/`, or the script, and update the excerpts.
- `report/evidence/` is scanner output asserted by `make findings`. After a deliberate change to `before/` or a
  scanner upgrade, run `make evidence`, review the diff, and update the counts and IDs in `report/REPORT.md`.
- `report/REPORT.pdf` is generated: edit `report/REPORT.md`, then `make report`. `make verify` compares bytes, so
  use pandoc 3.11.
- Workflows that reach AWS live in `examples/workflows/`, never in `.github/workflows/` (ADR 0008).
- Diagrams: edit the `.drawio` sources in `docs/diagrams/` and export SVG and PNG with the draw.io CLI.

## Commands

```bash
make verify              # every offline check, same as CI
make demo                # migration replay against moto
make report              # rebuild report/REPORT.pdf
make evidence            # rewrite report/evidence/ after a deliberate change
pre-commit run --all-files
```

`make test-live` touches a real account (profile `dev`). Run it only when the maintainer asks.

## Content

Placeholders only (`YOUR_AWS_ACCOUNT_ID`, `123456789012`). English, dateless, Conventional Commits, no AI
attribution.
