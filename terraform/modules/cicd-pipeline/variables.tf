# Variables for CI/CD Pipeline Module

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in format: owner/repo"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to track"
  type        = string
  default     = "master"
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "lambda_execution_role_arn" {
  description = "ARN of Lambda execution role"
  type        = string
}

variable "api_gateway_url" {
  description = "API Gateway URL"
  type        = string
}

variable "frontend_bucket_name" {
  description = "S3 bucket name for frontend"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
