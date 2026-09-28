#!/usr/bin/env bash
# Policy check on a Terraform plan in JSON form (terraform show -json tfplan).
#
# Fails when the plan deletes or replaces a stateful resource: S3 buckets
# (including the Terraform state bucket), KMS keys, DynamoDB tables, RDS and
# EFS. Other deletes are listed as warnings for the reviewer. The same script
# runs locally and in CI:
#
#   terraform plan -out=tfplan
#   terraform show -json tfplan > plan.json
#   scripts/check-plan.sh plan.json
#
# Exit codes: 0 = allowed, 1 = blocked, 2 = usage or input error.
set -euo pipefail

PROTECTED_TYPES='["aws_s3_bucket","aws_kms_key","aws_dynamodb_table","aws_db_instance","aws_rds_cluster","aws_efs_file_system"]'

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
  echo "usage: $0 <plan.json>" >&2
  exit 2
fi
plan_json="$1"

if ! jq -e '.format_version and (.resource_changes | type == "array" or . == null)' "$plan_json" >/dev/null; then
  echo "error: $plan_json is not the output of terraform show -json <planfile>" >&2
  exit 2
fi

# "replace" shows up as ["delete","create"] or ["create","delete"], so matching
# on "delete" covers both.
deletes="$(jq -r '
  [.resource_changes[]? | select(.change.actions | index("delete"))
   | "  \(.address) (\(.change.actions | join(",")))"] | .[]' "$plan_json")"

blocked="$(jq -r --argjson protected "$PROTECTED_TYPES" '
  [.resource_changes[]? | select(.change.actions | index("delete"))
   | select(.type as $t | $protected | index($t))
   | "  \(.address)"] | .[]' "$plan_json")"

summary="$(jq -r '
  [.resource_changes[]?.change.actions] as $a
  | "create=\([$a[] | select(. == ["create"])] | length)"
    + " update=\([$a[] | select(. == ["update"])] | length)"
    + " delete=\([$a[] | select(. == ["delete"])] | length)"
    + " replace=\([$a[] | select(index("delete") and index("create"))] | length)"
    + " forget=\([$a[] | select(. == ["forget"])] | length)"' "$plan_json")"
moves="$(jq '[.resource_changes[]? | select(.previous_address != null)] | length' "$plan_json")"
imports="$(jq '[.resource_changes[]? | select(.change.importing != null)] | length' "$plan_json")"

echo "plan: $summary moved=$moves import=$imports"

if [ "$deletes" != "" ]; then
  echo "deletes and replacements in this plan:"
  echo "$deletes"
fi

if [ "$blocked" != "" ]; then
  echo "BLOCKED: the plan deletes or replaces stateful resources:" >&2
  echo "$blocked" >&2
  echo "Add a moved block, or split the change into its own reviewed PR with a data backup plan." >&2
  exit 1
fi

echo "OK: no stateful resource is deleted or replaced."
