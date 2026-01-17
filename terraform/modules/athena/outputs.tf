# Outputs for Athena Module

output "workgroup_name" {
  description = "Name of the Athena workgroup"
  value       = aws_athena_workgroup.analytics.name
}

output "workgroup_arn" {
  description = "ARN of the Athena workgroup"
  value       = aws_athena_workgroup.analytics.arn
}

output "workgroup_id" {
  description = "ID of the Athena workgroup"
  value       = aws_athena_workgroup.analytics.id
}

output "query_results_bucket" {
  description = "Name of the S3 bucket for query results"
  value       = aws_s3_bucket.query_results.bucket
}

output "query_results_bucket_arn" {
  description = "ARN of the S3 bucket for query results"
  value       = aws_s3_bucket.query_results.arn
}

output "named_queries" {
  description = "Map of named query names to their IDs"
  value = {
    sample_orders         = aws_athena_named_query.sample_orders_query.id
    daily_sales_summary   = aws_athena_named_query.daily_sales_summary.id
    top_products          = aws_athena_named_query.top_products.id
    customer_lifetime_value = aws_athena_named_query.customer_lifetime_value.id
  }
}
