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
- Output excerpts in `migration/README.md` come from `migration/demo/run-local-demo.sh`. Rerun it after changing
  `before/prod`, `after/`, or the script, and update the excerpts.

## Commands

```bash
pre-commit run --all-files
terraform -chdir=after/modules/app-storage test
scripts/tests/test-check-plan.sh
MOTO_IAM_LOAD_MANAGED_POLICIES=true uvx --from 'moto[server,proxy]==5.2.3' moto_proxy -p 5005 &
migration/demo/run-local-demo.sh
```

## Content

Placeholders only (`YOUR_AWS_ACCOUNT_ID`, `123456789012`). English, dateless, Conventional Commits, no AI
attribution.
