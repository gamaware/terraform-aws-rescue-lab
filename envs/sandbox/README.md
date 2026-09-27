# envs/sandbox

Root module for the sandbox account. It calls `modules/baseline` and keeps its state in the bucket that
`bootstrap` created, locked with an S3 lock file.

```bash
cp backend.hcl.example backend.hcl            # set the bucket name
cp terraform.tfvars.example terraform.tfvars  # set the alert email
terraform init -backend-config=backend.hcl
terraform plan
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0 |
| aws | ~> 6.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| baseline | ../../modules/baseline | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| budget\_alert\_emails | Email addresses for budget alerts. In CI this comes from the BUDGET\_ALERT\_EMAIL secret. | `list(string)` | `[]` | no |
| budget\_limit\_usd | Monthly cost budget in USD. | `number` | `20` | no |
| name\_prefix | Prefix for every resource name. Must match the bootstrap name\_prefix. | `string` | `"baseline-lab"` | no |
| region | AWS region for the baseline resources. | `string` | `"us-east-1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| budget\_alert\_topic\_arn | ARN of the SNS topic that receives budget alerts. |
| cloudtrail\_arn | ARN of the multi-region trail. |
| cloudtrail\_bucket | Name of the bucket that stores CloudTrail logs. |
<!-- END_TF_DOCS -->
