variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "compliance-guardian"
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package"
  type        = string
}

variable "athena_database" {
  description = "Athena database name for compliance data"
  type        = string
  default     = "compliance_db"
}

variable "athena_output_location" {
  description = "S3 location for Athena query results"
  type        = string
}

variable "data_bucket_prefix" {
  description = "Prefix for data lake S3 buckets"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "log_level" {
  description = "Logging level"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN for Lambda permissions"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 encryption"
  type        = string
}
