# ADR 0004: Refactor state with moved, removed and import blocks, not CLI commands

## Status

Accepted

## Context

Moving resources into a module changes every address in state. The old way is a list of `terraform state mv`,
`state rm` and `import` commands run by hand against production state, with no review, no plan and no record. One typo
and the next plan destroys a bucket full of customer images. The inherited prod code already has one such accident: a
rename without a move (finding F3).

## Decision

We express every state change as code in the environment root:

- `moved` blocks for each old address, including a chain for the earlier rename;
- a `removed` block with `destroy = false` for the public ACL resource, which has no place once ACLs are disabled;
- an `import` block for the access log bucket that was created by hand.

The plan shows each of these (`has moved to`, `will no longer be managed`, `will be imported`) before anything
happens, and the reviewer approves the plan, not a shell history.

## Consequences

- The refactor is a normal PR with a normal plan, and it can be replayed on any copy of the state.
- The blocks stay in the code until every copy of the old state is migrated. They are harmless afterwards.
- `moved` cannot change a resource's type or its name in AWS. Names therefore stay exactly as before (ADR 0003).
- Terraform 1.7 or later is required for `removed`; the roots already require 1.11.

## Compliance

- The plan policy check (ADR 0005) fails when a move is missing, because a missing move shows as a delete.
- `migration/demo/run-local-demo.sh` replays the migration against moto and ends with a plan that has no changes.

## Notes

Book reference: *Terraform in Depth*, 9.6.3 (refactoring with `moved`).
