output "cloudtrail_arn" {
  description = "ARN of the multi-region trail."
  value       = module.baseline.cloudtrail_arn
}

output "cloudtrail_bucket" {
  description = "Name of the bucket that stores CloudTrail logs."
  value       = module.baseline.cloudtrail_bucket
}

output "budget_alert_topic_arn" {
  description = "ARN of the SNS topic that receives budget alerts."
  value       = module.baseline.budget_alert_topic_arn
}
