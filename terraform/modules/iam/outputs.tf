# Outputs for IAM Module

output "batch_job_execution_role_arn" {
  description = "ARN of the Batch job execution role"
  value       = aws_iam_role.batch_job_execution.arn
}

output "batch_job_execution_role_name" {
  description = "Name of the Batch job execution role"
  value       = aws_iam_role.batch_job_execution.name
}

output "batch_service_role_arn" {
  description = "ARN of the Batch service role"
  value       = aws_iam_role.batch_service.arn
}

output "batch_service_role_name" {
  description = "Name of the Batch service role"
  value       = aws_iam_role.batch_service.name
}

output "dms_replication_role_arn" {
  description = "ARN of the DMS replication role"
  value       = aws_iam_role.dms_replication.arn
}

output "dms_replication_role_name" {
  description = "Name of the DMS replication role"
  value       = aws_iam_role.dms_replication.name
}

output "glue_crawler_role_arn" {
  description = "ARN of the Glue crawler role"
  value       = aws_iam_role.glue_crawler.arn
}

output "glue_crawler_role_name" {
  description = "Name of the Glue crawler role"
  value       = aws_iam_role.glue_crawler.name
}
