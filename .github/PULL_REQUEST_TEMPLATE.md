# What and why

<!-- One or two sentences. Link the finding (F1-F10) or ADR this PR addresses. -->

## Plan summary

<!-- Paste the Plan: line for each root the plan comment covers. -->

- [ ] The plan policy check passed: no stateful resource is deleted or replaced
- [ ] Every address change has a `moved` block; every adopted resource has an `import` block

## Checklist

- [ ] `pre-commit run --all-files` passes
- [ ] `terraform test` passes in `after/modules/app-storage`
- [ ] Checkov and tflint report zero failures on `after/`
- [ ] Docs updated (README, runbook, ADR or CHANGELOG) where behavior changed
- [ ] No real account IDs, credentials or client names
