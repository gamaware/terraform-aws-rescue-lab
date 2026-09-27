# Terraform diagnostic and repair plan: Harbor Goods

> **Sample deliverable. The client, the account and every name in it are fictional.** The code under review is
> [`before/`](../before/) in this repository, and the evidence below is real output from the tools named, run against
> that code and, for the plans, against a local AWS emulator (moto). Account `123456789012` is the AWS documentation
> placeholder.

## Summary

Harbor Goods runs its product image storage from two Terraform folders, `dev` and `prod`, whose state lives on one
engineer's laptop. The review found **10 findings: 2 critical, 3 high, 4 medium, 1 low**. The two critical ones are
live exposures today: the prod uploads bucket is publicly readable and listable, and the application role can do
anything in the account. The most urgent operational risk is F3: the next `terraform apply` in `prod` would try to
destroy the uploads bucket, because a resource was renamed without a `moved` block.

All ten are fixed in [`after/`](../after/) with **0 resources destroyed**: the prod plan for the full repair reads
`Plan: 1 to import, 12 to add, 7 to change, 0 to destroy.`

| Tool | `before/` | `after/` |
| --- | --- | --- |
| Checkov 3.2.529 (Terraform) | 23 passed, **47 failed** | 176 passed, **0 failed**, 21 skipped with inline reasons |
| tflint 0.61.0, preset `all` + AWS ruleset 0.49.0 | **12 issues** | **0 issues** |
| `terraform validate` | valid | valid |
| `terraform test` | none exist | 9 runs, 9 passed |

## Scope and method

- **In scope:** the Terraform in `before/dev` and `before/prod`, the local state of `prod`, and the resources that
  state points to.
- **Method:** read-only. Static analysis (Checkov, tflint, `terraform validate`), a code read, `terraform plan`
  against the current state, and `terraform state list`. No change was applied during the diagnosis. The CI role used
  for plans has `ReadOnlyAccess`, is denied object, parameter and secret reads, and can write only Terraform lock
  files ([ADR 0001](../docs/adr/0001-read-only-diagnosis.md)).
- **Ranking:** likelihood times impact. Critical means exploitable now or losing data on the next apply; high means a
  single mistake away from an outage or data loss; medium means it makes the next incident more likely or slower to
  fix; low means hygiene.

## Findings

| ID | Risk | Finding | Where |
| --- | --- | --- | --- |
| F1 | Critical | Uploads bucket is public: public-read ACL, public bucket policy, Block Public Access off | `before/*/main.tf` |
| F2 | Critical | Application role policy allows `*` on `*` | `before/*/main.tf` |
| F3 | High | A rename without `moved` makes the next prod apply destroy the uploads bucket | `before/prod/main.tf:17-20` |
| F4 | High | State is a local file on one laptop: no locking, no history, one copy | both folders |
| F5 | High | No KMS encryption, no versioning in prod, no lifecycle rules | `before/*/main.tf` |
| F6 | Medium | Environments are copy-pasted and have drifted apart | `before/dev` vs `before/prod` |
| F7 | Medium | Provider and Terraform versions unpinned, no lock file | `before/*/main.tf:5-11` |
| F8 | Medium | Hardcoded names, region and ARNs; no input validation | both folders |
| F9 | Medium | Access log bucket created by hand and unmanaged; no access logging | AWS console |
| F10 | Low | No resource has an owner or cost center tag | both folders |

### F1. Uploads bucket is public (Critical)

- **Where:** `before/prod/main.tf:22-66` (ownership, public access block, ACL, policy); same in `before/dev`.
- **Evidence:**

  ```text
  Check: CKV_AWS_20: "S3 Bucket has an ACL defined which allows public READ access."  FAILED  /prod/main.tf:18-20
  Check: CKV_AWS_53..56: block_public_acls / block_public_policy / ignore_public_acls /
         restrict_public_buckets                                                      FAILED  /prod/main.tf:31-38
  Check: CKV_AWS_70: "Ensure S3 bucket does not allow an action with any Principal"   FAILED  /prod/main.tf:50-66
  Check: CKV2_AWS_65: "Ensure access control lists for S3 buckets are disabled"       FAILED  /prod/main.tf:22-28
  ```

- **Risk:** a `public-read` bucket ACL lets anyone list every key, not only fetch known image URLs. Uploads that were
  never meant to be public (invoices, returns photos) are one listing away.
