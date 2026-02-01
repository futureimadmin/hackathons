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

variable "create_cicd_pipeline" {
  description = "Whether to create the CI/CD pipeline (set to false when running from pipeline)"
  type        = bool
  default     = true
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
  default     = "106.192.45.56"  # Public IP for direct connection (no VPN) - CORRECTED
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

# VPN Configuration Variables
variable "enable_vpn" {
  description = "Enable VPN Gateway for on-premises connectivity to MySQL"
  type        = bool
  default     = false
}

variable "customer_gateway_ip" {
  description = "Public IP address of your on-premises VPN device/router"
  type        = string
  default     = ""
}

variable "customer_gateway_bgp_asn" {
  description = "BGP ASN for customer gateway (use 65000 for non-BGP)"
  type        = number
  default     = 65000
}

variable "onprem_cidr_block" {
  description = "CIDR block of your on-premises network where MySQL resides (e.g., 172.20.0.0/16)"
  type        = string
  default     = "172.20.0.0/16"
}

variable "use_route_propagation" {
  description = "Use VPN route propagation (true) or static routes (false)"
  type        = bool
  default     = true
}
