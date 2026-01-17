# Outputs for Monitoring Module

output "data_pipeline_dashboard_arn" {
  description = "ARN of the data pipeline CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.data_pipeline.dashboard_arn
}

output "api_performance_dashboard_arn" {
  description = "ARN of the API performance CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.api_performance.dashboard_arn
}

output "ml_performance_dashboard_arn" {
  description = "ARN of the ML performance CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.ml_performance.dashboard_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = aws_cloudtrail.audit_trail.arn
}

output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "log_group_names" {
  description = "Names of CloudWatch log groups"
  value = {
    lambda      = [for lg in aws_cloudwatch_log_group.lambda_logs : lg.name]
    batch       = aws_cloudwatch_log_group.batch_logs.name
    api_gateway = aws_cloudwatch_log_group.api_gateway_logs.name
    cloudtrail  = aws_cloudwatch_log_group.cloudtrail.name
  }
}

output "alarm_arns" {
  description = "ARNs of CloudWatch alarms"
  value = {
    dms_replication_lag = aws_cloudwatch_metric_alarm.dms_replication_lag.arn
    lambda_errors       = aws_cloudwatch_metric_alarm.lambda_errors.arn
    api_gateway_5xx     = aws_cloudwatch_metric_alarm.api_gateway_5xx.arn
    batch_job_failures  = aws_cloudwatch_metric_alarm.batch_job_failures.arn
  }
}
