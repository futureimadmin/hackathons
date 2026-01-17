# Variables for Glue Module

variable "system_name" {
  description = "Name of the system (e.g., market-intelligence-hub)"
  type        = string
}

variable "database_name" {
  description = "Name of the Glue database (underscores instead of hyphens)"
  type        = string
}

variable "prod_bucket_name" {
  description = "Name of the production S3 bucket to crawl"
  type        = string
}

variable "crawler_role_arn" {
  description = "ARN of the IAM role for Glue Crawler"
  type        = string
}

variable "crawler_schedule" {
  description = "Cron expression for crawler schedule (e.g., 'cron(0 */6 * * ? *)')"
  type        = string
  default     = "cron(0 */6 * * ? *)"
}

variable "enable_lambda_trigger" {
  description = "Enable Lambda function to trigger crawler on S3 events"
  type        = bool
  default     = true
}

variable "lambda_role_arn" {
  description = "ARN of the IAM role for Lambda function"
  type        = string
  default     = ""
}

variable "lambda_zip_path" {
  description = "Path to Lambda function ZIP file"
  type        = string
  default     = ""
}

variable "log_level" {
  description = "Log level for Lambda function"
  type        = string
  default     = "INFO"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "alarm_actions" {
  description = "List of ARNs to notify when alarms trigger"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
