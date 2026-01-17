# Market Intelligence Hub Lambda Module
# Deploys Lambda function for forecasting and market analytics

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Lambda function
resource "aws_lambda_function" "market_intelligence" {
  function_name = "${var.project_name}-market-intelligence-hub"
  description   = "Market Intelligence Hub - Forecasting and Analytics"
  
  # Deployment package
  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key
  
  # Runtime configuration
  runtime       = "python3.11"
  handler       = "handler.lambda_handler"
  timeout       = 300  # 5 minutes for model training
  memory_size   = 3008 # 3 GB for ML models
  
  # IAM role
  role = aws_iam_role.market_intelligence_lambda.arn
  
  # Environment variables
  environment {
    variables = {
      ATHENA_DATABASE    = var.athena_database
      ATHENA_STAGING_DIR = var.athena_staging_dir
      AWS_REGION_NAME    = var.aws_region
      LOG_LEVEL          = var.log_level
    }
  }
  
  # VPC configuration (if needed)
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  
  # Layers for large dependencies (optional)
  layers = var.lambda_layers
  
  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-market-intelligence-hub"
      Component   = "AI-System"
      System      = "MarketIntelligenceHub"
    }
  )
}

# IAM role for Lambda
resource "aws_iam_role" "market_intelligence_lambda" {
  name = "${var.project_name}-market-intelligence-lambda-role"
  
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
  
  tags = var.tags
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.market_intelligence_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach VPC execution policy if VPC is configured
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.market_intelligence_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionPolicy"
}

# Custom policy for Athena, S3, and Glue access
resource "aws_iam_role_policy" "market_intelligence_policy" {
  name = "${var.project_name}-market-intelligence-policy"
  role = aws_iam_role.market_intelligence_lambda.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults",
          "athena:StopQueryExecution",
          "athena:GetWorkGroup"
        ]
        Resource = [
          "arn:aws:athena:${var.aws_region}:${data.aws_caller_identity.current.account_id}:workgroup/${var.athena_workgroup}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*-prod-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::${var.project_name}-*-prod-${data.aws_caller_identity.current.account_id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "${var.athena_staging_dir}*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:GetPartition"
        ]
        Resource = [
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:database/${var.athena_database}",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.athena_database}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "market_intelligence" {
  name              = "/aws/lambda/${aws_lambda_function.market_intelligence.function_name}"
  retention_in_days = var.log_retention_days
  
  tags = var.tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.market_intelligence.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
