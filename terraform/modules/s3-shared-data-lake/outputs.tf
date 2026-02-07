output "raw_bucket_name" {
  description = "Name of the shared raw S3 bucket"
  value       = aws_s3_bucket.raw.id
}

output "raw_bucket_arn" {
  description = "ARN of the shared raw S3 bucket"
  value       = aws_s3_bucket.raw.arn
}

output "curated_bucket_name" {
  description = "Name of the shared curated S3 bucket"
  value       = aws_s3_bucket.curated.id
}

output "curated_bucket_arn" {
  description = "ARN of the shared curated S3 bucket"
  value       = aws_s3_bucket.curated.arn
}
