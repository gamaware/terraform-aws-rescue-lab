output "bucket_name" {
  description = "Name of the uploads bucket."
  value       = module.storage.bucket_name
}

output "log_bucket_name" {
  description = "Name of the access log bucket."
  value       = module.storage.log_bucket_name
}

output "app_role_arn" {
  description = "ARN of the application role."
  value       = module.storage.app_role_arn
}
