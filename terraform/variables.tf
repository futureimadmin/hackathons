# Variables for eCommerce AI Analytics Platform

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "futureim-ecommerce-ai-platform"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
  default     = "futureimadmin/hackathons"
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
  default     = ""
}

# DMS Configuration
variable "dms_replication_instance_class" {
  description = "Instance class for DMS replication instance"
  type        = string
  default     = "dms.c5.large"
}

variable "dms_allocated_storage" {
  description = "Allocated storage in GB for DMS replication instance"
  type        = number
  default     = 100
}

variable "dms_multi_az" {
  description = "Enable Multi-AZ for DMS high availability"
  type        = bool
  default     = false
}

# MySQL Source Configuration
variable "mysql_server_name" {
  description = "MySQL server hostname or IP"
  type        = string
  default     = "172.20.10.4"
}

variable "mysql_port" {
  description = "MySQL server port"
  type        = number
  default     = 3306
}

variable "mysql_username" {
  description = "MySQL username for DMS"
  type        = string
  default     = "dms_remote"
}

variable "mysql_database_name" {
  description = "MySQL database name"
  type        = string
  default     = "ecommerce"
}

variable "mysql_ssl_mode" {
  description = "MySQL SSL mode (none, require, verify-ca, verify-full)"
  type        = string
  default     = "none"
}

variable "mysql_password_secret_arn" {
  description = "ARN of the secret containing MySQL password"
  type        = string
  default     = ""
}

variable "dms_replication_tasks" {
  description = "List of DMS replication tasks to create"
  type = list(object({
    task_id           = string
    source_database   = string
    target_bucket     = string
    table_mappings    = string
    migration_type    = string
  }))
  default = []
}
