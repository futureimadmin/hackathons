# Variables for EventBridge Module

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "systems" {
  description = "Map of system names to their configurations"
  type = map(object({
    description = string
  }))
}

variable "batch_job_queue_arn" {
  description = "ARN of the Batch job queue"
  type        = string
}

variable "raw_to_curated_job_definition_arn" {
  description = "ARN of the raw-to-curated job definition"
  type        = string
}

variable "curated_to_prod_job_definition_arn" {
  description = "ARN of the curated-to-prod job definition"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
