# Main Terraform configuration for eCommerce AI Analytics Platform

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket         = "futureim-ecommerce-ai-platform-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "futureim-ecommerce-ai-platform-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "eCommerce-AI-Platform"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# Data source for available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# KMS Module
module "kms" {
  source = "./modules/kms"
  
  environment = var.environment
  project_name = var.project_name
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"
  
  environment         = var.environment
  project_name        = var.project_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = data.aws_availability_zones.available.names
  kms_key_id          = module.kms.kms_key_arn
}

# IAM Module
module "iam" {
  source = "./modules/iam"
  
  project_name  = var.project_name
  environment   = var.environment
  kms_key_arn   = module.kms.kms_key_arn
}

# DynamoDB Users Table
module "dynamodb_users" {
  source = "./modules/dynamodb-users"
  
  table_name                    = "${var.project_name}-users-${var.environment}"
  billing_mode                  = "PAY_PER_REQUEST"
  enable_point_in_time_recovery = true
  kms_key_arn                   = module.kms.kms_key_arn
  enable_streams                = true
  
  tags = {
    Environment = var.environment
    System      = "Authentication"
  }
}

# S3 Data Lake Modules - One for each system

# Market Intelligence Hub Data Lake
module "market_intelligence_hub_data_lake" {
  source = "./modules/s3-data-lake"
  
  system_name        = "market-intelligence-hub"
  environment        = var.environment
  kms_key_id         = module.kms.kms_key_id
  batch_job_role_arn = module.iam.batch_job_execution_role_arn
  
  tags = {
    System = "Market Intelligence Hub"
  }
}

# Demand Insights Engine Data Lake
module "demand_insights_engine_data_lake" {
  source = "./modules/s3-data-lake"
  
  system_name        = "demand-insights-engine"
  environment        = var.environment
  kms_key_id         = module.kms.kms_key_id
  batch_job_role_arn = module.iam.batch_job_execution_role_arn
  
  tags = {
    System = "Demand Insights Engine"
  }
}

# Compliance Guardian Data Lake
module "compliance_guardian_data_lake" {
  source = "./modules/s3-data-lake"
  
  system_name        = "compliance-guardian"
  environment        = var.environment
  kms_key_id         = module.kms.kms_key_id
  batch_job_role_arn = module.iam.batch_job_execution_role_arn
  
  tags = {
    System = "Compliance Guardian"
  }
}

# Retail Copilot Data Lake
module "retail_copilot_data_lake" {
  source = "./modules/s3-data-lake"
  
  system_name        = "retail-copilot"
  environment        = var.environment
  kms_key_id         = module.kms.kms_key_id
  batch_job_role_arn = module.iam.batch_job_execution_role_arn
  
  tags = {
    System = "Retail Copilot"
  }
}

# Global Market Pulse Data Lake
module "global_market_pulse_data_lake" {
  source = "./modules/s3-data-lake"
  
  system_name        = "global-market-pulse"
  environment        = var.environment
  kms_key_id         = module.kms.kms_key_id
  batch_job_role_arn = module.iam.batch_job_execution_role_arn
  
  tags = {
    System = "Global Market Pulse"
  }
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "kms_key_id" {
  description = "KMS key ID for encryption"
  value       = module.kms.kms_key_id
}

output "kms_key_arn" {
  description = "KMS key ARN for encryption"
  value       = module.kms.kms_key_arn
}

output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

# IAM Role Outputs
output "batch_job_execution_role_arn" {
  description = "ARN of the Batch job execution role"
  value       = module.iam.batch_job_execution_role_arn
}

output "dms_replication_role_arn" {
  description = "ARN of the DMS replication role"
  value       = module.iam.dms_replication_role_arn
}

output "glue_crawler_role_arn" {
  description = "ARN of the Glue crawler role"
  value       = module.iam.glue_crawler_role_arn
}

# DynamoDB Outputs
output "dynamodb_users_table_name" {
  description = "DynamoDB users table name"
  value       = module.dynamodb_users.table_name
}

output "dynamodb_users_table_arn" {
  description = "DynamoDB users table ARN"
  value       = module.dynamodb_users.table_arn
}

# S3 Data Lake Outputs
output "market_intelligence_hub_buckets" {
  description = "S3 bucket names for Market Intelligence Hub"
  value       = module.market_intelligence_hub_data_lake.all_bucket_names
}

output "demand_insights_engine_buckets" {
  description = "S3 bucket names for Demand Insights Engine"
  value       = module.demand_insights_engine_data_lake.all_bucket_names
}

output "compliance_guardian_buckets" {
  description = "S3 bucket names for Compliance Guardian"
  value       = module.compliance_guardian_data_lake.all_bucket_names
}

output "retail_copilot_buckets" {
  description = "S3 bucket names for Retail Copilot"
  value       = module.retail_copilot_data_lake.all_bucket_names
}

output "global_market_pulse_buckets" {
  description = "S3 bucket names for Global Market Pulse"
  value       = module.global_market_pulse_data_lake.all_bucket_names
}

output "all_systems_buckets" {
  description = "All S3 bucket names organized by system"
  value = {
    market_intelligence_hub = module.market_intelligence_hub_data_lake.all_bucket_names
    demand_insights_engine  = module.demand_insights_engine_data_lake.all_bucket_names
    compliance_guardian     = module.compliance_guardian_data_lake.all_bucket_names
    retail_copilot          = module.retail_copilot_data_lake.all_bucket_names
    global_market_pulse     = module.global_market_pulse_data_lake.all_bucket_names
  }
}
