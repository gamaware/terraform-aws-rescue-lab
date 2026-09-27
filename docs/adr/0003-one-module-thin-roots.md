# 0003. One module, thin environment roots

## Status

Accepted

## Context

`before/dev` and `before/prod` are copies of each other that drifted: dev has versioning and `force_destroy`, prod
has neither, and a rename happened in one folder only (findings F3 and F6). Every fix had to be made twice and was
not.

## Decision

We move the shared resources into one module, `after/modules/app-storage`, with validated inputs, required tags and
a working `examples/basic`. Each environment is a thin root in `after/envs/<env>` that holds only what differs:
backend key, environment name, cost center, and the `moved`, `removed` and `import` blocks for its own state.

Inside this repository the roots call the module by relative path, so a module change and its effect on both
environments are reviewed in one PR. When a client wants environments upgraded one at a time, the module moves to its
own repository and each root pins a tag: `source = "git::https://github.com/ORG/terraform-aws-app-storage.git?ref=v1.2.0"`.
The CHANGELOG records each version.

## Consequences

- A fix lands once and reaches both environments; drift between them needs an explicit input.
- Resource names are computed as `<name_prefix>-<environment>-<suffix>` and must match the names the old code created,
  or the move becomes a replacement. The module tests assert those names.
- With a path source, dev and prod always run the same module code. Staged rollouts need the tag-pinned form above.

## Compliance

- tflint (preset `all`) runs on every module and root and enforces typed, documented variables and outputs.
- `terraform test` in `after/modules/app-storage/tests` checks input validation and naming.
- `examples/basic` is applied against the mock provider in the same test run.

## Notes

Book references: *Infrastructure as Code*, 3rd edition, chapter 7; *Terraform in Depth*, 8.4.2 and 9.2.2.
