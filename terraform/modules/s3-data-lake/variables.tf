# Variables for S3 Data Lake Module

variable "system_name" {
  description = "Name of the system (e.g., market-intelligence-hub, demand-insights-engine)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.system_name))
    error_message = "System name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "kms_key_id" {
  description = "KMS key ID for S3 bucket encryption"
  type        = string
}

variable "batch_job_role_arn" {
  description = "ARN of the IAM role used by AWS Batch jobs for data processing"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
