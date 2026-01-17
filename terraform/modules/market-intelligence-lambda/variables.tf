# Variables for Market Intelligence Lambda Module

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_s3_bucket" {
  description = "S3 bucket containing Lambda deployment package"
  type        = string
}

variable "lambda_s3_key" {
  description = "S3 key for Lambda deployment package"
  type        = string
}

variable "athena_database" {
  description = "Athena database name for Market Intelligence Hub"
  type        = string
  default     = "market_intelligence_hub"
}

variable "athena_workgroup" {
  description = "Athena workgroup name"
  type        = string
  default     = "ecommerce-analytics"
}

variable "athena_staging_dir" {
  description = "S3 location for Athena query results"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN for Lambda permissions"
  type        = string
}

variable "vpc_config" {
  description = "VPC configuration for Lambda (optional)"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}

variable "lambda_layers" {
  description = "List of Lambda layer ARNs"
  type        = list(string)
  default     = []
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
