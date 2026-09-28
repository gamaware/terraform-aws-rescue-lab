#!/usr/bin/env bash
# Online test of after/modules/app-storage in a real AWS account.
#
# Maintainer only, never in CI. It applies the module with a random name prefix
# and local state in a temporary directory, checks the outcomes the offline
# tests can only assume (public access blocked, KMS encryption, versioning, a
# role policy without wildcards), then destroys everything, even on failure,
# and confirms that nothing tagged purpose=portfolio-test is left.
#
#   make test-live                       # uses AWS profile "dev" in us-east-1
#   AWS_PROFILE_LIVE=dev AWS_REGION_LIVE=us-east-1 scripts/test-live.sh
#
# Cost: two small S3 buckets and one KMS key for a few minutes. The key is
# scheduled for deletion (the module sets a 30-day window); AWS does not bill
# keys pending deletion. Never commit any output of this script.
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
profile="${AWS_PROFILE_LIVE:-dev}"
region="${AWS_REGION_LIVE:-us-east-1}"
run_id="rl$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"

if ! [[ "$region" =~ ^[a-z]{2}(-[a-z]+)+-[0-9]$ ]]; then
  echo "AWS_REGION_LIVE must be a region code such as us-east-1, got $region" >&2
  exit 2
fi
case "$repo" in
  *'"'* | *'$'* | *'\'*)
    echo "repository path contains characters that cannot go into HCL: $repo" >&2
    exit 2
    ;;
esac

# The named profile is the only credential source: environment keys would win
# over it and could point at another account.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
export AWS_PROFILE="$profile" AWS_REGION="$region" TF_IN_AUTOMATION=1 TF_INPUT=0

echo "Account for this run (confirm before continuing):"
aws sts get-caller-identity --output table
if [ -t 0 ]; then
  read -r -p "Apply test resources with prefix $run_id in this account? [y/N] " answer
  [ "$answer" = "y" ] || exit 1
elif [ "${CONFIRM:-}" != "yes" ]; then
  echo "No terminal to confirm on: set CONFIRM=yes to run unattended." >&2
  exit 1
fi

work="$(mktemp -d)"
cleanup() {
  local rc=$?
  echo "==== destroy"
  terraform -chdir="$work" destroy -auto-approve -no-color >/dev/null || rc=1
  echo "==== leftovers tagged purpose=portfolio-test, run=$run_id"
  left="$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=purpose,Values=portfolio-test" "Key=run,Values=$run_id" \
    --query 'ResourceTagMappingList[].ResourceARN' --output text | tr '\t' '\n' | grep -v '^None$' || true)"
  leaks=""
  while read -r arn; do
    [ "$arn" != "" ] || continue
    # A destroyed KMS key stays listed while it waits for deletion; that is expected.
    if [[ "$arn" == *":kms:"* ]] &&
      [ "$(aws kms describe-key --key-id "$arn" --query KeyMetadata.KeyState --output text)" = "PendingDeletion" ]; then
      continue
    fi
    leaks="$leaks$arn"$'\n'
  done <<<"$left"
  # The tagging API does not list IAM roles, so check the role by name.
  if aws iam get-role --role-name "$run_id-dev-app" >/dev/null 2>&1; then
    leaks="${leaks}iam role $run_id-dev-app"$'\n'
  fi
  if [ "$leaks" != "" ]; then
    echo "LEAK: resources still exist:" >&2
    printf '%s' "$leaks" >&2
    rc=1
  else
    echo "none"
  fi
  if [ "$rc" -eq 0 ]; then
    rm -rf "$work"
  else
    echo "State kept in $work: run terraform -chdir=$work destroy after fixing the cause." >&2
  fi
  exit "$rc"
}
trap cleanup EXIT

cat >"$work/main.tf" <<EOF
terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.66"
    }
  }
}

provider "aws" {
  region = "$region"
  default_tags {
    tags = {
      purpose = "portfolio-test"
      run     = "$run_id"
    }
  }
}

module "storage" {
  source = "$repo/after/modules/app-storage"

  name_prefix   = "$run_id"
  environment   = "dev"
  force_destroy = true

  tags = {
    Owner      = "portfolio-test"
    CostCenter = "cc-0000"
  }
}

output "bucket_name" {
  value = module.storage.bucket_name
}

output "app_role_name" {
  value = split("/", module.storage.app_role_arn)[1]
}
EOF

echo "==== apply"
terraform -chdir="$work" init -no-color >/dev/null
terraform -chdir="$work" apply -auto-approve -no-color | tail -n 1

bucket="$(terraform -chdir="$work" output -raw bucket_name)"
role="$(terraform -chdir="$work" output -raw app_role_name)"
failures=0
check() {
  if [ "$2" = "$3" ]; then
    echo "pass  $1"
  else
    echo "FAIL  $1: expected $3, got $2"
    failures=$((failures + 1))
  fi
}

echo "==== assert"
check "public access fully blocked" \
  "$(aws s3api get-public-access-block --bucket "$bucket" \
    --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' \
    --output text)" "True	True	True	True"
check "default encryption is SSE-KMS" \
  "$(aws s3api get-bucket-encryption --bucket "$bucket" \
    --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
    --output text)" "aws:kms"
check "versioning enabled" "$(aws s3api get-bucket-versioning --bucket "$bucket" --query Status --output text)" "Enabled"
check "ACLs disabled" \
  "$(aws s3api get-bucket-ownership-controls --bucket "$bucket" \
    --query 'OwnershipControls.Rules[0].ObjectOwnership' --output text)" "BucketOwnerEnforced"
check "role has no attached managed policies" \
  "$(aws iam list-attached-role-policies --role-name "$role" --query 'length(AttachedPolicies)' --output text)" "0"
policies="$(aws iam list-role-policies --role-name "$role" --query 'PolicyNames' --output text)"
check "role has one inline policy" "$(wc -w <<<"$policies" | tr -d ' ')" "1"
# Same rule as the offline test: no "*" or "service:*" action, no NotAction,
# and no "*" resource. Object ARNs such as bucket/* are expected.
check "role policy has no wildcards" \
  "$(aws iam get-role-policy --role-name "$role" --policy-name "$policies" --query PolicyDocument --output json |
    jq '[.Statement[] | def list: if type == "array" then .[] else . end;
      ((.Action // [] | list | select(. == "*" or endswith(":*"))),
       (.NotAction // empty),
       (.Resource // [] | list | select(. == "*")))] | length')" "0"

[ "$failures" -eq 0 ]
