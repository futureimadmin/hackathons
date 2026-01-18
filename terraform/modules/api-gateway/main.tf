# API Gateway REST API for eCommerce Platform
# Provides REST endpoints for authentication and analytics

# REST API
resource "aws_api_gateway_rest_api" "main" {
  name        = var.api_name
  description = "eCommerce AI Analytics Platform API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# /auth resource
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "auth"
}

# /auth/register resource
resource "aws_api_gateway_resource" "register" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "register"
}

# /auth/login resource
resource "aws_api_gateway_resource" "login" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "login"
}

# /auth/forgot-password resource
resource "aws_api_gateway_resource" "forgot_password" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "forgot-password"
}

# /auth/reset-password resource
resource "aws_api_gateway_resource" "reset_password" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "reset-password"
}

# /auth/verify resource
resource "aws_api_gateway_resource" "verify" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "verify"
}

# /analytics resource
resource "aws_api_gateway_resource" "analytics" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "analytics"
}

# /analytics/{system} resource
resource "aws_api_gateway_resource" "analytics_system" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.analytics.id
  path_part   = "{system}"
}

# /analytics/{system}/query resource
resource "aws_api_gateway_resource" "analytics_query" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.analytics_system.id
  path_part   = "query"
}

# /analytics/{system}/forecast resource
resource "aws_api_gateway_resource" "analytics_forecast" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.analytics_system.id
  path_part   = "forecast"
}

# /analytics/{system}/insights resource
resource "aws_api_gateway_resource" "analytics_insights" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.analytics_system.id
  path_part   = "insights"
}

# /market-intelligence resource
resource "aws_api_gateway_resource" "market_intelligence" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "market-intelligence"
}

# /market-intelligence/forecast resource
resource "aws_api_gateway_resource" "mi_forecast" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.market_intelligence.id
  path_part   = "forecast"
}

# /market-intelligence/trends resource
resource "aws_api_gateway_resource" "mi_trends" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.market_intelligence.id
  path_part   = "trends"
}

# /market-intelligence/competitive-pricing resource
resource "aws_api_gateway_resource" "mi_competitive_pricing" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.market_intelligence.id
  path_part   = "competitive-pricing"
}

# /market-intelligence/compare-models resource
resource "aws_api_gateway_resource" "mi_compare_models" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.market_intelligence.id
  path_part   = "compare-models"
}

# POST /auth/register method
resource "aws_api_gateway_method" "register_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.register.id
  http_method   = "POST"
  authorization = "NONE"
}

# POST /auth/login method
resource "aws_api_gateway_method" "login_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.login.id
  http_method   = "POST"
  authorization = "NONE"
}

# POST /auth/forgot-password method
resource "aws_api_gateway_method" "forgot_password_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.forgot_password.id
  http_method   = "POST"
  authorization = "NONE"
}

# POST /auth/reset-password method
resource "aws_api_gateway_method" "reset_password_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.reset_password.id
  http_method   = "POST"
  authorization = "NONE"
}

# POST /auth/verify method (protected)
resource "aws_api_gateway_method" "verify_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.verify.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /analytics/{system}/query method (protected)
resource "aws_api_gateway_method" "analytics_query_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.analytics_query.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id

  request_parameters = {
    "method.request.path.system" = true
  }
}

# POST /analytics/{system}/forecast method (protected)
resource "aws_api_gateway_method" "analytics_forecast_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.analytics_forecast.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id

  request_parameters = {
    "method.request.path.system" = true
  }
}

# GET /analytics/{system}/insights method (protected)
resource "aws_api_gateway_method" "analytics_insights_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.analytics_insights.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id

  request_parameters = {
    "method.request.path.system" = true
  }
}

