output "bucket_name" {
  description = "Name of the uploads bucket."
  value       = module.storage.bucket_name
}

output "app_role_arn" {
  description = "ARN of the application role."
  value       = module.storage.app_role_arn
}
