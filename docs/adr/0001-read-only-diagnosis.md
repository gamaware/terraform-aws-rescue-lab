# ADR 0001: Diagnose with a read-only role; no apply role in this repo

## Status

Accepted

## Context

A rescue engagement starts in an account nobody fully understands, often with state that is out of date. The first
deliverable is a diagnosis, and a diagnosis needs to read everything and change nothing. Clients are rightly wary of
handing write credentials to someone they met a week ago, and a write role held by the consultant becomes one more
thing to audit and remove at the end.

The earlier version of this repository had a second, environment-scoped apply role. It was sound, but it made the
repository the place where changes reach AWS, which is the client's pipeline's job.

## Decision

We give CI one role, `rescue-lab-github-plan`, with `ReadOnlyAccess` plus read access to the state objects and write
access to `*.tflock` lock files only. An explicit deny stops it from reading S3 objects outside the state bucket, SSM
parameters and Secrets Manager values, which `ReadOnlyAccess` would otherwise allow and a plan never needs. Pull
requests and the scheduled drift check assume it through GitHub OIDC, and its trust policy names this repository's
`pull_request` and `refs/heads/main` subjects exactly. We do not create an apply role. Fix PRs are merged here and
applied by the client, through their own reviewed pipeline or by a named engineer following
[`migration/README.md`](../../migration/README.md).

## Consequences

- The diagnosis can run on day one with a role the client can review in one screen.
- Nothing in this repository can change the client's infrastructure, even with a malicious workflow edit.
- Someone on the client side must run each apply. The runbook is written for that person.
- `plan` still takes the state lock, so the read-only role can create and delete lock files. That is the only write.

## Compliance

- `after/bootstrap/iam.tf` defines exactly one `aws_iam_role`; review blocks any second role.
- The workflows that reach AWS (`examples/workflows/plan.yml` and `drift.yml`, installed in the client's CI) assume
  `vars.AWS_PLAN_ROLE_ARN` only. This repository's own CI has no AWS access at all. zizmor and actionlint run on
  both folders on each PR.
- The plan job's trust subject is checked by AWS on every run: a job outside `pull_request` or `main` cannot assume it.

## Notes

Supersedes the plan/apply role split of the earlier baseline lab. Book reference: *GitHub Actions in Action*, 9.3.3
(OIDC scoped to the exact repository).
