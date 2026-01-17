# Outputs for Market Intelligence Lambda Module

output "lambda_function_arn" {
  description = "ARN of the Market Intelligence Lambda function"
  value       = aws_lambda_function.market_intelligence.arn
}

output "lambda_function_name" {
  description = "Name of the Market Intelligence Lambda function"
  value       = aws_lambda_function.market_intelligence.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Market Intelligence Lambda function"
  value       = aws_lambda_function.market_intelligence.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.market_intelligence_lambda.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.market_intelligence_lambda.name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.market_intelligence.name
}