# POST /market-intelligence/forecast method (protected)
resource "aws_api_gateway_method" "mi_forecast_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.mi_forecast.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /market-intelligence/trends method (protected)
resource "aws_api_gateway_method" "mi_trends_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.mi_trends.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /market-intelligence/competitive-pricing method (protected)
resource "aws_api_gateway_method" "mi_competitive_pricing_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.mi_competitive_pricing.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /market-intelligence/compare-models method (protected)
resource "aws_api_gateway_method" "mi_compare_models_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.mi_compare_models.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# Lambda integration for /auth/register
resource "aws_api_gateway_integration" "register_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.register.id
  http_method             = aws_api_gateway_method.register_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.auth_lambda_invoke_arn
}

# Lambda integration for /auth/login
resource "aws_api_gateway_integration" "login_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.login.id
  http_method             = aws_api_gateway_method.login_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.auth_lambda_invoke_arn
}

# Lambda integration for /auth/forgot-password
resource "aws_api_gateway_integration" "forgot_password_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.forgot_password.id
  http_method             = aws_api_gateway_method.forgot_password_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.auth_lambda_invoke_arn
}

# Lambda integration for /auth/reset-password
resource "aws_api_gateway_integration" "reset_password_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.reset_password.id
  http_method             = aws_api_gateway_method.reset_password_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.auth_lambda_invoke_arn
}

# Lambda integration for /auth/verify
resource "aws_api_gateway_integration" "verify_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.verify.id
  http_method             = aws_api_gateway_method.verify_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.auth_lambda_invoke_arn
}

# Lambda integration for /analytics/{system}/query
resource "aws_api_gateway_integration" "analytics_query_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.analytics_query.id
  http_method             = aws_api_gateway_method.analytics_query_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.analytics_lambda_invoke_arn
}

# Lambda integration for /analytics/{system}/forecast
resource "aws_api_gateway_integration" "analytics_forecast_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.analytics_forecast.id
  http_method             = aws_api_gateway_method.analytics_forecast_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.analytics_lambda_invoke_arn
}

# Lambda integration for /analytics/{system}/insights
resource "aws_api_gateway_integration" "analytics_insights_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.analytics_insights.id
  http_method             = aws_api_gateway_method.analytics_insights_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.analytics_lambda_invoke_arn
}

# Lambda integration for /market-intelligence/forecast
resource "aws_api_gateway_integration" "mi_forecast_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.mi_forecast.id
  http_method             = aws_api_gateway_method.mi_forecast_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.market_intelligence_lambda_invoke_arn
}

# Lambda integration for /market-intelligence/trends
resource "aws_api_gateway_integration" "mi_trends_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.mi_trends.id
  http_method             = aws_api_gateway_method.mi_trends_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.market_intelligence_lambda_invoke_arn
}

# Lambda integration for /market-intelligence/competitive-pricing
resource "aws_api_gateway_integration" "mi_competitive_pricing_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.mi_competitive_pricing.id
  http_method             = aws_api_gateway_method.mi_competitive_pricing_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.market_intelligence_lambda_invoke_arn
}

# Lambda integration for /market-intelligence/compare-models
resource "aws_api_gateway_integration" "mi_compare_models_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.mi_compare_models.id
  http_method             = aws_api_gateway_method.mi_compare_models_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.market_intelligence_lambda_invoke_arn
}

# Lambda permission for API Gateway to invoke auth function
# NOTE: This will fail until the auth Lambda function is deployed
# Commented out to allow API Gateway deployment without Lambda functions
# resource "aws_lambda_permission" "api_gateway_auth" {
#   statement_id  = "AllowAPIGatewayInvoke"
#   action        = "lambda:InvokeFunction"
#   function_name = var.auth_lambda_function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
# }

