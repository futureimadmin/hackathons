# Variables for AWS Batch Module

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for Batch compute environment"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for Batch compute environment"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for Batch compute environment"
  type        = list(string)
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "compute_type" {
  description = "Compute type for Batch (EC2 or FARGATE)"
  type        = string
  default     = "EC2"
  
  validation {
    condition     = contains(["EC2", "FARGATE"], var.compute_type)
    error_message = "Compute type must be either EC2 or FARGATE"
  }
}

variable "instance_types" {
  description = "List of instance types for EC2 compute environment"
  type        = list(string)
  default     = ["c5.xlarge", "c5.2xlarge", "c5.4xlarge"]
}

variable "min_vcpus" {
  description = "Minimum vCPUs for compute environment"
  type        = number
  default     = 0
}

variable "max_vcpus" {
  description = "Maximum vCPUs for compute environment"
  type        = number
  default     = 256
}

variable "desired_vcpus" {
  description = "Desired vCPUs for compute environment"
  type        = number
  default     = 0
}

variable "ecr_image_uri" {
  description = "ECR image URI for data processing container"
  type        = string
  default     = ""
}

variable "raw_to_curated_vcpus" {
  description = "vCPUs for raw-to-curated job"
  type        = number
  default     = 4
}

variable "raw_to_curated_memory" {
  description = "Memory (MB) for raw-to-curated job"
  type        = number
  default     = 8192
}

variable "raw_to_curated_timeout" {
  description = "Timeout (seconds) for raw-to-curated job"
  type        = number
  default     = 3600
}

variable "curated_to_prod_vcpus" {
  description = "vCPUs for curated-to-prod job"
  type        = number
  default     = 2
}

variable "curated_to_prod_memory" {
  description = "Memory (MB) for curated-to-prod job"
  type        = number
  default     = 4096
}

variable "curated_to_prod_timeout" {
  description = "Timeout (seconds) for curated-to-prod job"
  type        = number
  default     = 1800
}

variable "retry_attempts" {
  description = "Number of retry attempts for failed jobs"
  type        = number
  default     = 3
}

variable "log_level" {
  description = "Log level for data processing jobs"
  type        = string
  default     = "INFO"
  
  validation {
    condition     = contains(["DEBUG", "INFO", "WARNING", "ERROR"], var.log_level)
    error_message = "Log level must be one of: DEBUG, INFO, WARNING, ERROR"
  }
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
