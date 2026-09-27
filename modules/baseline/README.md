# modules/baseline

Account baseline for one AWS account and region:

- multi-region CloudTrail with log file validation, KMS-encrypted, into a private bucket
- account-level S3 Block Public Access
- EBS encryption by default
- a monthly cost budget that alerts an encrypted SNS topic, with optional email subscriptions

Tests live in the repository-level `tests/` directory.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |
| aws | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| aws | ~> 6.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_budgets_budget.monthly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_cloudtrail.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudtrail) | resource |
| [aws_ebs_encryption_by_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_account_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block) | resource |
| [aws_s3_bucket.trail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.trail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.trail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.trail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.trail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.trail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.trail](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_sns_topic.budget_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.budget_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.budget_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.budget_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.trail_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| name\_prefix | Prefix for every resource name. Must match the prefix the bootstrap apply role was scoped to. | `string` | n/a | yes |
| budget\_alert\_emails | Email addresses subscribed to the budget alert SNS topic. Each address must confirm the subscription. | `list(string)` | `[]` | no |
| budget\_alert\_thresholds | Percentages of the budget that trigger an alert. Actual spend for each, plus a forecast alert at 100. | `list(number)` | ```[ 50, 80, 100 ]``` | no |
| budget\_limit\_usd | Monthly cost budget in USD. | `number` | `20` | no |
| cloudtrail\_log\_retention\_days | Days to keep CloudTrail log files before they expire. | `number` | `365` | no |
| force\_destroy\_trail\_bucket | Allow terraform destroy to empty the CloudTrail bucket. Keep false outside a throwaway lab. | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| budget\_alert\_topic\_arn | ARN of the SNS topic that receives budget alerts. |
| cloudtrail\_arn | ARN of the multi-region trail. |
| cloudtrail\_bucket | Name of the bucket that stores CloudTrail logs. |
| ebs\_encryption\_by\_default | Whether EBS encryption by default is on in this region. |
| kms\_key\_arn | ARN of the KMS key for CloudTrail logs and budget alerts. |
<!-- END_TF_DOCS -->
