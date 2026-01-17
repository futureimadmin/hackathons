# Outputs for Glue Module

output "database_name" {
  description = "Name of the Glue database"
  value       = aws_glue_catalog_database.system_database.name
}

output "database_arn" {
  description = "ARN of the Glue database"
  value       = aws_glue_catalog_database.system_database.arn
}

output "crawler_name" {
  description = "Name of the Glue crawler"
  value       = aws_glue_crawler.prod_crawler.name
}

output "crawler_arn" {
  description = "ARN of the Glue crawler"
  value       = aws_glue_crawler.prod_crawler.arn
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function that triggers the crawler"
  value       = var.enable_lambda_trigger ? aws_lambda_function.trigger_crawler[0].arn : null
}

output "lambda_function_name" {
  description = "Name of the Lambda function that triggers the crawler"
  value       = var.enable_lambda_trigger ? aws_lambda_function.trigger_crawler[0].function_name : null
}
