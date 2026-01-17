# Variables for System Registry Module

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID for encryption"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "data_lake_bucket_name" {
  description = "Name of the data lake S3 bucket"
  type        = string
}

variable "api_gateway_id" {
  description = "ID of the API Gateway REST API"
  type        = string
}

variable "api_gateway_root_resource_id" {
  description = "Root resource ID of the API Gateway"
  type        = string
}

variable "api_gateway_authorizer_id" {
  description = "ID of the API Gateway authorizer"
  type        = string
}

variable "api_gateway_execution_arn" {
  description = "Execution ARN of the API Gateway"
  type        = string
}
