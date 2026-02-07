# Outputs for Data Pipeline Lambdas Module

output "raw_to_curated_function_arn" {
  description = "ARN of the raw-to-curated Lambda function"
  value       = aws_lambda_function.raw_to_curated.arn
}

output "raw_to_curated_function_name" {
  description = "Name of the raw-to-curated Lambda function"
  value       = aws_lambda_function.raw_to_curated.function_name
}

output "curated_to_prod_function_arn" {
  description = "ARN of the curated-to-prod Lambda function"
  value       = aws_lambda_function.curated_to_prod.arn
}

output "curated_to_prod_function_name" {
  description = "Name of the curated-to-prod Lambda function"
  value       = aws_lambda_function.curated_to_prod.function_name
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_role.arn
}

# ECR Repository URLs
output "raw_to_curated_ecr_url" {
  description = "ECR repository URL for raw-to-curated Lambda"
  value       = aws_ecr_repository.raw_to_curated.repository_url
}

output "curated_to_prod_ecr_url" {
  description = "ECR repository URL for curated-to-prod Lambda"
  value       = aws_ecr_repository.curated_to_prod.repository_url
}
