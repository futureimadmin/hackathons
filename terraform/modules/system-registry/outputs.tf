# Outputs for System Registry Module

output "registry_table_name" {
  description = "Name of the system registry DynamoDB table"
  value       = aws_dynamodb_table.system_registry.name
}

output "registry_table_arn" {
  description = "ARN of the system registry DynamoDB table"
  value       = aws_dynamodb_table.system_registry.arn
}

output "system_registration_function_name" {
  description = "Name of the system registration Lambda function"
  value       = aws_lambda_function.system_registration.function_name
}

output "system_registration_function_arn" {
  description = "ARN of the system registration Lambda function"
  value       = aws_lambda_function.system_registration.arn
}

output "infrastructure_provisioner_function_name" {
  description = "Name of the infrastructure provisioner Lambda function"
  value       = aws_lambda_function.infrastructure_provisioner.function_name
}

output "infrastructure_provisioner_function_arn" {
  description = "ARN of the infrastructure provisioner Lambda function"
  value       = aws_lambda_function.infrastructure_provisioner.arn
}
