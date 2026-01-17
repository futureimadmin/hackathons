# Variables for Global Market Pulse Lambda Module

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "global-market-pulse"
}

variable "deployment_package_path" {
  description = "Path to the Lambda deployment package (zip file)"
  type        = string
}

variable "memory_size" {
  description = "Amount of memory in MB for Lambda function"
  type        = number
  default     = 1024
}

variable "timeout" {
  description = "Timeout in seconds for Lambda function"
  type        = number
  default     = 300
}

variable "athena_database" {
  description = "Athena database name"
  type        = string
  default     = "global_market_db"
}

variable "athena_output_location" {
  description = "S3 location for Athena query results"
  type        = string
}

variable "s3_data_bucket" {
  description = "S3 bucket containing data for analysis"
  type        = string
}

variable "s3_results_bucket" {
  description = "S3 bucket for Athena query results"
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

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
  default     = ""
}

variable "error_threshold" {
  description = "Threshold for error alarm"
  type        = number
  default     = 5
}

variable "duration_threshold_ms" {
  description = "Threshold for duration alarm in milliseconds"
  type        = number
  default     = 250000
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
