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

# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"
  
  api_name   = "${var.project_name}-api"
  stage_name = var.environment
  
  # JWT Secret configuration
  jwt_secret_name = "${var.project_name}/jwt-secret"
  
  # Auth Lambda (required)
  auth_lambda_function_name = "${var.project_name}-auth-${var.environment}"
  auth_lambda_invoke_arn    = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-auth-${var.environment}/invocations"
  
  # Analytics Lambda (placeholder - not deployed yet)
  analytics_lambda_function_name = ""
  analytics_lambda_invoke_arn    = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:450133579764:function:futureim-ecommerce-ai-platform-analytics-dev/invocations"
  
  # AI Lambda Functions - using actual module outputs
  market_intelligence_lambda_function_name = module.market_intelligence_lambda.function_name
  market_intelligence_lambda_invoke_arn    = module.market_intelligence_lambda.invoke_arn
  
  demand_insights_lambda_function_name = module.demand_insights_lambda.function_name
  demand_insights_lambda_invoke_arn    = module.demand_insights_lambda.invoke_arn
  
  compliance_guardian_lambda_function_name = module.compliance_guardian_lambda.function_name
  compliance_guardian_lambda_invoke_arn    = module.compliance_guardian_lambda.invoke_arn
  
  retail_copilot_lambda_function_name = module.retail_copilot_lambda.function_name
  retail_copilot_lambda_invoke_arn    = module.retail_copilot_lambda.invoke_arn
  
  global_market_pulse_lambda_function_name = module.global_market_pulse_lambda.function_name
  global_market_pulse_lambda_invoke_arn    = module.global_market_pulse_lambda.invoke_arn
  
  kms_key_arn         = module.kms.kms_key_arn
  cors_allowed_origin = "*"  # Allow all origins for dev environment (localhost + S3)
  enable_waf          = false  # Disable WAF for dev environment
  enable_xray_tracing = true
  
  tags = {
    Environment = var.environment
  }
}

# Shared S3 Data Lake - ONE raw bucket + ONE curated bucket for all systems
module "shared_data_lake" {
  source = "./modules/s3-shared-data-lake"
  
  environment = var.environment
  kms_key_id  = module.kms.kms_key_id
  
  tags = {
    Purpose = "Shared data lake for all AI systems"
  }
}

# System-Specific Prod Buckets - One for each AI system

# Market Intelligence Hub Prod Bucket
module "market_intelligence_hub_data_lake" {
  source = "./modules/s3-data-lake"
  
  system_name = "market-intelligence-hub"
  environment = var.environment
  kms_key_id  = module.kms.kms_key_id
  
  tags = {
    System = "Market Intelligence Hub"
  }
}

# Demand Insights Engine Prod Bucket
module "demand_insights_engine_data_lake" {
  source = "./modules/s3-data-lake"
  
  system_name = "demand-insights-engine"
  environment = var.environment
  kms_key_id  = module.kms.kms_key_id
  
  tags = {
    System = "Demand Insights Engine"
  }
}

# Compliance Guardian Prod Bucket
module "compliance_guardian_data_lake" {
  source = "./modules/s3-data-lake"
  
  system_name = "compliance-guardian"
  environment = var.environment
  kms_key_id  = module.kms.kms_key_id
  
  tags = {
    System = "Compliance Guardian"
  }
}

# Retail Copilot Prod Bucket
module "retail_copilot_data_lake" {
  source = "./modules/s3-data-lake"
  
  system_name = "retail-copilot"
  environment = var.environment
  kms_key_id  = module.kms.kms_key_id
  
  tags = {
    System = "Retail Copilot"
  }
}

# Global Market Pulse Prod Bucket
module "global_market_pulse_data_lake" {
  source = "./modules/s3-data-lake"
  
  system_name = "global-market-pulse"
  environment = var.environment
  kms_key_id  = module.kms.kms_key_id
  
  tags = {
    System = "Global Market Pulse"
  }
}

