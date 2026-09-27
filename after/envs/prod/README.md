# envs/prod

Thin root for the `prod` environment. It sets the backend key, the environment name and the cost center, calls
[`modules/app-storage`](../../modules/app-storage), and holds the blocks that map the old flat state from
[`before/prod`](../../../before/prod) into the module: `moved.tf`, `imports.tf` and a `removed` block.

```bash
cp backend.hcl.example backend.hcl   # set the state bucket name
terraform init -backend-config=backend.hcl
terraform plan
```

The first init against existing local state follows [`migration/README.md`](../../../migration/README.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0, < 2.0.0 |
| aws | ~> 6.66 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| storage | ../../modules/app-storage | n/a |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| region | AWS region for this environment. | `string` | `"us-east-1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| app\_role\_arn | ARN of the application role. |
| bucket\_name | Name of the uploads bucket. |
| log\_bucket\_name | Name of the access log bucket. |
<!-- END_TF_DOCS -->
