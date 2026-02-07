# Outputs for S3 Data Lake Module - Prod Bucket Only

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