# DMS Replication - COMMENTED OUT (not using DMS currently, may need later with OpenVPN)
# module "dms" {
#   source = "./modules/dms"
# 
#   project_name                = var.project_name
#   environment                 = var.environment
#   vpc_id                      = module.vpc.vpc_id
#   subnet_ids                  = module.vpc.public_subnet_ids  # Changed to public subnets for direct connection
#   security_group_ids          = [module.vpc.dms_security_group_id]
#   kms_key_arn                 = module.kms.kms_key_arn
#   replication_instance_class  = var.dms_replication_instance_class
#   allocated_storage           = var.dms_allocated_storage
#   multi_az                    = var.dms_multi_az
# 
#   source_endpoint_config = {
#     server_name   = var.mysql_server_name
#     port          = var.mysql_port
#     username      = var.mysql_username
#     database_name = var.mysql_database_name
#     ssl_mode      = var.mysql_ssl_mode
#   }
# 
#   source_password_secret_arn = var.mysql_password_secret_arn
# 
#   target_s3_buckets = {
#     ecommerce = module.shared_data_lake.raw_bucket_name
#   }
# 
#   replication_tasks = var.dms_replication_tasks
# 
#   tags = {
#     Environment = var.environment
#     System      = "DMS"
#   }
# 
#   depends_on = [
#     module.vpc,
#     module.kms,
#     module.iam,
#     module.shared_data_lake
#   ]
# }

# Glue Crawlers and Catalog - One per system
module "glue_market_intelligence_hub" {
  source = "./modules/glue"
  
  system_name        = "market-intelligence-hub"
  database_name      = "market_intelligence_hub"
  prod_bucket_name   = module.market_intelligence_hub_data_lake.prod_bucket_name
  crawler_role_arn   = module.iam.glue_crawler_role_arn
  crawler_schedule   = "cron(0 */6 * * ? *)"
  enable_lambda_trigger = true  # Enabled - triggers crawler when Parquet files arrive
  lambda_role_arn    = module.iam.lambda_execution_role_arn
  lambda_zip_path    = "${path.module}/modules/glue/lambda/trigger_crawler.zip"
  
  tags = {
    Environment = var.environment
    System      = "Market Intelligence Hub"
  }
  
  depends_on = [module.market_intelligence_hub_data_lake]
}

module "glue_demand_insights_engine" {
  source = "./modules/glue"
  
  system_name        = "demand-insights-engine"
  database_name      = "demand_insights_engine"
  prod_bucket_name   = module.demand_insights_engine_data_lake.prod_bucket_name
  crawler_role_arn   = module.iam.glue_crawler_role_arn
  crawler_schedule   = "cron(0 */6 * * ? *)"
  enable_lambda_trigger = true
  lambda_role_arn    = module.iam.lambda_execution_role_arn
  lambda_zip_path    = "${path.module}/modules/glue/lambda/trigger_crawler.zip"
  
  tags = {
    Environment = var.environment
    System      = "Demand Insights Engine"
  }
  
  depends_on = [module.demand_insights_engine_data_lake]
}

module "glue_compliance_guardian" {
  source = "./modules/glue"
  
  system_name        = "compliance-guardian"
  database_name      = "compliance_guardian"
  prod_bucket_name   = module.compliance_guardian_data_lake.prod_bucket_name
  crawler_role_arn   = module.iam.glue_crawler_role_arn
  crawler_schedule   = "cron(0 */6 * * ? *)"
  enable_lambda_trigger = true
  lambda_role_arn    = module.iam.lambda_execution_role_arn
  lambda_zip_path    = "${path.module}/modules/glue/lambda/trigger_crawler.zip"
  
  tags = {
    Environment = var.environment
    System      = "Compliance Guardian"
  }
  
  depends_on = [module.compliance_guardian_data_lake]
}

module "glue_retail_copilot" {
  source = "./modules/glue"
  
