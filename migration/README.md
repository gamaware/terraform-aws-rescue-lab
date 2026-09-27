# State migration runbook: local state to the S3 backend

Moves `before/prod` from a local `terraform.tfstate` to the S3 backend used by `after/envs/prod`, then applies the
refactor with `moved`, `removed` and `import` blocks. Dev follows the same steps with `after/envs/dev` and its own key.
Findings F3, F4 and F9 in the [diagnostic report](../report/REPORT.md) explain why.

Every excerpt below is real output from [`demo/run-local-demo.sh`](demo/run-local-demo.sh), which replays the whole
runbook against [moto](https://github.com/getmoto/moto), a local AWS emulator. Run it yourself; it needs no AWS
account. Hashes, lineages and key IDs change on every run; counts and plan lines do not.

```bash
MOTO_IAM_LOAD_MANAGED_POLICIES=true uvx --from 'moto[server,proxy]==5.2.3' moto_proxy -p 5005   # terminal 1
migration/demo/run-local-demo.sh                                                                 # terminal 2
```

## Before you start

- Terraform 1.10 or later, the AWS CLI, `jq`, and administrator credentials for the target account.
- One named operator runs every step, and a second person reviews each plan.
- Nobody else runs `terraform` against `prod` from the start of step 2 to the end of step 8.

## 1. Bootstrap the state bucket

`after/bootstrap` creates the bucket its own state will live in, so its first apply uses local state.

```bash
cd after/bootstrap
cp terraform.tfvars.example terraform.tfvars          # set github_repository
mv backend.tf backend.tf.off
terraform init && terraform apply
cp backend.hcl.example backend.hcl                     # bucket = terraform output -raw state_bucket
mv backend.tf.off backend.tf
terraform init -migrate-state -backend-config=backend.hcl
rm terraform.tfstate terraform.tfstate.backup          # after checking terraform state list
```

```text
Successfully configured the backend "s3"! Terraform will automatically
Terraform has been successfully initialized!
bootstrap resources now in S3 state: 21
```

## 2. Freeze and back up the local state

Announce the freeze. On the laptop that holds the prod state:

```bash
cd before/prod
mkdir -p ~/tfstate-backups
cp terraform.tfstate ~/tfstate-backups/prod.tfstate
shasum -a 256 ~/tfstate-backups/prod.tfstate
jq -r '"lineage=\(.lineage) serial=\(.serial) resources=\(.resources | length)"' ~/tfstate-backups/prod.tfstate
terraform state list | sort > ~/tfstate-backups/prod.addresses
```

```text
60b0b13c9c9a20906266928c4ba95440d58d6c1d9f3a2c8c4d1b2fb8401a5cae  prod.tfstate
lineage=7ba582a9-f034-2339-0a39-70f46f6935c2 serial=8 resources=7
aws_iam_role_policy.app
aws_iam_role.app
aws_s3_bucket_acl.uploads
aws_s3_bucket_ownership_controls.uploads
aws_s3_bucket_policy.uploads
aws_s3_bucket_public_access_block.uploads
aws_s3_bucket.uploads_bucket
```

Store the backup and its hash somewhere other than the laptop. The last line is finding F3: state still holds the
old name.

## 3. Migrate

Copy the state file next to the new root and initialize it with the S3 backend. Terraform finds the local file and
copies it into the bucket.

```bash
cd after/envs/prod
cp backend.hcl.example backend.hcl                     # same bucket as bootstrap
cp ~/tfstate-backups/prod.tfstate terraform.tfstate
terraform init -migrate-state -backend-config=backend.hcl
rm terraform.tfstate terraform.tfstate.backup          # the S3 copy is now the source of truth
```

```text
Initializing the backend...
Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
Terraform has been successfully initialized!
```

## 4. Verify the copy

```bash
terraform state pull > /tmp/migrated.tfstate
terraform state list | sort | diff ~/tfstate-backups/prod.addresses - && echo "state list: identical to the backup"
diff <(jq -S .resources ~/tfstate-backups/prod.tfstate) <(jq -S .resources /tmp/migrated.tfstate) \
  && echo "resource attributes: identical to the backup"
aws s3api list-objects-v2 --bucket rescue-lab-tfstate-YOUR_AWS_ACCOUNT_ID --query 'Contents[].Key' --output text
```

```text
lineage=c5cb0105-7eda-6557-b8e1-5bffae8e1264 serial=1 resources=7
state list: identical to the backup
resource attributes: identical to the backup
bootstrap/terraform.tfstate     envs/prod/terraform.tfstate
```

The migrated copy starts a new lineage at serial 1, so the resources are compared instead of the header. A side
effect is useful: Terraform refuses to `state push` the old laptop file over the new one without `-force`.

## 5. Reset the public ACL

S3 refuses to set `BucketOwnerEnforced` while the bucket ACL grants access to anyone but the owner. The module sets
it, so reset the ACL first. This is the only change made outside Terraform, and it is the fix for F1 anyway.

```bash
aws s3api put-bucket-acl --bucket harbor-prod-uploads --acl private
```

## 6. Plan the refactor

```bash
terraform plan -out=tfplan
```

```text
 # aws_s3_bucket_acl.uploads will no longer be managed by Terraform, but will not be destroyed
  # module.storage.aws_iam_role.app will be updated in-place
  # (moved from aws_iam_role.app)
  # module.storage.aws_iam_role_policy.app will be updated in-place
  # (moved from aws_iam_role_policy.app)
  # module.storage.aws_kms_key.this will be created
  # module.storage.aws_s3_bucket.logs will be updated in-place
  # (imported from "harbor-prod-access-logs")
  # module.storage.aws_s3_bucket.this will be updated in-place
  # (moved from aws_s3_bucket.uploads_bucket)
  # module.storage.aws_s3_bucket_ownership_controls.this will be updated in-place
  # (moved from aws_s3_bucket_ownership_controls.uploads)
  # module.storage.aws_s3_bucket_policy.this will be updated in-place
  # (moved from aws_s3_bucket_policy.uploads)
  # module.storage.aws_s3_bucket_public_access_block.this will be updated in-place
  # (moved from aws_s3_bucket_public_access_block.uploads)
  ... 11 more "will be created" lines: KMS alias, versioning, encryption, lifecycle and logging settings
Plan: 1 to import, 12 to add, 7 to change, 0 to destroy.
```

Read it for three things: every old address shows `moved from`, the log bucket shows `imported from`, and the summary
says `0 to destroy`.

## 7. Run the plan gate

```bash
terraform show -json tfplan > plan.json
../../../scripts/check-plan.sh plan.json
```

```text
plan: create=12 update=7 delete=0 replace=0 forget=1 moved=6 import=1
OK: no stateful resource is deleted or replaced.
```

In the client's repository, [`examples/workflows/plan.yml`](../examples/workflows/plan.yml) runs the same script on
every PR ([ADR 0005](../docs/adr/0005-plan-json-policy-gate.md)).

## 8. Apply and confirm

```bash
terraform apply tfplan
terraform plan -detailed-exitcode       # exit code 0 means no changes
aws s3api list-objects-v2 --bucket harbor-prod-uploads --query 'Contents[].Key' --output text
```

```text
No changes. Your infrastructure matches the configuration.
and found no differences, so no changes are needed.
objects still in harbor-prod-uploads: images/sample.jpg
```

Lift the freeze. Keep the laptop backup until the next successful plan in CI.

## Rollback

| Failure point | State of the world | Rollback |
| --- | --- | --- |
| Steps 2-4 (before apply) | Nothing in AWS changed; the laptop file and the S3 copy both exist | Delete the S3 object `envs/prod/terraform.tfstate`, keep using `before/prod` with the backup. |
| Step 5 | Bucket ACL is private | `aws s3api put-bucket-acl --bucket harbor-prod-uploads --acl public-read` restores public listing. Only if the business needs it back before CloudFront exists. |
| Step 6-7 | Plan shows a destroy or the gate fails | Stop. Do not apply. Add the missing `moved` block and plan again. |
| Step 8, apply fails partway | Some settings applied, state records what succeeded | Fix forward: rerun `terraform plan`, read it, apply again. State is consistent with AWS after a partial apply. |
| After step 8, state object damaged or overwritten | Infrastructure fine, state wrong | The state bucket is versioned: find the previous version with `aws s3api list-object-versions --bucket <state-bucket> --prefix envs/prod/`, then `aws s3api copy-object --copy-source "<state-bucket>/envs/prod/terraform.tfstate?versionId=<id>" --bucket <state-bucket> --key envs/prod/terraform.tfstate`. |
| After step 8, need the old configuration back | Resources are private and managed by the module | Revert the PR and write reverse `moved` blocks; a code revert alone would plan destroys, and the gate would block it. |

## moto differences

The demo matches real AWS except for one step: moto's proxy hands requests to moto over plain HTTP, and moto applies
bucket policy `Deny` statements without their conditions, so the state bucket's `aws:SecureTransport` deny would
block every state read. The demo deletes that policy right after the bootstrap apply. Real S3 needs no such step.
