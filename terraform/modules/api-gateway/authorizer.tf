# Lambda Authorizer for JWT Token Verification

# Lambda function for JWT authorization
resource "aws_lambda_function" "authorizer" {
  filename      = "${path.module}/lambda/authorizer.zip"
  function_name = "${var.api_name}-authorizer"
  role          = aws_iam_role.authorizer.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 10
  memory_size   = 256

  environment {
    variables = {
      JWT_SECRET_NAME = var.jwt_secret_name
    }
  }

  tags = var.tags
}

# CloudWatch log group for authorizer
resource "aws_cloudwatch_log_group" "authorizer" {
  name              = "/aws/lambda/${aws_lambda_function.authorizer.function_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# API Gateway authorizer
resource "aws_api_gateway_authorizer" "jwt" {
  name                   = "${var.api_name}-jwt-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.main.id
  authorizer_uri         = aws_lambda_function.authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.authorizer_invocation.arn
  type                   = "TOKEN"
  identity_source        = "method.request.header.Authorization"
  
  # Cache authorizer results for 5 minutes
  authorizer_result_ttl_in_seconds = 300
}

# IAM role for authorizer Lambda
resource "aws_iam_role" "authorizer" {
  name = "${var.api_name}-authorizer-role"

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

# IAM policy for authorizer Lambda
resource "aws_iam_role_policy" "authorizer" {
  name = "${var.api_name}-authorizer-policy"
  role = aws_iam_role.authorizer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.jwt_secret_name}-*"
      }
    ]
  })
}

# IAM role for API Gateway to invoke authorizer
resource "aws_iam_role" "authorizer_invocation" {
  name = "${var.api_name}-authorizer-invocation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for API Gateway to invoke authorizer
resource "aws_iam_role_policy" "authorizer_invocation" {
  name = "${var.api_name}-authorizer-invocation-policy"
  role = aws_iam_role.authorizer_invocation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.authorizer.arn
      }
    ]
  })
}
