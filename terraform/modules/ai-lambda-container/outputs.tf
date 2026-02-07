output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.ai_lambda.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.ai_lambda.arn
}

output "invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.ai_lambda.invoke_arn
}

output "qualified_arn" {
  description = "Qualified ARN of the Lambda function"
  value       = aws_lambda_function.ai_lambda.qualified_arn
}
