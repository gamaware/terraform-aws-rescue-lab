#!/usr/bin/env bash
# Runs scripts/check-plan.sh against small plan fixtures and checks the exit
# code of each. Used by pre-commit and CI.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
check="$here/../check-plan.sh"
failures=0

expect() {
  local want="$1" fixture="$2" got=0
  "$check" "$here/fixtures/$fixture" >/dev/null 2>&1 || got=$?
  if [ "$got" -eq "$want" ]; then
    echo "pass  $fixture (exit $got)"
  else
    echo "FAIL  $fixture: expected exit $want, got $got"
    failures=$((failures + 1))
  fi
}

expect 0 safe-refactor.json
expect 0 delete-unprotected.json
expect 1 replace-state-bucket.json
expect 1 rename-without-moved.json
expect 2 missing-file.json

exit "$failures"
