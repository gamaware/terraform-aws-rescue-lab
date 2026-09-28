#!/usr/bin/env bash
# Asserts the scanner results the report is built on.
#
# before/ is insecure on purpose. Instead of skipping it, this script scans it
# and fails unless Checkov and tflint report exactly the findings recorded in
# report/evidence/, and unless every Checkov ID the report cites is one of them.
# after/ must stay at zero Checkov failures and zero tflint issues.
#
#   scripts/check-findings.sh            # verify (make findings)
#   scripts/check-findings.sh --update   # rewrite report/evidence/ after a deliberate change
#
# Exit codes: 0 = results match, 1 = drift from the evidence, 2 = usage error.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
evidence="$repo/report/evidence"
report="$repo/report/REPORT.md"
# CHECKOV may be a command with arguments, for example the pinned uvx call in the Makefile.
read -ra checkov <<<"${CHECKOV:-checkov}"
tflint="${TFLINT:-tflint}"
update=false

case "${1:-}" in
  "") ;;
  --update) update=true ;;
  *)
    echo "usage: $0 [--update]" >&2
    exit 2
    ;;
esac

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$repo"

# Checkov on before/: one line per failed check, sorted, plus the totals.
"${checkov[@]}" --directory before --config-file .checkov.yaml --framework terraform \
  --output json --soft-fail >"$work/checkov-before.json" 2>"$work/checkov-before.err" || {
  cat "$work/checkov-before.err" >&2
  echo "checkov failed on before/" >&2
  exit 1
}
if ! jq -e '.summary.resource_count > 0' "$work/checkov-before.json" >/dev/null 2>&1; then
  cat "$work/checkov-before.err" >&2
  echo "checkov scanned no resources in before/: refusing to compare or record empty evidence" >&2
  exit 1
fi
jq -r '"# checkov \(.summary.checkov_version): passed=\(.summary.passed) failed=\(.summary.failed)",
  ([.results.failed_checks[] | "\(.check_id) \(.file_path) \(.resource)"] | sort | .[])' \
  "$work/checkov-before.json" >"$work/before-checkov.txt"

# tflint on before/: compact lines, sorted. Exit code 2 means "issues found".
"$tflint" --init --config="$repo/.tflint.hcl" >/dev/null
rc=0
"$tflint" --recursive --chdir=before --config="$repo/.tflint.hcl" --format=compact \
  >"$work/tflint-raw.txt" 2>&1 || rc=$?
if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
  cat "$work/tflint-raw.txt" >&2
  echo "tflint failed on before/ with exit $rc" >&2
  exit 1
fi
{ grep -E '^before/' "$work/tflint-raw.txt" || true; } | sort >"$work/before-tflint.txt"

if [ "$update" = true ]; then
  mkdir -p "$evidence"
  cp "$work/before-checkov.txt" "$work/before-tflint.txt" "$evidence/"
  echo "updated report/evidence/. Review the diff and the counts in report/REPORT.md."
  exit 0
fi

failures=0
fail() {
  echo "FAIL  $*"
  failures=$((failures + 1))
}

for f in before-checkov.txt before-tflint.txt; do
  if diff -u "$evidence/$f" "$work/$f" >"$work/$f.diff"; then
    echo "pass  before/ matches report/evidence/$f ($(grep -vc '^#' "$work/$f") findings)"
  else
    cat "$work/$f.diff"
    fail "before/ findings drifted from report/evidence/$f"
  fi
done

# Every Checkov ID cited in the report must be a real before/ failure.
failed_ids="$(jq -r '.results.failed_checks[].check_id' "$work/checkov-before.json" | sort -u)"
while read -r id; do
  if ! grep -qx "$id" <<<"$failed_ids"; then
    fail "report cites $id, which before/ does not fail"
  fi
done < <(grep -oE 'CKV2?_AWS_[0-9]+' "$report" | sort -u)

# The headline counts in the report must match the scans.
checkov_failed="$(jq -r '.summary.failed' "$work/checkov-before.json")"
tflint_issues="$(wc -l <"$work/before-tflint.txt" | tr -d ' ')"
grep -q "\*\*$checkov_failed failed\*\*" "$report" || fail "report does not state $checkov_failed failed Checkov checks"
grep -q "\*\*$tflint_issues issues\*\*" "$report" || fail "report does not state $tflint_issues tflint issues"

# after/ is the repaired code: no failures at all.
if "${checkov[@]}" --directory after --config-file .checkov.yaml >"$work/checkov-after.txt" 2>&1; then
  echo "pass  after/ Checkov: $(grep -m1 -E '^Passed checks' "$work/checkov-after.txt" || echo 'no failures')"
else
  cat "$work/checkov-after.txt"
  fail "Checkov fails on after/"
fi
if "$tflint" --recursive --chdir=after --config="$repo/.tflint.hcl" --format=compact >"$work/tflint-after.txt" 2>&1; then
  echo "pass  after/ tflint: 0 issues"
else
  cat "$work/tflint-after.txt"
  fail "tflint reports issues in after/"
fi

[ "$failures" -eq 0 ] || exit 1
