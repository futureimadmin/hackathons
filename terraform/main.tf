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
  
  # VPN Configuration
  enable_vpn              = var.enable_vpn
  customer_gateway_ip     = var.customer_gateway_ip
  customer_gateway_bgp_asn = var.customer_gateway_bgp_asn
  onprem_cidr_block       = var.onprem_cidr_block
  use_route_propagation   = var.use_route_propagation
  
  # MySQL Configuration for DMS Security Group
  mysql_server_ip         = var.mysql_server_name
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

# S3 Frontend Bucket
module "frontend_bucket" {
  source = "./modules/s3-frontend"
  
  bucket_name = "${var.project_name}-frontend-${var.environment}"
  
  tags = {
    Environment = var.environment
    System      = "Frontend"
  }
}

# API Gateway Module (infrastructure only - Lambda functions will be deployed separately)
module "api_gateway" {
  source = "./modules/api-gateway"
  
  api_name   = "${var.project_name}-api"
  stage_name = var.environment
  
  # Placeholder Lambda ARNs - will be updated after Lambda deployment
  # Lambda functions don't exist yet, so we use placeholder ARNs
  # The auth Lambda permission is commented out in the module
  # Other Lambda permissions have count parameters that check for empty strings
  
  # Auth Lambda (required - permission commented out in module)
  auth_lambda_function_name = "${var.project_name}-auth-${var.environment}"
  auth_lambda_invoke_arn    = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-auth-${var.environment}/invocations"
  
  # Optional Lambda functions - using placeholder ARNs (functions don't exist yet)
  # These will return 500 errors until Lambda functions are deployed
  # Permissions are skipped via count parameters (function names are empty)
  # Using placeholder ARNs to keep integrations valid (not empty)
  analytics_lambda_function_name = ""
  analytics_lambda_invoke_arn    = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:450133579764:function:futureim-ecommerce-ai-platform-analytics-dev/invocations"
  
  market_intelligence_lambda_function_name = ""
  market_intelligence_lambda_invoke_arn    = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:450133579764:function:futureim-ecommerce-ai-platform-market-intelligence-dev/invocations"
  
  demand_insights_lambda_function_name = ""
  demand_insights_lambda_invoke_arn    = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:450133579764:function:futureim-ecommerce-ai-platform-demand-insights-dev/invocations"
  
  compliance_guardian_lambda_function_name = ""
  compliance_guardian_lambda_invoke_arn    = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:450133579764:function:futureim-ecommerce-ai-platform-compliance-guardian-dev/invocations"
  
  retail_copilot_lambda_function_name = ""
  retail_copilot_lambda_invoke_arn    = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:450133579764:function:futureim-ecommerce-ai-platform-retail-copilot-dev/invocations"
  
  global_market_pulse_lambda_function_name = ""
  global_market_pulse_lambda_invoke_arn    = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:450133579764:function:futureim-ecommerce-ai-platform-global-market-pulse-dev/invocations"
  
  kms_key_arn         = module.kms.kms_key_arn
  cors_allowed_origin = "http://${var.project_name}-frontend-${var.environment}.s3-website.${var.aws_region}.amazonaws.com"
  enable_waf          = false  # Disable WAF for dev environment
  enable_xray_tracing = true
  
