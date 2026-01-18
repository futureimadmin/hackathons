# Complete Terraform configuration with all modules
# This file shows what needs to be added to main.tf

# NOTE: This is a reference file showing all modules that should be added
# You'll need to merge this with your existing main.tf

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

# Analytics Lambda
module "analytics_lambda" {
  source = "./modules/analytics-lambda"
  
  function_name = "${var.project_name}-analytics-${var.environment}"
  environment_name = var.environment
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.lambda_security_group_id]
  kms_key_arn = module.kms.kms_key_arn
  
  # S3 buckets for data access
  data_lake_buckets = {
    raw     = module.demand_insights_engine_data_lake.raw_bucket_name
    curated = module.demand_insights_engine_data_lake.curated_bucket_name
    prod    = module.demand_insights_engine_data_lake.prod_bucket_name
  }
  
  tags = {
    Environment = var.environment
    System      = "Analytics"
  }
}

# Market Intelligence Hub Lambda
module "market_intelligence_lambda" {
  source = "./modules/market-intelligence-lambda"
  
  function_name = "${var.project_name}-market-intelligence-${var.environment}"
  environment_name = var.environment
  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.lambda_security_group_id]
  kms_key_arn = module.kms.kms_key_arn
  
  data_lake_buckets = {
    raw     = module.market_intelligence_hub_data_lake.raw_bucket_name
    curated = module.market_intelligence_hub_data_lake.curated_bucket_name
    prod    = module.market_intelligence_hub_data_lake.prod_bucket_name
  }
  
  tags = {
    Environment = var.environment
    System      = "Market Intelligence Hub"
  }
}

# Add similar blocks for other Lambda functions...
# (demand-insights, compliance-guardian, retail-copilot, global-market-pulse)

# API Gateway
module "api_gateway" {
  source = "./modules/api-gateway"
  
  api_name   = "${var.project_name}-api"
  stage_name = var.environment
  
  # Lambda function integrations
  auth_lambda_function_name = "auth-function-name"  # TODO: Add auth Lambda module
  auth_lambda_invoke_arn    = "auth-invoke-arn"     # TODO: Add auth Lambda module
  
  analytics_lambda_function_name = module.analytics_lambda.function_name
  analytics_lambda_invoke_arn    = module.analytics_lambda.invoke_arn
  
  market_intelligence_lambda_function_name = module.market_intelligence_lambda.function_name
  market_intelligence_lambda_invoke_arn    = module.market_intelligence_lambda.invoke_arn
  
  kms_key_arn = module.kms.kms_key_arn
  
  cors_allowed_origin = "*"  # Update with your frontend URL
  enable_waf          = true
  enable_xray_tracing = true
  
  tags = {
    Environment = var.environment
  }
  
  depends_on = [
    module.analytics_lambda,
    module.market_intelligence_lambda
  ]
}

# Output API Gateway URL
output "api_gateway_url" {
  description = "API Gateway URL"
  value       = module.api_gateway.api_url
}
