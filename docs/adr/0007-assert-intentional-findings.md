# ADR 0007: Assert the intentional findings in before/ instead of skipping them

## Status

Accepted

## Context

`before/` is insecure on purpose: it is the codebase the client handed over, and every weakness in it is a numbered
finding in `report/REPORT.md`. The earlier version kept Checkov away from it with a global `skip-path` and scanned it
in a non-blocking CI job that only uploaded the reports. That kept CI green, but nothing noticed when a scanner
upgrade, an edit to `before/` or a typo in the report made the report disagree with the code. A skipped folder also
reads like a hidden problem to anyone skimming the configuration.

## Decision

We scan `before/` with the same `.checkov.yaml` and `.tflint.hcl` as `after/`, and assert the result.
`scripts/check-findings.sh` records the expected findings in `report/evidence/before-checkov.txt` (one line per check,
file and resource, plus the totals) and `report/evidence/before-tflint.txt`, and fails when:

- the findings differ from the evidence files in any way, extra or missing;
- the report cites a Checkov ID that `before/` does not fail;
- the report's headline counts differ from the scans;
- `after/` has any Checkov failure or tflint issue.

`make evidence` rewrites the evidence files after a deliberate change, so the diff shows exactly what moved.

## Consequences

- Report, evidence and code cannot drift apart without a red build.
- A scanner upgrade that adds or renames checks fails the build until the evidence and the report are updated. The
  `tools` target pins the versions the evidence was recorded with, so this happens on purpose, in one PR.
- Pre-commit still excludes `before/` from the Checkov and tflint hooks, because those hooks fail on any finding; the
  assertion runs in `make verify` instead.

## Compliance

`make verify` runs `scripts/check-findings.sh` locally and in CI. The negative cases were checked by hand: removing
an evidence line and citing an unknown check ID both fail the script.

## Notes

Follows the portfolio standard's rule that intentional findings are asserted, never blanket-skipped. Book reference:
*Terraform in Depth*, 7.4-7.5 (policy checks with reasons next to each exception).
