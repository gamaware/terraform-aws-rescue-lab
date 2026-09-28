# 0008. This repository's CI has no cloud access; AWS-facing workflows ship as examples

## Status

Accepted

## Context

The rescue lab used to run `plan.yml` on every pull request that touched `after/`, assuming a read-only role through
GitHub OIDC, and `drift.yml` weekly. Both need repository variables that point at a real account. In the public
repository those variables are empty, so the jobs either failed or had to be skipped, and a public repository whose
pull request checks can request an OIDC token is one workflow edit away from a credential exposure. The portfolio
standard also requires that pull request checks never get cloud credentials or `id-token`.

## Decision

`.github/workflows/` holds only checks that need no cloud access: `make verify` and the shared lint, secret and
security scans. `plan.yml` and `drift.yml` move, unchanged in behavior, to `examples/workflows/`. They are part of the
deliverable: a client copies them into the repository that holds their real Terraform, after applying
`after/bootstrap` and setting `AWS_PLAN_ROLE_ARN`, `TF_STATE_BUCKET` and `AWS_REGION`.

## Consequences

- No workflow in this repository can request an OIDC token or reach AWS.
- The plan comment and the drift check are no longer exercised here. The plan gate they call is still tested
  offline against fixtures, and the full plan, gate and apply sequence is replayed against moto by `make demo`.
- actionlint and zizmor lint `examples/workflows/` as well, so the examples stay valid.

## Compliance

- `.github/workflows/ci.yml` grants `contents: read` only; zizmor and actionlint run on both workflow folders.
- Review rejects any `id-token: write` under `.github/workflows/`.

## Notes

ADR 0001 still holds for a client installation: the examples assume only the read-only plan role.