# Lambda permission for API Gateway to invoke analytics function
resource "aws_lambda_permission" "api_gateway_analytics" {
  count         = var.analytics_lambda_function_name != "" ? 1 : 0
  statement_id  = "AllowAPIGatewayInvokeAnalytics"
  action        = "lambda:InvokeFunction"
  function_name = var.analytics_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Lambda permission for API Gateway to invoke market intelligence function
resource "aws_lambda_permission" "api_gateway_market_intelligence" {
  count         = var.market_intelligence_lambda_function_name != "" ? 1 : 0
  statement_id  = "AllowAPIGatewayInvokeMarketIntelligence"
  action        = "lambda:InvokeFunction"
  function_name = var.market_intelligence_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# Lambda permission for API Gateway to invoke authorizer
resource "aws_lambda_permission" "api_gateway_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/authorizers/${aws_api_gateway_authorizer.jwt.id}"
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.auth.id,
      aws_api_gateway_resource.register.id,
      aws_api_gateway_resource.login.id,
      aws_api_gateway_resource.forgot_password.id,
      aws_api_gateway_resource.reset_password.id,
      aws_api_gateway_resource.verify.id,
      aws_api_gateway_resource.analytics.id,
      aws_api_gateway_resource.analytics_system.id,
      aws_api_gateway_resource.analytics_query.id,
      aws_api_gateway_resource.analytics_forecast.id,
      aws_api_gateway_resource.analytics_insights.id,
      aws_api_gateway_method.register_post.id,
      aws_api_gateway_method.login_post.id,
      aws_api_gateway_method.forgot_password_post.id,
      aws_api_gateway_method.reset_password_post.id,
      aws_api_gateway_method.verify_post.id,
      aws_api_gateway_method.analytics_query_get.id,
      aws_api_gateway_method.analytics_forecast_post.id,
      aws_api_gateway_method.analytics_insights_get.id,
      aws_api_gateway_integration.register_lambda.id,
      aws_api_gateway_integration.login_lambda.id,
      aws_api_gateway_integration.forgot_password_lambda.id,
      aws_api_gateway_integration.reset_password_lambda.id,
      aws_api_gateway_integration.verify_lambda.id,
      aws_api_gateway_integration.analytics_query_lambda.id,
      aws_api_gateway_integration.analytics_forecast_lambda.id,
      aws_api_gateway_integration.analytics_insights_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.register_lambda,
    aws_api_gateway_integration.login_lambda,
    aws_api_gateway_integration.forgot_password_lambda,
    aws_api_gateway_integration.reset_password_lambda,
    aws_api_gateway_integration.verify_lambda,
    # Conditional integrations removed from depends_on
    # They will be included automatically when they exist
  ]
}

# IAM role for API Gateway to write to CloudWatch Logs
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.api_name}-cloudwatch-role"

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

# IAM policy attachment for API Gateway CloudWatch Logs
resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# API Gateway account settings (sets CloudWatch Logs role for the account)
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# API Gateway stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.stage_name

  # Enable CloudWatch logging
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  # Enable X-Ray tracing
  xray_tracing_enabled = var.enable_xray_tracing

  tags = var.tags
  
  depends_on = [aws_api_gateway_account.main]
}

# CloudWatch log group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

# API Gateway method settings (throttling)
resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = var.enable_data_trace
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }
}

# Usage plan for rate limiting
resource "aws_api_gateway_usage_plan" "main" {
  name        = "${var.api_name}-usage-plan"
  description = "Usage plan for ${var.api_name}"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_stage.main.stage_name
  }

  quota_settings {
    limit  = var.quota_limit
    period = "DAY"
  }

  throttle_settings {
    burst_limit = var.throttling_burst_limit
    rate_limit  = var.throttling_rate_limit
  }

  tags = var.tags
}

# CloudWatch alarm for 4XX errors
resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "${var.api_name}-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_threshold_4xx
  alarm_description   = "Alert when API Gateway 4XX errors exceed threshold"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = var.tags
}

# CloudWatch alarm for 5XX errors
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "${var.api_name}-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_threshold_5xx
  alarm_description   = "Alert when API Gateway 5XX errors exceed threshold"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = var.tags
}

# CloudWatch alarm for latency
resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${var.api_name}-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = var.latency_threshold_ms
  alarm_description   = "Alert when API Gateway latency exceeds threshold"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  tags = var.tags
}

# ========================================
# Demand Insights Engine Resources
# ========================================

