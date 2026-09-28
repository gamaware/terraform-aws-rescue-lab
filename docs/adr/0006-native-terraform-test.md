# 0006. Native terraform test with mock_provider instead of Terratest

## Status

Accepted

## Context

The module needs tests that run on every PR, need no AWS account and finish in seconds. Terratest has richer helpers
but needs Go, real infrastructure for most checks, and a second language in the repository. The client team writes
HCL, not Go.

## Decision

We test the module with `terraform test` and `mock_provider "aws"` (Terraform 1.7 or later). The tests check risks
from the diagnostic report: public access, encryption, wildcard IAM, stable names, required tags and rejected inputs.
`examples/basic` is applied against the mock as a fixture. The end-to-end proof of the migration runs against moto in
`migration/demo/run-local-demo.sh`.

## Consequences

- Tests run offline in CI and in pre-commit, with no credentials.
- A mock accepts any value the real API would reject. The moto demo and the PR plan against the real account cover
  that gap; neither is a substitute for a test run in a disposable AWS account.
- Values that are only known after apply need `command = apply` against the mock.

## Compliance

- The `verify` job in `.github/workflows/ci.yml` runs `make verify`, which includes `terraform test`, and fails the PR
  on any failed run.

## Notes

Book reference: *Terraform in Depth*, 9.1.3 and 9.4.3.
