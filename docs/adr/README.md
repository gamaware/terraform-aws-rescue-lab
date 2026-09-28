# Architecture decision records

Architecture decision records follow the *Fundamentals of Software Architecture* (2nd ed.) format. The Compliance
section names the automated check that keeps the decision true.

| Number | Title | Status |
| --- | --- | --- |
| [0001](0001-read-only-diagnosis.md) | Diagnose with a read-only role; no apply role in this repo | Accepted |
| [0002](0002-s3-backend-native-lockfile.md) | S3 backend with the native lockfile, no DynamoDB table | Accepted |
| [0003](0003-one-module-thin-roots.md) | One module, thin environment roots | Accepted |
| [0004](0004-declarative-refactoring.md) | Refactor state with moved, removed and import blocks, not CLI commands | Accepted |
| [0005](0005-plan-json-policy-gate.md) | Block plans that delete or replace stateful resources | Accepted |
| [0006](0006-native-terraform-test.md) | Native terraform test with mock_provider instead of Terratest | Accepted |
| [0007](0007-assert-intentional-findings.md) | Assert the intentional findings in before/ instead of skipping them | Accepted |
| [0008](0008-no-cloud-access-in-repo-ci.md) | This repository's CI has no cloud access; AWS-facing workflows ship as examples | Accepted |

New records copy the structure of an existing one and take the next number.
