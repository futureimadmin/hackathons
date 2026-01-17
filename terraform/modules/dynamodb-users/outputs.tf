# Outputs for DynamoDB Users Table Module

output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.users.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.users.arn
}

output "table_id" {
  description = "ID of the DynamoDB table"
  value       = aws_dynamodb_table.users.id
}

output "stream_arn" {
  description = "ARN of the DynamoDB stream"
  value       = aws_dynamodb_table.users.stream_arn
}

output "email_index_name" {
  description = "Name of the email GSI"
  value       = "email-index"
}
