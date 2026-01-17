output "lambda_function_arn" {
  description = "ARN of the Compliance Guardian Lambda function"
  value       = aws_lambda_function.compliance_guardian.arn
}

output "lambda_function_name" {
  description = "Name of the Compliance Guardian Lambda function"
  value       = aws_lambda_function.compliance_guardian.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Compliance Guardian Lambda function"
  value       = aws_lambda_function.compliance_guardian.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.compliance_guardian_lambda.arn
}

output "lambda_role_name" {
  description = "Name of the Lambda execution role"
  value       = aws_iam_role.compliance_guardian_lambda.name
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.compliance_guardian_lambda.name
}
