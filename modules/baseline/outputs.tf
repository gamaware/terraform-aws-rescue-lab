output "cloudtrail_arn" {
  description = "ARN of the multi-region trail."
  value       = aws_cloudtrail.this.arn
}

output "cloudtrail_bucket" {
  description = "Name of the bucket that stores CloudTrail logs."
  value       = aws_s3_bucket.trail.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key for CloudTrail logs and budget alerts."
  value       = aws_kms_key.this.arn
}

output "budget_alert_topic_arn" {
  description = "ARN of the SNS topic that receives budget alerts."
  value       = aws_sns_topic.budget_alerts.arn
}

output "ebs_encryption_by_default" {
  description = "Whether EBS encryption by default is on in this region."
  value       = aws_ebs_encryption_by_default.this.enabled
}
