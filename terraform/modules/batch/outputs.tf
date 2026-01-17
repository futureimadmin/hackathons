# Outputs for AWS Batch Module

output "compute_environment_arn" {
  description = "ARN of the Batch compute environment"
  value       = aws_batch_compute_environment.data_processing.arn
}

output "job_queue_arn" {
  description = "ARN of the Batch job queue"
  value       = aws_batch_job_queue.data_processing.arn
}

output "job_queue_name" {
  description = "Name of the Batch job queue"
  value       = aws_batch_job_queue.data_processing.name
}

output "raw_to_curated_job_definition_arn" {
  description = "ARN of the raw-to-curated job definition"
  value       = aws_batch_job_definition.raw_to_curated.arn
}

output "raw_to_curated_job_definition_name" {
  description = "Name of the raw-to-curated job definition"
  value       = aws_batch_job_definition.raw_to_curated.name
}

output "curated_to_prod_job_definition_arn" {
  description = "ARN of the curated-to-prod job definition"
  value       = aws_batch_job_definition.curated_to_prod.arn
}

output "curated_to_prod_job_definition_name" {
  description = "Name of the curated-to-prod job definition"
  value       = aws_batch_job_definition.curated_to_prod.name
}

output "batch_job_role_arn" {
  description = "ARN of the Batch job IAM role"
  value       = aws_iam_role.batch_job.arn
}

output "batch_execution_role_arn" {
  description = "ARN of the Batch execution IAM role"
  value       = aws_iam_role.batch_execution.arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.data_processor.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.data_processor.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.batch_jobs.name
}