- **Fix:** Block Public Access on, `BucketOwnerEnforced` (ACLs disabled), a bucket policy that only denies non-TLS
  requests. Reset the ACL to `private` just before the apply, because S3 refuses to disable ACLs while a public grant
  exists ([runbook step 5](../migration/README.md#5-reset-the-public-acl)). Public image delivery moves behind
  CloudFront with origin access control (out of scope, see below).

### F2. Application role can do anything (Critical)

- **Where:** `before/prod/main.tf:83-96`, `before/dev/main.tf:97-110`.
- **Evidence:**

  ```text
  Check: CKV_AWS_62: "Ensure IAM policies that allow full "*-*" administrative privileges are not created"  FAILED
  Check: CKV_AWS_286: "Ensure IAM policies does not allow privilege escalation"                            FAILED
  Check: CKV2_AWS_40: "Ensure AWS IAM policy does not allow full IAM privileges"                            FAILED
  ... 6 more IAM checks FAILED for aws_iam_role_policy.app
  ```

- **Risk:** any code execution on an instance with this role (a vulnerable dependency, an SSRF to the metadata
  endpoint) is full account takeover, including creating new admin users.
- **Fix:** the module's policy lists six actions: `s3:ListBucket` on the bucket, `s3:GetObject`, `s3:PutObject` and
  `s3:DeleteObject` on its objects, `kms:Decrypt` and `kms:GenerateDataKey` on its key. A test fails if `*` returns.
  The policy keeps its name, so the change is an in-place update, not a replacement.

### F3. Next prod apply destroys the uploads bucket (High)

- **Where:** `before/prod/main.tf:17-20`. The resource was renamed from `uploads_bucket` to `uploads` in code; state
  still holds `aws_s3_bucket.uploads_bucket`.
- **Evidence:** `terraform plan` in `before/prod`, against its own state:

  ```text
    # aws_s3_bucket.uploads will be created
    # aws_s3_bucket.uploads_bucket will be destroyed
    # (because aws_s3_bucket.uploads_bucket is not in configuration)
    # aws_s3_bucket_acl.uploads must be replaced
    # aws_s3_bucket_ownership_controls.uploads must be replaced
    # aws_s3_bucket_policy.uploads must be replaced
    # aws_s3_bucket_public_access_block.uploads must be replaced
  Plan: 5 to add, 0 to change, 5 to destroy.
  ```

- **Risk:** the new bucket cannot be created while the old one holds the name, and the old one cannot be deleted
  while it holds objects. The apply stops partway, after some of the ten operations have run, leaving prod and state
  out of step. With `force_destroy` (as dev has), the delete would succeed and every uploaded object would be gone.
- **Fix:** freeze applies in `prod` until the migration. `after/envs/prod/moved.tf` chains
  `uploads_bucket -> uploads -> module.storage.aws_s3_bucket.this`, and the plan gate now fails any PR whose plan
  deletes or replaces a bucket ([ADR 0005](../docs/adr/0005-plan-json-policy-gate.md)).

### F4. Local state on one laptop (High)

- **Where:** neither folder has a `backend` block, so state is `terraform.tfstate` in the working directory.
- **Evidence:** `tflint` and Checkov do not flag this; the code read does. `terraform state list` works only on that
  laptop.
- **Risk:** two people applying at once corrupt state; a lost or wiped laptop means Terraform no longer knows what it
  manages; there is no history to roll back to. The file also holds every resource attribute in plain text.
- **Fix:** an S3 backend per root with `use_lockfile = true` (no DynamoDB table), in a versioned, KMS-encrypted,
  TLS-only bucket created by `after/bootstrap` ([ADR 0002](../docs/adr/0002-s3-backend-native-lockfile.md)). The move
  is the runbook in [`migration/`](../migration/README.md).

### F5. No managed encryption, no versioning in prod (High)

- **Where:** `before/prod/main.tf:18-20`; `before/dev` has versioning, prod does not.
- **Evidence:**

  ```text
  Check: CKV_AWS_145: "Ensure that S3 buckets are encrypted with KMS by default"      FAILED  dev and prod
  Check: CKV_AWS_21:  "Ensure all data stored in the S3 bucket have versioning enabled" FAILED  prod only
  Check: CKV2_AWS_61: "Ensure that an S3 bucket has a lifecycle configuration"       FAILED  dev and prod
  ```

- **Risk:** an overwrite or delete in prod, by a bug or by a person, cannot be undone. Default SSE-S3 encryption gives
  no key policy to restrict or audit who can decrypt.
- **Fix:** SSE-KMS with a rotating customer managed key and bucket keys (to keep KMS request cost low), versioning,
  and a lifecycle rule that expires old versions after 90 days and aborts stale multipart uploads.

### F6. Copy-pasted environments have drifted (Medium)

- **Where:** `before/dev/main.tf` vs `before/prod/main.tf`.
- **Evidence:** `diff before/dev/main.tf before/prod/main.tf`: dev has `force_destroy = true`, an
  `aws_s3_bucket_versioning` resource and a `var.env` variable; prod has none of these and has the rename from F3.
- **Risk:** a fix made in one folder is missed in the other, as versioning already was. Dev stops being a test of prod.
- **Fix:** one module, `after/modules/app-storage`, and two thin roots that pass only what differs
  ([ADR 0003](../docs/adr/0003-one-module-thin-roots.md)). `force_destroy` is now an input that validation rejects
  for `prod`.

### F7. Unpinned provider and Terraform version (Medium)

- **Where:** `before/prod/main.tf:5-11`, `before/dev/main.tf:5-11`; no `.terraform.lock.hcl` in either folder.
- **Evidence:**

  ```text
  before/prod/main.tf:7:11: Warning - Missing version constraint for provider "aws" in `required_providers`
  before/prod/main.tf:5:1: Warning - terraform "required_version" attribute is required
  ```

- **Risk:** the next `terraform init` on a new machine takes whatever AWS provider is newest. A major version can
  change resource behavior and produce a surprising plan on an unrelated change.
- **Fix:** `required_version = ">= 1.10.0, < 2.0.0"`, `aws ~> 6.66` in every root, and committed lock files with
  hashes for Linux and macOS. Dependabot proposes provider updates as reviewed PRs.

### F8. Hardcoded values and no validation (Medium)

- **Where:** bucket and role names, the region and the bucket ARN inside the policy JSON in both folders;
  `variable "env"` in `before/dev/main.tf:18`.
- **Evidence:**

  ```text
  before/dev/main.tf:18:1: Warning - `env` variable has no type (terraform_typed_variables)
  before/dev/main.tf:18:1: Notice - `env` variable has no description (terraform_documented_variables)
  ```

- **Risk:** `env = "production"` would create a new, unconfigured set of resources; a hand-edited ARN can point the
  policy at the wrong bucket without any error.
- **Fix:** names are computed from `name_prefix` and `environment`, both validated; ARNs come from resource
  attributes; tags, retention periods and the trusted service are validated inputs.

### F9. Unmanaged access log bucket (Medium)

- **Where:** `harbor-prod-access-logs` exists in the account but in no Terraform code.
- **Evidence:** the bucket is listed by `aws s3api list-buckets` and missing from `terraform state list`;
  `CKV_AWS_18 "Ensure the S3 bucket has access logging enabled"` fails for both uploads buckets.
- **Risk:** nobody knows its settings or who may write to it, and there is no access trail for the public bucket in
  F1, so the exposure cannot be scoped after the fact.
- **Fix:** an `import` block adopts the bucket in prod (`after/envs/prod/imports.tf`); the module sets versioning,
  SSE-S3 (the only encryption S3 log delivery supports), a delivery-only bucket policy and retention, and turns on
  server access logging for the uploads bucket.

### F10. No tags (Low)

- **Where:** every resource in both folders; there are no `tags` arguments and no provider `default_tags`.
- **Evidence:** `grep -c tags before/*/main.tf` returns 0 for both files.
- **Risk:** the storage bill cannot be split by team or environment, and nobody is named as owner in an incident.
- **Fix:** `Owner` and `CostCenter` are required module inputs (validation fails without them); `Environment` is
  added by the module and `ManagedBy`, `Repository` and `Stack` by each root's `default_tags`.

## Repair order

Each step is one pull request with its own plan, reviewed and applied before the next.

1. **Freeze prod applies** until step 5 (F3). No code change; a message to the team.
2. **Bootstrap the state backend** (F4): apply `after/bootstrap`, then move its own state into the new bucket.
3. **Migrate prod and dev state to S3** (F4): runbook steps 2-4. The plan must be unchanged by the move.
4. **Agree how product images are served** once the bucket is private: CloudFront in front, or an announced URL
   change (see F1). This gates step 5 in prod, not in dev.
5. **Refactor into the module with `moved`, `removed` and `import` blocks** (F3, F6, F7, F8, F9): the plan gate must
   show `0 to destroy`. This PR also carries F1, F2, F5 and F10, because they are in-place updates of the same
   resources; splitting them would mean writing the old, insecure settings into the new module first. Dev goes
   first, prod after a clean dev apply.

## Out of scope

- CloudFront with origin access control for public product images; F1 closes direct public access to the bucket.
- Cross-region replication and a disaster-recovery target for uploads (Checkov `CKV_AWS_144`, skipped inline with
  this reason).
- Bucket event notifications (`CKV2_AWS_62`), until a consumer exists.
- Moving the app off the EC2 role to a workload identity, and anything outside the two folders reviewed.
- Rotating any credentials that may have been read through F1 or used through F2. Recommended as an immediate client
  action; it needs CloudTrail history that this review did not have.

## How to reproduce

```bash
checkov -d before --framework terraform --compact --quiet                        # 47 failed checks
tflint --init && tflint --recursive --chdir=before --config="$PWD/.tflint.hcl"   # 12 issues
migration/demo/run-local-demo.sh     # F3 plan, the migration and the 0-to-destroy plan
```
