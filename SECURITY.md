# Security policy

This is a public demonstration repository. The environment it describes is fictional, and every account ID, bucket
name and email address in it is a placeholder.

## Reporting a vulnerability

If you find a security problem in the code, workflows or documentation, for example a way to reach the plan role from
a fork or a secret that should not be here, report it privately through
[GitHub private vulnerability reporting](https://github.com/gamaware/terraform-aws-rescue-lab/security/advisories/new).
Please do not open a public issue.

You can expect an acknowledgement within three business days and a fix or a written answer within two weeks.

## Scope

- In scope: Terraform in `after/`, GitHub Actions workflows, scripts, and anything that could leak credentials.
- Out of scope: `before/`, which is insecure on purpose and documented finding by finding in
  `report/diagnostic-report.md`.

## Supported versions

Only the `main` branch is maintained.
