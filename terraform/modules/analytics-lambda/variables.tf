variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to Lambda deployment package"
  type        = string
}

variable "athena_database" {
  description = "Athena database name"
  type        = string
}

variable "athena_output_location" {
  description = "S3 location for Athena query results"
  type        = string
}

variable "athena_workgroup" {
  description = "Athena workgroup name"
  type        = string
  default     = "primary"
}

variable "jwt_secret_name" {
  description = "Secrets Manager secret name for JWT"
  type        = string
}

variable "jwt_secret_arn" {
  description = "ARN of JWT secret in Secrets Manager"
  type        = string
}

variable "data_lake_bucket_arn" {
  description = "ARN of data lake S3 bucket"
  type        = string
}

variable "athena_results_bucket_arn" {
  description = "ARN of Athena results S3 bucket"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "Execution ARN of API Gateway"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
