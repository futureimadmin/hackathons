output "lambda_function_arn" {
  description = "ARN of the Retail Copilot Lambda function"
  value       = aws_lambda_function.retail_copilot.arn
}

output "lambda_function_name" {
  description = "Name of the Retail Copilot Lambda function"
  value       = aws_lambda_function.retail_copilot.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Retail Copilot Lambda function"
  value       = aws_lambda_function.retail_copilot.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.retail_copilot_lambda.arn
}

output "conversation_table_name" {
  description = "Name of the DynamoDB conversations table"
  value       = aws_dynamodb_table.conversations.name
}

output "conversation_table_arn" {
  description = "ARN of the DynamoDB conversations table"
  value       = aws_dynamodb_table.conversations.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.retail_copilot_lambda.name
}
