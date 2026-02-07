# Variables for Data Pipeline Lambdas Module

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 encryption"
  type        = string
}