  tags = {
    Environment = var.environment
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

# DMS Replication
module "dms" {
  source = "./modules/dms"

  project_name                = var.project_name
  environment                 = var.environment
  vpc_id                      = module.vpc.vpc_id
  subnet_ids                  = module.vpc.public_subnet_ids  # Changed to public subnets for direct connection
  security_group_ids          = [module.vpc.dms_security_group_id]
  kms_key_arn                 = module.kms.kms_key_arn
  replication_instance_class  = var.dms_replication_instance_class
  allocated_storage           = var.dms_allocated_storage
  multi_az                    = var.dms_multi_az

  source_endpoint_config = {
    server_name   = var.mysql_server_name
    port          = var.mysql_port
    username      = var.mysql_username
    database_name = var.mysql_database_name
    ssl_mode      = var.mysql_ssl_mode
  }

  source_password_secret_arn = var.mysql_password_secret_arn

  target_s3_buckets = {
    market-intelligence-hub = module.market_intelligence_hub_data_lake.raw_bucket_name
    demand-insights-engine  = module.demand_insights_engine_data_lake.raw_bucket_name
    compliance-guardian     = module.compliance_guardian_data_lake.raw_bucket_name
    retail-copilot          = module.retail_copilot_data_lake.raw_bucket_name
    global-market-pulse     = module.global_market_pulse_data_lake.raw_bucket_name
  }

  replication_tasks = var.dms_replication_tasks

  tags = {
    Environment = var.environment
    System      = "DMS"
  }

  depends_on = [
    module.vpc,
    module.kms,
    module.iam,
    module.market_intelligence_hub_data_lake,
    module.demand_insights_engine_data_lake,
    module.compliance_guardian_data_lake,
    module.retail_copilot_data_lake,
    module.global_market_pulse_data_lake
  ]
}

# CI/CD Pipeline (only created when running locally, not from the pipeline itself)
module "cicd_pipeline" {
  count  = var.create_cicd_pipeline ? 1 : 0
  source = "./modules/cicd-pipeline"
  
  project_name              = var.project_name
  environment               = var.environment
  aws_region                = var.aws_region
  kms_key_arn               = module.kms.kms_key_arn
  lambda_execution_role_arn = module.iam.lambda_execution_role_arn
  frontend_bucket_name      = module.frontend_bucket.bucket_name
  api_gateway_url           = module.api_gateway.api_endpoint
  github_repo               = var.github_repo
  github_branch             = var.github_branch
  github_token              = var.github_token
  
  tags = {
    Environment = var.environment
    System      = "CI/CD"
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

# API Gateway Outputs
output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = module.api_gateway.api_id
}

output "api_gateway_url" {
  description = "API Gateway base URL"
  value       = module.api_gateway.api_endpoint
}

output "api_gateway_stage" {
  description = "API Gateway stage name"
  value       = module.api_gateway.api_stage_name
}

output "api_endpoints" {
  description = "API Gateway endpoints"
  value       = module.api_gateway.api_endpoints
}

# Frontend Outputs
output "frontend_bucket_name" {
  description = "Frontend S3 bucket name"
  value       = module.frontend_bucket.bucket_name
}

output "frontend_website_url" {
  description = "Frontend website URL"
  value       = module.frontend_bucket.website_url
}

# CI/CD Pipeline Outputs (conditional)
output "pipeline_name" {
  description = "CodePipeline name"
  value       = var.create_cicd_pipeline ? module.cicd_pipeline[0].pipeline_name : null
}

output "pipeline_url" {
  description = "CodePipeline console URL"
  value       = var.create_cicd_pipeline ? module.cicd_pipeline[0].pipeline_url : null
}

output "github_connection_arn" {
  description = "GitHub CodeStar connection ARN (requires manual approval)"
  value       = var.create_cicd_pipeline ? module.cicd_pipeline[0].github_connection_arn : null
}

output "lambda_execution_role_arn" {
  description = "Lambda execution role ARN"
  value       = module.iam.lambda_execution_role_arn
}

# DMS Outputs
output "dms_replication_instance_arn" {
  description = "DMS replication instance ARN"
  value       = module.dms.replication_instance_arn
}

output "dms_replication_instance_id" {
  description = "DMS replication instance ID"
  value       = module.dms.replication_instance_id
}

output "dms_source_endpoint_arn" {
  description = "DMS source endpoint ARN"
  value       = module.dms.source_endpoint_arn
}

output "dms_target_endpoint_arns" {
  description = "Map of system names to DMS target endpoint ARNs"
  value       = module.dms.target_endpoint_arns
}

output "dms_replication_task_arns" {
  description = "Map of task IDs to DMS replication task ARNs"
  value       = module.dms.replication_task_arns
}