# /demand-insights resource
resource "aws_api_gateway_resource" "demand_insights" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "demand-insights"
}

# /demand-insights/segments resource
resource "aws_api_gateway_resource" "di_segments" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.demand_insights.id
  path_part   = "segments"
}

# /demand-insights/forecast resource
resource "aws_api_gateway_resource" "di_forecast" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.demand_insights.id
  path_part   = "forecast"
}

# /demand-insights/price-elasticity resource
resource "aws_api_gateway_resource" "di_price_elasticity" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.demand_insights.id
  path_part   = "price-elasticity"
}

# /demand-insights/price-optimization resource
resource "aws_api_gateway_resource" "di_price_optimization" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.demand_insights.id
  path_part   = "price-optimization"
}

# /demand-insights/clv resource
resource "aws_api_gateway_resource" "di_clv" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.demand_insights.id
  path_part   = "clv"
}

# /demand-insights/churn resource
resource "aws_api_gateway_resource" "di_churn" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.demand_insights.id
  path_part   = "churn"
}

# /demand-insights/at-risk-customers resource
resource "aws_api_gateway_resource" "di_at_risk_customers" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.demand_insights.id
  path_part   = "at-risk-customers"
}

# GET /demand-insights/segments method (protected)
resource "aws_api_gateway_method" "di_segments_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.di_segments.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /demand-insights/forecast method (protected)
resource "aws_api_gateway_method" "di_forecast_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.di_forecast.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /demand-insights/price-elasticity method (protected)
resource "aws_api_gateway_method" "di_price_elasticity_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.di_price_elasticity.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /demand-insights/price-optimization method (protected)
resource "aws_api_gateway_method" "di_price_optimization_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.di_price_optimization.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /demand-insights/clv method (protected)
resource "aws_api_gateway_method" "di_clv_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.di_clv.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /demand-insights/churn method (protected)
resource "aws_api_gateway_method" "di_churn_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.di_churn.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /demand-insights/at-risk-customers method (protected)
resource "aws_api_gateway_method" "di_at_risk_customers_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.di_at_risk_customers.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# Lambda integrations for Demand Insights endpoints
resource "aws_api_gateway_integration" "di_segments_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.di_segments.id
  http_method             = aws_api_gateway_method.di_segments_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.demand_insights_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "di_forecast_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.di_forecast.id
  http_method             = aws_api_gateway_method.di_forecast_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.demand_insights_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "di_price_elasticity_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.di_price_elasticity.id
  http_method             = aws_api_gateway_method.di_price_elasticity_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.demand_insights_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "di_price_optimization_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.di_price_optimization.id
  http_method             = aws_api_gateway_method.di_price_optimization_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.demand_insights_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "di_clv_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.di_clv.id
  http_method             = aws_api_gateway_method.di_clv_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.demand_insights_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "di_churn_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.di_churn.id
  http_method             = aws_api_gateway_method.di_churn_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.demand_insights_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "di_at_risk_customers_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.di_at_risk_customers.id
  http_method             = aws_api_gateway_method.di_at_risk_customers_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.demand_insights_lambda_invoke_arn
}

# Lambda permission for API Gateway to invoke demand insights function
resource "aws_lambda_permission" "api_gateway_demand_insights" {
  count         = var.demand_insights_lambda_function_name != "" ? 1 : 0
  statement_id  = "AllowAPIGatewayInvokeDemandInsights"
  action        = "lambda:InvokeFunction"
  function_name = var.demand_insights_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# ========================================
# Compliance Guardian Resources
# ========================================

# /compliance resource
resource "aws_api_gateway_resource" "compliance" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "compliance"
}

# /compliance/fraud-detection resource
resource "aws_api_gateway_resource" "compliance_fraud_detection" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.compliance.id
  path_part   = "fraud-detection"
}

# /compliance/risk-score resource
resource "aws_api_gateway_resource" "compliance_risk_score" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.compliance.id
  path_part   = "risk-score"
}

