output "state_bucket" {
  description = "Name of the S3 bucket that holds Terraform state. Use it in envs/sandbox/backend.hcl."
  value       = aws_s3_bucket.state.id
}

output "state_kms_key_arn" {
  description = "ARN of the KMS key that encrypts the state bucket."
  value       = aws_kms_key.state.arn
}

output "plan_role_arn" {
  description = "Set as the AWS_PLAN_ROLE_ARN repository variable."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Set as the AWS_APPLY_ROLE_ARN repository variable."
  value       = aws_iam_role.apply.arn
}