  system_name        = "retail-copilot"
  database_name      = "retail_copilot"
  prod_bucket_name   = module.retail_copilot_data_lake.prod_bucket_name
  crawler_role_arn   = module.iam.glue_crawler_role_arn
  crawler_schedule   = "cron(0 */6 * * ? *)"
  enable_lambda_trigger = true
  lambda_role_arn    = module.iam.lambda_execution_role_arn
  lambda_zip_path    = "${path.module}/modules/glue/lambda/trigger_crawler.zip"
  
  tags = {
    Environment = var.environment
    System      = "Retail Copilot"
  }
  
  depends_on = [module.retail_copilot_data_lake]
}

module "glue_global_market_pulse" {
  source = "./modules/glue"
  
  system_name        = "global-market-pulse"
  database_name      = "global_market_pulse"
  prod_bucket_name   = module.global_market_pulse_data_lake.prod_bucket_name
  crawler_role_arn   = module.iam.glue_crawler_role_arn
  crawler_schedule   = "cron(0 */6 * * ? *)"
  enable_lambda_trigger = true
  lambda_role_arn    = module.iam.lambda_execution_role_arn
  lambda_zip_path    = "${path.module}/modules/glue/lambda/trigger_crawler.zip"
  
  tags = {
    Environment = var.environment
    System      = "Global Market Pulse"
  }
  
  depends_on = [module.global_market_pulse_data_lake]
}

# Data Pipeline Lambda Functions (replaces AWS Batch + EventBridge)
module "data_pipeline_lambdas" {
  source = "./modules/data-pipeline-lambdas"
  
  project_name   = var.project_name
  aws_account_id = data.aws_caller_identity.current.account_id
  kms_key_arn    = module.kms.kms_key_arn
  
  tags = {
    Environment = var.environment
    System      = "Data Pipeline"
  }
  
  depends_on = [
    module.shared_data_lake,
    module.market_intelligence_hub_data_lake,
    module.demand_insights_engine_data_lake,
    module.compliance_guardian_data_lake,
    module.retail_copilot_data_lake,
    module.global_market_pulse_data_lake
  ]
}

# IAM Role for AI Lambda Functions
resource "aws_iam_role" "ai_lambda_role" {
  name = "${var.project_name}-ai-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    System      = "AI Lambda Functions"
  }
}

