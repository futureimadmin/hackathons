# Outputs for EventBridge Module

output "raw_bucket_event_rules" {
  description = "Map of raw bucket event rule ARNs"
  value = {
    for k, v in aws_cloudwatch_event_rule.raw_bucket_events : k => v.arn
  }
}

output "curated_bucket_event_rules" {
  description = "Map of curated bucket event rule ARNs"
  value = {
    for k, v in aws_cloudwatch_event_rule.curated_bucket_events : k => v.arn
  }
}

output "eventbridge_role_arn" {
  description = "ARN of the EventBridge IAM role"
  value       = aws_iam_role.eventbridge.arn
}