# /compliance/high-risk-transactions resource
resource "aws_api_gateway_resource" "compliance_high_risk_transactions" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.compliance.id
  path_part   = "high-risk-transactions"
}

# /compliance/pci-compliance resource
resource "aws_api_gateway_resource" "compliance_pci_compliance" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.compliance.id
  path_part   = "pci-compliance"
}

# /compliance/compliance-report resource
resource "aws_api_gateway_resource" "compliance_compliance_report" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.compliance.id
  path_part   = "compliance-report"
}

# /compliance/fraud-statistics resource
resource "aws_api_gateway_resource" "compliance_fraud_statistics" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.compliance.id
  path_part   = "fraud-statistics"
}

# POST /compliance/fraud-detection method (protected)
resource "aws_api_gateway_method" "compliance_fraud_detection_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.compliance_fraud_detection.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /compliance/risk-score method (protected)
resource "aws_api_gateway_method" "compliance_risk_score_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.compliance_risk_score.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /compliance/high-risk-transactions method (protected)
resource "aws_api_gateway_method" "compliance_high_risk_transactions_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.compliance_high_risk_transactions.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /compliance/pci-compliance method (protected)
resource "aws_api_gateway_method" "compliance_pci_compliance_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.compliance_pci_compliance.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /compliance/compliance-report method (protected)
resource "aws_api_gateway_method" "compliance_compliance_report_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.compliance_compliance_report.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /compliance/fraud-statistics method (protected)
resource "aws_api_gateway_method" "compliance_fraud_statistics_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.compliance_fraud_statistics.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# Lambda integrations for Compliance Guardian endpoints
resource "aws_api_gateway_integration" "compliance_fraud_detection_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.compliance_fraud_detection.id
  http_method             = aws_api_gateway_method.compliance_fraud_detection_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.compliance_guardian_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "compliance_risk_score_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.compliance_risk_score.id
  http_method             = aws_api_gateway_method.compliance_risk_score_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.compliance_guardian_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "compliance_high_risk_transactions_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.compliance_high_risk_transactions.id
  http_method             = aws_api_gateway_method.compliance_high_risk_transactions_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.compliance_guardian_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "compliance_pci_compliance_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.compliance_pci_compliance.id
  http_method             = aws_api_gateway_method.compliance_pci_compliance_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.compliance_guardian_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "compliance_compliance_report_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.compliance_compliance_report.id
  http_method             = aws_api_gateway_method.compliance_compliance_report_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.compliance_guardian_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "compliance_fraud_statistics_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.compliance_fraud_statistics.id
  http_method             = aws_api_gateway_method.compliance_fraud_statistics_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.compliance_guardian_lambda_invoke_arn
}

# Lambda permission for API Gateway to invoke compliance guardian function
resource "aws_lambda_permission" "api_gateway_compliance_guardian" {
  count         = var.compliance_guardian_lambda_function_name != "" ? 1 : 0
  statement_id  = "AllowAPIGatewayInvokeComplianceGuardian"
  action        = "lambda:InvokeFunction"
  function_name = var.compliance_guardian_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}


# ========================================
# Retail Copilot Resources
# ========================================

# /copilot resource
resource "aws_api_gateway_resource" "copilot" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "copilot"
}

# /copilot/chat resource
resource "aws_api_gateway_resource" "copilot_chat" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.copilot.id
  path_part   = "chat"
}

# /copilot/conversations resource
resource "aws_api_gateway_resource" "copilot_conversations" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.copilot.id
  path_part   = "conversations"
}

# /copilot/conversation resource
resource "aws_api_gateway_resource" "copilot_conversation" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.copilot.id
  path_part   = "conversation"
}

# /copilot/inventory resource
resource "aws_api_gateway_resource" "copilot_inventory" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.copilot.id
  path_part   = "inventory"
}

# /copilot/orders resource
resource "aws_api_gateway_resource" "copilot_orders" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.copilot.id
  path_part   = "orders"
}

