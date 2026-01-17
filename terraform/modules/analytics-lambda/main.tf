/**
 * Analytics Lambda Module
 * 
 * Creates Lambda function for analytics service with Athena integration.
 */

resource "aws_lambda_function" "analytics" {
  filename         = var.lambda_zip_path
  function_name    = "${var.project_name}-analytics-service"
  role            = aws_iam_role.analytics_lambda.arn
  handler         = "handler.lambda_handler"
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  runtime         = "python3.11"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      ATHENA_DATABASE         = var.athena_database
      ATHENA_OUTPUT_LOCATION  = var.athena_output_location
      ATHENA_WORKGROUP        = var.athena_workgroup
      JWT_SECRET_NAME         = var.jwt_secret_name
    }
  }

  tags = var.tags
}

# IAM Role for Lambda
resource "aws_iam_role" "analytics_lambda" {
  name = "${var.project_name}-analytics-lambda-role"

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
  role       = aws_iam_role.analytics_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy for Athena access
resource "aws_iam_role_policy" "athena_access" {
  name = "${var.project_name}-analytics-athena-policy"
  role = aws_iam_role.analytics_lambda.id

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
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions"
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
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.data_lake_bucket_arn}/*",
          var.data_lake_bucket_arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.athena_results_bucket_arn}/*",
          var.athena_results_bucket_arn
        ]
      }
    ]
  })
}

# Policy for Secrets Manager access
resource "aws_iam_role_policy" "secrets_access" {
  name = "${var.project_name}-analytics-secrets-policy"
  role = aws_iam_role.analytics_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = var.jwt_secret_arn
      }
    ]
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "analytics_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.analytics.function_name}"
  retention_in_days = 7

  tags = var.tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.analytics.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_execution_arn}/*/*"
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
