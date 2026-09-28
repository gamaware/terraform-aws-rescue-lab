output "bucket_name" {
  description = "Name of the uploads bucket."
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN of the uploads bucket."
  value       = aws_s3_bucket.this.arn
}

output "log_bucket_name" {
  description = "Name of the bucket that receives S3 server access logs."
  value       = aws_s3_bucket.logs.bucket
}

output "kms_key_arn" {
  description = "ARN of the KMS key that encrypts the uploads bucket."
  value       = aws_kms_key.this.arn
}

output "app_role_arn" {
  description = "ARN of the application role. Attach it to an instance profile or task definition."
  value       = aws_iam_role.app.arn
}