# IAM Policy for AI Lambda Functions
resource "aws_iam_role_policy" "ai_lambda_policy" {
  name = "${var.project_name}-ai-lambda-policy"
  role = aws_iam_role.ai_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*-prod-${data.aws_caller_identity.current.account_id}/*",
          "arn:aws:s3:::*-prod-${data.aws_caller_identity.current.account_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-${var.environment}-athena-results-${data.aws_caller_identity.current.account_id}/*",
          "arn:aws:s3:::${var.project_name}-${var.environment}-athena-results-${data.aws_caller_identity.current.account_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = module.kms.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Market Intelligence Hub Lambda
module "market_intelligence_lambda" {
  source = "./modules/ai-lambda-container"
  
  function_name              = "${var.project_name}-market-intelligence-${var.environment}"
  lambda_role_arn            = aws_iam_role.ai_lambda_role.arn
  image_uri                  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-market-intelligence-${var.environment}:latest"
  timeout                    = 300
  memory_size                = 2048
  athena_database            = "market_intelligence_hub"
  athena_output_location     = "s3://${var.project_name}-${var.environment}-athena-results-${data.aws_caller_identity.current.account_id}/"
  enable_api_gateway_permission = false  # Will be created separately to avoid circular dependency
  
  additional_env_vars = {
    MPLCONFIGDIR = "/tmp/matplotlib"
    PLOTLY_RENDERER = "json"
    ATHENA_WORKGROUP = "${var.project_name}-${var.environment}"
  }
  
  tags = {
    Environment = var.environment
    System      = "Market Intelligence Hub"
  }
  
  depends_on = [module.athena]
}

# Demand Insights Engine Lambda
module "demand_insights_lambda" {
  source = "./modules/ai-lambda-container"
  
  function_name              = "${var.project_name}-demand-insights-${var.environment}"
  lambda_role_arn            = aws_iam_role.ai_lambda_role.arn
  image_uri                  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-demand-insights-${var.environment}:latest"
  timeout                    = 300
  memory_size                = 2048
  athena_database            = "demand_insights_engine"
  athena_output_location     = "s3://${var.project_name}-${var.environment}-athena-results-${data.aws_caller_identity.current.account_id}/"
  enable_api_gateway_permission = false  # Will be created separately to avoid circular dependency
  
  additional_env_vars = {
    MPLCONFIGDIR = "/tmp/matplotlib"
    PLOTLY_RENDERER = "json"
    ATHENA_WORKGROUP = "${var.project_name}-${var.environment}"
  }
  
  tags = {
    Environment = var.environment
    System      = "Demand Insights Engine"
  }
  
  depends_on = [module.athena]
}

# Compliance Guardian Lambda
module "compliance_guardian_lambda" {
  source = "./modules/ai-lambda-container"
  
  function_name              = "${var.project_name}-compliance-guardian-${var.environment}"
  lambda_role_arn            = aws_iam_role.ai_lambda_role.arn
  image_uri                  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-compliance-guardian-${var.environment}:latest"
  timeout                    = 300
  memory_size                = 2048
  athena_database            = "compliance_guardian"
  athena_output_location     = "s3://${var.project_name}-${var.environment}-athena-results-${data.aws_caller_identity.current.account_id}/"
  enable_api_gateway_permission = false  # Will be created separately to avoid circular dependency
  
  additional_env_vars = {
    MPLCONFIGDIR = "/tmp/matplotlib"
    PLOTLY_RENDERER = "json"
    ATHENA_WORKGROUP = "${var.project_name}-${var.environment}"
  }
  
  tags = {
    Environment = var.environment
    System      = "Compliance Guardian"
  }
  
  depends_on = [module.athena]
}

# Retail Copilot Lambda
module "retail_copilot_lambda" {
  source = "./modules/ai-lambda-container"
  
  function_name              = "${var.project_name}-retail-copilot-${var.environment}"
  lambda_role_arn            = aws_iam_role.ai_lambda_role.arn
  image_uri                  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-retail-copilot-${var.environment}:latest"
  timeout                    = 300
  memory_size                = 2048
  athena_database            = "retail_copilot"
  athena_output_location     = "s3://${var.project_name}-${var.environment}-athena-results-${data.aws_caller_identity.current.account_id}/"
  enable_api_gateway_permission = false  # Will be created separately to avoid circular dependency
  
  additional_env_vars = {
    MPLCONFIGDIR = "/tmp/matplotlib"
    PLOTLY_RENDERER = "json"
    ATHENA_WORKGROUP = "${var.project_name}-${var.environment}"
  }
  
  tags = {
    Environment = var.environment
    System      = "Retail Copilot"
  }
  
  depends_on = [module.athena]
}

# Global Market Pulse Lambda
module "global_market_pulse_lambda" {
  source = "./modules/ai-lambda-container"
  
  function_name              = "${var.project_name}-global-market-pulse-${var.environment}"
  lambda_role_arn            = aws_iam_role.ai_lambda_role.arn
  image_uri                  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-global-market-pulse-${var.environment}:latest"
  timeout                    = 300
  memory_size                = 2048
  athena_database            = "global_market_pulse"
  athena_output_location     = "s3://${var.project_name}-${var.environment}-athena-results-${data.aws_caller_identity.current.account_id}/"
  enable_api_gateway_permission = false  # Will be created separately to avoid circular dependency
  
  additional_env_vars = {
    MPLCONFIGDIR = "/tmp/matplotlib"
    PLOTLY_RENDERER = "json"
    ATHENA_WORKGROUP = "${var.project_name}-${var.environment}"
  }
  
  tags = {
    Environment = var.environment
    System      = "Global Market Pulse"
  }
  
  depends_on = [module.athena]
}

# Athena Workgroups
module "athena" {
  source = "./modules/athena"
  
  workgroup_name              = "${var.project_name}-${var.environment}"
  query_results_bucket_name   = "${var.project_name}-${var.environment}-athena-results-${var.aws_account_id}"
  query_results_retention_days = 30
  sample_database_name        = "market_intelligence_hub"
  
  tags = {
    Environment = var.environment
    System      = "Athena"
  }
  
  depends_on = [module.kms]
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
# output "dms_replication_role_arn" {
#   description = "ARN of the DMS replication role"
#   value       = module.iam.dms_replication_role_arn
# }

output "glue_crawler_role_arn" {
  description = "ARN of the Glue crawler role"
  value       = module.iam.glue_crawler_role_arn
}

output "lambda_execution_role_arn" {
  description = "Lambda execution role ARN"
  value       = module.iam.lambda_execution_role_arn
}

# Data Pipeline Lambda Outputs
output "raw_to_curated_lambda_arn" {
  description = "ARN of the raw-to-curated Lambda function"
  value       = module.data_pipeline_lambdas.raw_to_curated_function_arn
}

output "curated_to_prod_lambda_arn" {
  description = "ARN of the curated-to-prod Lambda function"
  value       = module.data_pipeline_lambdas.curated_to_prod_function_arn
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
output "shared_raw_bucket_name" {
  description = "Shared raw S3 bucket name"
  value       = module.shared_data_lake.raw_bucket_name
}

output "shared_curated_bucket_name" {
  description = "Shared curated S3 bucket name"
  value       = module.shared_data_lake.curated_bucket_name
}

output "market_intelligence_hub_prod_bucket" {
  description = "S3 prod bucket name for Market Intelligence Hub"
  value       = module.market_intelligence_hub_data_lake.prod_bucket_name
}

output "demand_insights_engine_prod_bucket" {
  description = "S3 prod bucket name for Demand Insights Engine"
  value       = module.demand_insights_engine_data_lake.prod_bucket_name
}

output "compliance_guardian_prod_bucket" {
  description = "S3 prod bucket name for Compliance Guardian"
  value       = module.compliance_guardian_data_lake.prod_bucket_name
}

output "retail_copilot_prod_bucket" {
  description = "S3 prod bucket name for Retail Copilot"
  value       = module.retail_copilot_data_lake.prod_bucket_name
}

output "global_market_pulse_prod_bucket" {
  description = "S3 prod bucket name for Global Market Pulse"
  value       = module.global_market_pulse_data_lake.prod_bucket_name
}

output "all_systems_buckets" {
  description = "All S3 bucket names organized by system"
  value = {
    shared = {
      raw     = module.shared_data_lake.raw_bucket_name
      curated = module.shared_data_lake.curated_bucket_name
    }
    market_intelligence_hub = {
      prod = module.market_intelligence_hub_data_lake.prod_bucket_name
    }
    demand_insights_engine = {
      prod = module.demand_insights_engine_data_lake.prod_bucket_name
    }
    compliance_guardian = {
      prod = module.compliance_guardian_data_lake.prod_bucket_name
    }
    retail_copilot = {
      prod = module.retail_copilot_data_lake.prod_bucket_name
    }
    global_market_pulse = {
      prod = module.global_market_pulse_data_lake.prod_bucket_name
    }
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

# DMS Outputs - COMMENTED OUT (not using DMS currently, may need later with OpenVPN)
# output "dms_replication_instance_arn" {
#   description = "DMS replication instance ARN"
#   value       = module.dms.replication_instance_arn
# }
# 
# output "dms_replication_instance_id" {
#   description = "DMS replication instance ID"
#   value       = module.dms.replication_instance_id
# }
# 
# output "dms_source_endpoint_arn" {
#   description = "DMS source endpoint ARN"
#   value       = module.dms.source_endpoint_arn
# }
# 
# output "dms_target_endpoint_arns" {
#   description = "Map of system names to DMS target endpoint ARNs"
#   value       = module.dms.target_endpoint_arns
# }
# 
# output "dms_replication_task_arns" {
#   description = "Map of task IDs to DMS replication task ARNs"
#   value       = module.dms.replication_task_arns
# }
