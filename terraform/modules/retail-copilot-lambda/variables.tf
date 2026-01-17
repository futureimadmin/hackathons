variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "retail-copilot"
}

variable "lambda_zip_path" {
  description = "Path to Lambda deployment package"
  type        = string
}

variable "athena_database" {
  description = "Athena database name"
  type        = string
  default     = "retail_copilot_db"
}

variable "athena_output_location" {
  description = "S3 location for Athena query results"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "llm_provider" {
  description = "LLM provider (bedrock, openai)"
  type        = string
  default     = "bedrock"
}

variable "llm_model_id" {
  description = "LLM model identifier"
  type        = string
  default     = "anthropic.claude-v2"
}

variable "llm_temperature" {
  description = "LLM sampling temperature"
  type        = string
  default     = "0.7"
}

variable "llm_max_tokens" {
  description = "Maximum tokens in LLM response"
  type        = string
  default     = "2000"
}

variable "conversation_table" {
  description = "DynamoDB table name for conversations"
  type        = string
  default     = "retail-copilot-conversations"
}

variable "data_bucket_prefix" {
  description = "Prefix for data lake S3 buckets"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "API Gateway execution ARN"
  type        = string
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
