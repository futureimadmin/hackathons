variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ecommerce-ai-platform"
}

variable "vpc_id" {
  description = "VPC ID where DMS replication instance will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for DMS replication instance"
  type        = list(string)
}

variable "replication_instance_class" {
  description = "Instance class for DMS replication instance"
  type        = string
  default     = "dms.c5.xlarge"
}

variable "allocated_storage" {
  description = "Allocated storage in GB for DMS replication instance"
  type        = number
  default     = 200
}

variable "multi_az" {
  description = "Enable Multi-AZ for high availability"
  type        = bool
  default     = true
}

variable "source_endpoint_config" {
  description = "Configuration for source MySQL endpoint"
  type = object({
    server_name = string
    port        = number
    username    = string
    database_name = string
    ssl_mode    = string
  })
  default = {
    server_name   = "172.20.10.4"
    port          = 3306
    username      = "root"
    database_name = "ecommerce"
    ssl_mode      = "require"
  }
}

variable "source_password_secret_arn" {
  description = "ARN of the secret containing source database password"
  type        = string
  default     = null
}

variable "target_s3_buckets" {
  description = "Map of system names to their raw S3 bucket names"
  type        = map(string)
}

variable "kms_key_arn" {
  description = "ARN of KMS key for encryption"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs for DMS replication instance"
  type        = list(string)
}

variable "replication_tasks" {
  description = "List of replication tasks to create"
  type = list(object({
    task_id           = string
    source_database   = string
    target_bucket     = string
    table_mappings    = string
    migration_type    = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
