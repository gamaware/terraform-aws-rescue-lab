# app-storage

Private storage for application uploads, with the settings the inherited code was missing:

- uploads bucket: Block Public Access, ACLs disabled (`BucketOwnerEnforced`), SSE-KMS with a rotating key and bucket
  keys, versioning, lifecycle for old versions, TLS-only bucket policy, server access logging
- access log bucket: the same controls with SSE-S3, which is what S3 log delivery supports, and a policy that lets
  only S3 logging write to it
- application role: `s3:ListBucket`, `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on this bucket and
  `kms:Decrypt`, `kms:GenerateDataKey` on its key; nothing else

Names are `<name_prefix>-<environment>-uploads`, `-access-logs` and `-app`. They match what the inherited code
created, so the environment roots can move existing resources into the module without replacing them.

## Usage

```hcl
module "storage" {
  source = "../../modules/app-storage"

  name_prefix = "harbor"
  environment = "prod"

  tags = {
    Owner      = "platform-team"
    CostCenter = "cc-1001"
  }
}
```

A complete call is in [`examples/basic`](examples/basic). Tests run offline with a mocked provider:

```bash
terraform init -backend=false
terraform test
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0, < 2.0.0 |
| aws | >= 6.0.0, < 7.0.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | >= 6.0.0, < 7.0.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_role.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.app_trust](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| environment | Environment name, used in resource names and the Environment tag. | `string` | n/a | yes |
| name\_prefix | Company or product prefix. Every resource name starts with name\_prefix and environment, so changing either replaces the buckets. | `string` | n/a | yes |
| tags | Tags for every resource in the module. Owner and CostCenter are required so spend can be traced. | `map(string)` | n/a | yes |
| access\_log\_retention\_days | Days to keep S3 server access logs. | `number` | `365` | no |
| app\_role\_service | AWS service principal allowed to assume the application role, for example ec2.amazonaws.com. | `string` | `"ec2.amazonaws.com"` | no |
| force\_destroy | Let terraform destroy delete non-empty buckets. Allowed only outside prod. | `bool` | `false` | no |
| noncurrent\_version\_retention\_days | Days to keep previous versions of uploaded objects before they expire. | `number` | `90` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| app\_role\_arn | ARN of the application role. Attach it to an instance profile or task definition. |
| bucket\_arn | ARN of the uploads bucket. |
| bucket\_name | Name of the uploads bucket. |
| kms\_key\_arn | ARN of the KMS key that encrypts the uploads bucket. |
| log\_bucket\_name | Name of the bucket that receives S3 server access logs. |
<!-- END_TF_DOCS -->