# /copilot/customers resource
resource "aws_api_gateway_resource" "copilot_customers" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.copilot.id
  path_part   = "customers"
}

# /copilot/recommendations resource
resource "aws_api_gateway_resource" "copilot_recommendations" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.copilot.id
  path_part   = "recommendations"
}

# /copilot/sales-report resource
resource "aws_api_gateway_resource" "copilot_sales_report" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.copilot.id
  path_part   = "sales-report"
}

# POST /copilot/chat method (protected)
resource "aws_api_gateway_method" "copilot_chat_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.copilot_chat.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /copilot/conversations method (protected)
resource "aws_api_gateway_method" "copilot_conversations_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.copilot_conversations.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /copilot/conversation method (protected)
resource "aws_api_gateway_method" "copilot_conversation_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.copilot_conversation.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /copilot/conversation method (protected)
resource "aws_api_gateway_method" "copilot_conversation_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.copilot_conversation.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# DELETE /copilot/conversation method (protected)
resource "aws_api_gateway_method" "copilot_conversation_delete" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.copilot_conversation.id
  http_method   = "DELETE"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /copilot/inventory method (protected)
resource "aws_api_gateway_method" "copilot_inventory_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.copilot_inventory.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /copilot/orders method (protected)
resource "aws_api_gateway_method" "copilot_orders_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.copilot_orders.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /copilot/customers method (protected)
resource "aws_api_gateway_method" "copilot_customers_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.copilot_customers.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /copilot/recommendations method (protected)
resource "aws_api_gateway_method" "copilot_recommendations_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.copilot_recommendations.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /copilot/sales-report method (protected)
resource "aws_api_gateway_method" "copilot_sales_report_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.copilot_sales_report.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# Lambda integrations for Retail Copilot endpoints
resource "aws_api_gateway_integration" "copilot_chat_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.copilot_chat.id
  http_method             = aws_api_gateway_method.copilot_chat_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.retail_copilot_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "copilot_conversations_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.copilot_conversations.id
  http_method             = aws_api_gateway_method.copilot_conversations_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.retail_copilot_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "copilot_conversation_post_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.copilot_conversation.id
  http_method             = aws_api_gateway_method.copilot_conversation_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.retail_copilot_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "copilot_conversation_get_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.copilot_conversation.id
  http_method             = aws_api_gateway_method.copilot_conversation_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.retail_copilot_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "copilot_conversation_delete_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.copilot_conversation.id
  http_method             = aws_api_gateway_method.copilot_conversation_delete.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.retail_copilot_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "copilot_inventory_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.copilot_inventory.id
  http_method             = aws_api_gateway_method.copilot_inventory_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.retail_copilot_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "copilot_orders_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.copilot_orders.id
  http_method             = aws_api_gateway_method.copilot_orders_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.retail_copilot_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "copilot_customers_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.copilot_customers.id
  http_method             = aws_api_gateway_method.copilot_customers_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.retail_copilot_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "copilot_recommendations_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.copilot_recommendations.id
  http_method             = aws_api_gateway_method.copilot_recommendations_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.retail_copilot_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "copilot_sales_report_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.copilot_sales_report.id
  http_method             = aws_api_gateway_method.copilot_sales_report_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.retail_copilot_lambda_invoke_arn
}

# Lambda permission for API Gateway to invoke retail copilot function
resource "aws_lambda_permission" "api_gateway_retail_copilot" {
  count         = var.retail_copilot_lambda_function_name != "" ? 1 : 0
  statement_id  = "AllowAPIGatewayInvokeRetailCopilot"
  action        = "lambda:InvokeFunction"
  function_name = var.retail_copilot_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}


# ========================================
# Global Market Pulse Resources
# ========================================

# /global-market resource
resource "aws_api_gateway_resource" "global_market" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "global-market"
}

# /global-market/trends resource
resource "aws_api_gateway_resource" "gm_trends" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.global_market.id
  path_part   = "trends"
}

