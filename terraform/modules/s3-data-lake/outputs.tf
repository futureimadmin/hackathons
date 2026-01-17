# Outputs for S3 Data Lake Module

output "raw_bucket_id" {
  description = "ID of the raw S3 bucket"
  value       = aws_s3_bucket.raw.id
}

output "raw_bucket_arn" {
  description = "ARN of the raw S3 bucket"
  value       = aws_s3_bucket.raw.arn
}

output "raw_bucket_name" {
  description = "Name of the raw S3 bucket"
  value       = aws_s3_bucket.raw.bucket
}

output "curated_bucket_id" {
  description = "ID of the curated S3 bucket"
  value       = aws_s3_bucket.curated.id
}

output "curated_bucket_arn" {
  description = "ARN of the curated S3 bucket"
  value       = aws_s3_bucket.curated.arn
}

output "curated_bucket_name" {
  description = "Name of the curated S3 bucket"
  value       = aws_s3_bucket.curated.bucket
}

output "prod_bucket_id" {
  description = "ID of the prod S3 bucket"
  value       = aws_s3_bucket.prod.id
}

output "prod_bucket_arn" {
  description = "ARN of the prod S3 bucket"
  value       = aws_s3_bucket.prod.arn
}

output "prod_bucket_name" {
  description = "Name of the prod S3 bucket"
  value       = aws_s3_bucket.prod.bucket
}

output "all_bucket_arns" {
  description = "List of all bucket ARNs (raw, curated, prod)"
  value = [
    aws_s3_bucket.raw.arn,
    aws_s3_bucket.curated.arn,
    aws_s3_bucket.prod.arn
  ]
}

output "all_bucket_names" {
  description = "Map of bucket types to bucket names"
  value = {
    raw     = aws_s3_bucket.raw.bucket
    curated = aws_s3_bucket.curated.bucket
    prod    = aws_s3_bucket.prod.bucket
  }
}
