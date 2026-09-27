# examples/basic

The smallest working call of `app-storage`. `tests/unit.tftest.hcl` applies it against the mocked provider, so the
example cannot silently go stale.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0, < 2.0.0 |
| aws | ~> 6.66 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| storage | ../.. | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| region | AWS region for the example. | `string` | `"us-east-1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| app\_role\_arn | ARN of the application role. |
| bucket\_name | Name of the uploads bucket. |
<!-- END_TF_DOCS -->