# /global-market/regional-prices resource
resource "aws_api_gateway_resource" "gm_regional_prices" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.global_market.id
  path_part   = "regional-prices"
}

# /global-market/price-comparison resource
resource "aws_api_gateway_resource" "gm_price_comparison" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.global_market.id
  path_part   = "price-comparison"
}

# /global-market/opportunities resource
resource "aws_api_gateway_resource" "gm_opportunities" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.global_market.id
  path_part   = "opportunities"
}

# /global-market/competitor-analysis resource
resource "aws_api_gateway_resource" "gm_competitor_analysis" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.global_market.id
  path_part   = "competitor-analysis"
}

# /global-market/market-share resource
resource "aws_api_gateway_resource" "gm_market_share" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.global_market.id
  path_part   = "market-share"
}

# /global-market/growth-rates resource
resource "aws_api_gateway_resource" "gm_growth_rates" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.global_market.id
  path_part   = "growth-rates"
}

# /global-market/trend-changes resource
resource "aws_api_gateway_resource" "gm_trend_changes" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.global_market.id
  path_part   = "trend-changes"
}

# GET /global-market/trends method (protected)
resource "aws_api_gateway_method" "gm_trends_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.gm_trends.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /global-market/regional-prices method (protected)
resource "aws_api_gateway_method" "gm_regional_prices_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.gm_regional_prices.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /global-market/price-comparison method (protected)
resource "aws_api_gateway_method" "gm_price_comparison_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.gm_price_comparison.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /global-market/opportunities method (protected)
resource "aws_api_gateway_method" "gm_opportunities_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.gm_opportunities.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /global-market/competitor-analysis method (protected)
resource "aws_api_gateway_method" "gm_competitor_analysis_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.gm_competitor_analysis.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /global-market/market-share method (protected)
resource "aws_api_gateway_method" "gm_market_share_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.gm_market_share.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# GET /global-market/growth-rates method (protected)
resource "aws_api_gateway_method" "gm_growth_rates_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.gm_growth_rates.id
  http_method   = "GET"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# POST /global-market/trend-changes method (protected)
resource "aws_api_gateway_method" "gm_trend_changes_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.gm_trend_changes.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt.id
}

# Lambda integrations for Global Market Pulse endpoints
resource "aws_api_gateway_integration" "gm_trends_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.gm_trends.id
  http_method             = aws_api_gateway_method.gm_trends_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.global_market_pulse_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "gm_regional_prices_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.gm_regional_prices.id
  http_method             = aws_api_gateway_method.gm_regional_prices_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.global_market_pulse_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "gm_price_comparison_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.gm_price_comparison.id
  http_method             = aws_api_gateway_method.gm_price_comparison_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.global_market_pulse_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "gm_opportunities_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.gm_opportunities.id
  http_method             = aws_api_gateway_method.gm_opportunities_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.global_market_pulse_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "gm_competitor_analysis_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.gm_competitor_analysis.id
  http_method             = aws_api_gateway_method.gm_competitor_analysis_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.global_market_pulse_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "gm_market_share_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.gm_market_share.id
  http_method             = aws_api_gateway_method.gm_market_share_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.global_market_pulse_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "gm_growth_rates_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.gm_growth_rates.id
  http_method             = aws_api_gateway_method.gm_growth_rates_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.global_market_pulse_lambda_invoke_arn
}

resource "aws_api_gateway_integration" "gm_trend_changes_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.gm_trend_changes.id
  http_method             = aws_api_gateway_method.gm_trend_changes_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.global_market_pulse_lambda_invoke_arn
}

# Lambda permission for API Gateway to invoke global market pulse function
resource "aws_lambda_permission" "api_gateway_global_market_pulse" {
  count         = var.global_market_pulse_lambda_function_name != "" ? 1 : 0
  statement_id  = "AllowAPIGatewayInvokeGlobalMarketPulse"
  action        = "lambda:InvokeFunction"
  function_name = var.global_market_pulse_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
