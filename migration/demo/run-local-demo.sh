#!/usr/bin/env bash
# Replays the whole prod state migration against moto, a local AWS API
# emulator, so it runs without an AWS account and costs nothing. moto runs as
# an HTTPS proxy, so the Terraform code runs unmodified: no endpoint overrides.
#
#   MOTO_ACCOUNT_ID=111122223333 MOTO_IAM_LOAD_MANAGED_POLICIES=true \
#     uvx --from 'moto[server,proxy]==5.2.3' moto_proxy -p 5005    # another terminal
#   migration/demo/run-local-demo.sh
#
# It works in a temporary copy of the repository and prints each step's
# output. The excerpts in migration/README.md come from this script.
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
proxy="${MOTO_PROXY:-http://127.0.0.1:5005}"
ca_bundle="${MOTO_CA_BUNDLE:-$(uvx --from 'moto[server,proxy]==5.2.3' python -c \
  'import os, moto.moto_proxy as p; print(os.path.join(os.path.dirname(p.__file__), "ca.crt"))')}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

case "$proxy" in
  http://127.0.0.1:* | http://localhost:*) ;;
  *)
    echo "MOTO_PROXY must point at localhost, got $proxy" >&2
    exit 1
    ;;
esac

# Fake credentials only: every AWS call goes to moto through the proxy, which
# signs its own certificates with the CA above. Provider downloads bypass it.
unset AWS_PROFILE AWS_SESSION_TOKEN AWS_SECURITY_TOKEN AWS_ENDPOINT_URL AWS_ENDPOINT_URL_S3 AWS_ENDPOINT_URL_STS
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_REGION=us-east-1 AWS_DEFAULT_REGION=us-east-1
export HTTPS_PROXY="$proxy" HTTP_PROXY="$proxy" AWS_CA_BUNDLE="$ca_bundle"
export NO_PROXY="registry.terraform.io,releases.hashicorp.com,github.com,objects.githubusercontent.com"
export TF_IN_AUTOMATION=1 TF_INPUT=0

# moto runs as the example production account (MOTO_ACCOUNT_ID above), and
# after/bootstrap names the state bucket after the account ID.
state_bucket="rescue-lab-tfstate-111122223333"
repo_var="github_repository=YOUR_GITHUB_OWNER/terraform-aws-rescue-lab"

step() { printf '\n==== %s\n' "$*"; }
tf() { terraform -chdir="$1" "${@:2}" -no-color; }

cat >"$work/backend.hcl" <<EOF
bucket = "$state_bucket"
region = "us-east-1"
EOF

curl -fsS --proxy "$proxy" -X POST http://motoapi.amazonaws.com/moto-api/reset >/dev/null || {
  echo "moto_proxy is not reachable at $proxy" >&2
  exit 1
}

step "0. Recreate the inherited prod stack, as it was before the rename"
cp -R "$repo/before/prod" "$work/legacy"
sed -i.orig -e 's/"aws_s3_bucket" "uploads"/"aws_s3_bucket" "uploads_bucket"/' \
  -e 's/aws_s3_bucket\.uploads\./aws_s3_bucket.uploads_bucket./g' "$work/legacy/main.tf"
tf "$work/legacy" init >/dev/null
tf "$work/legacy" apply -auto-approve | tail -n 3
mv "$work/legacy/main.tf.orig" "$work/legacy/main.tf"
aws s3api put-object --bucket harbor-prod-uploads --key images/sample.jpg --body "$repo/LICENSE" >/dev/null
aws s3api create-bucket --bucket harbor-prod-access-logs >/dev/null
echo "Seeded one object in harbor-prod-uploads and a hand-made harbor-prod-access-logs bucket."

step "F3 evidence: plan of the inherited code against its own state"
tf "$work/legacy" plan | grep -E '^  # |^Plan:' || true

step "1. Bootstrap: first apply with local state, then move that state into its own bucket"
cp -R "$repo/after" "$work/after"
boot="$work/after/bootstrap"
mv "$boot/backend.tf" "$boot/backend.tf.off"
tf "$boot" init >/dev/null
tf "$boot" apply -auto-approve -var "$repo_var" | tail -n 1
# moto only: the proxy hands requests to moto as plain HTTP, and moto applies
# Deny statements without their conditions, so the aws:SecureTransport deny
# would block every state read. Real S3 needs no such step.
aws s3api delete-bucket-policy --bucket "$state_bucket"
mv "$boot/backend.tf.off" "$boot/backend.tf"
tf "$boot" init -migrate-state -force-copy -backend-config="$work/backend.hcl" | grep -iE 'copy|migrat|success' || true
rm -f "$boot/terraform.tfstate" "$boot/terraform.tfstate.backup"
tf "$boot" state list | wc -l | sed 's/^ */bootstrap resources now in S3 state: /'

step "2. Freeze and back up the prod local state"
mkdir -p "$work/backups"
cp "$work/legacy/terraform.tfstate" "$work/backups/prod.tfstate"
(cd "$work/backups" && shasum -a 256 prod.tfstate)
jq -r '"lineage=\(.lineage) serial=\(.serial) resources=\(.resources | length)"' "$work/backups/prod.tfstate"
tf "$work/legacy" state list | sort >"$work/backups/prod.addresses"
cat "$work/backups/prod.addresses"

step "3. Migrate: copy the local state into after/envs/prod and init with the S3 backend"
prod="$work/after/envs/prod"
cp "$work/backups/prod.tfstate" "$prod/terraform.tfstate"
tf "$prod" init -migrate-state -force-copy -backend-config="$work/backend.hcl" | grep -iE 'copy|migrat|backend|success' || true
rm -f "$prod/terraform.tfstate" "$prod/terraform.tfstate.backup"

step "4. Verify: same resources as the backup, state object in S3"
tf "$prod" state pull >"$work/migrated.tfstate"
jq -r '"lineage=\(.lineage) serial=\(.serial) resources=\(.resources | length)"' "$work/migrated.tfstate"
tf "$prod" state list | sort >"$work/migrated.addresses"
diff "$work/backups/prod.addresses" "$work/migrated.addresses" && echo "state list: identical to the backup"
diff <(jq -S .resources "$work/backups/prod.tfstate") <(jq -S .resources "$work/migrated.tfstate") &&
  echo "resource attributes: identical to the backup"
aws s3api list-objects-v2 --bucket "$state_bucket" --query 'Contents[].Key' --output text

step "5. Reset the public ACL to private before ACLs are disabled"
aws s3api put-bucket-acl --bucket harbor-prod-uploads --acl private
echo "ACL reset."

step "6. Plan the refactor: moved blocks, removed block, import block"
tf "$prod" plan -out=tfplan >"$work/plan.txt"
grep -E '^  # |no longer be managed|^Plan:' "$work/plan.txt" | grep -v 'will be read during apply\|(config refers\|(depends on'

tf "$prod" show -json tfplan >"$work/plan.json"

step "7. Policy check on the plan JSON"
"$repo/scripts/check-plan.sh" "$work/plan.json"

step "8. Apply, then prove there is nothing left to change"
tf "$prod" apply tfplan | tail -n 1
tf "$prod" plan -detailed-exitcode | grep -E '^No changes|found no differences'
aws s3api list-objects-v2 --bucket harbor-prod-uploads --query 'Contents[].Key' --output text |
  sed 's/^/objects still in harbor-prod-uploads: /'
