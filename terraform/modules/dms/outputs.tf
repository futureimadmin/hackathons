output "replication_instance_arn" {
  description = "ARN of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_arn
}

output "replication_instance_id" {
  description = "ID of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_id
}

output "replication_instance_private_ips" {
  description = "Private IP addresses of the DMS replication instance"
  value       = aws_dms_replication_instance.main.replication_instance_private_ips
}

output "source_endpoint_arn" {
  description = "ARN of the source MySQL endpoint"
  value       = aws_dms_endpoint.source.endpoint_arn
}

output "source_endpoint_id" {
  description = "ID of the source MySQL endpoint"
  value       = aws_dms_endpoint.source.endpoint_id
}

output "target_endpoint_arns" {
  description = "Map of system names to target S3 endpoint ARNs"
  value       = { for k, v in aws_dms_endpoint.target : k => v.endpoint_arn }
}

output "target_endpoint_ids" {
  description = "Map of system names to target S3 endpoint IDs"
  value       = { for k, v in aws_dms_endpoint.target : k => v.endpoint_id }
}

output "replication_task_arns" {
  description = "Map of task IDs to replication task ARNs"
  value       = { for k, v in aws_dms_replication_task.tasks : k => v.replication_task_arn }
}

output "replication_task_ids" {
  description = "Map of task IDs to replication task IDs"
  value       = { for k, v in aws_dms_replication_task.tasks : k => v.replication_task_id }
}

output "dms_s3_role_arn" {
  description = "ARN of the IAM role for DMS S3 access"
  value       = aws_iam_role.dms_s3_role.arn
}

output "dms_vpc_role_arn" {
  description = "ARN of the IAM role for DMS VPC management"
  value       = aws_iam_role.dms_vpc_role.arn
}

output "dms_cloudwatch_role_arn" {
  description = "ARN of the IAM role for DMS CloudWatch Logs"
  value       = aws_iam_role.dms_cloudwatch_role.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for DMS"
  value       = aws_cloudwatch_log_group.dms_logs.name
}
