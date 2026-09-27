# Security policy

Report a vulnerability privately through
[GitHub private vulnerability reporting](https://github.com/gamaware/terraform-aws-rescue-lab/security/advisories/new),
not in a public issue. The shared policy, response times and scope rules are in the
[gamaware/.github security policy](https://github.com/gamaware/.github/blob/main/SECURITY.md).

Specific to this repository:

- In scope: Terraform in `after/`, the workflows in `.github/workflows/` and `examples/workflows/`, the scripts, and
  anything that could leak credentials or reach the plan role from a fork.
- Out of scope: `before/`. It is insecure on purpose, and every weakness in it is a numbered finding in
  [`report/REPORT.md`](report/REPORT.md).
- The client, account and names are fictional. Account `123456789012` is the AWS documentation placeholder.
