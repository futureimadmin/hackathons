# CORS Configuration for API Gateway
# Comprehensive CORS setup for all endpoints

# Gateway Response for CORS (applies to all endpoints)
resource "aws_api_gateway_gateway_response" "cors_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "DEFAULT_4XX"

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = var.cors_allowed_origin != "*" ? "'${var.cors_allowed_origin}'" : "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
  }
}

resource "aws_api_gateway_gateway_response" "cors_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  response_type = "DEFAULT_5XX"

  response_templates = {
    "application/json" = "{\"message\":$context.error.messageString}"
  }

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin"  = var.cors_allowed_origin != "*" ? "'${var.cors_allowed_origin}'" : "'*'"
    "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "gatewayresponse.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
  }
}

# Root OPTIONS method for preflight requests
resource "aws_api_gateway_method" "root_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_rest_api.main.root_resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_rest_api.main.root_resource_id
  http_method = aws_api_gateway_method.root_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "root_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_rest_api.main.root_resource_id
  http_method = aws_api_gateway_method.root_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "root_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_rest_api.main.root_resource_id
  http_method = aws_api_gateway_method.root_options.http_method
  status_code = aws_api_gateway_method_response.root_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = var.cors_allowed_origin != "*" ? "'${var.cors_allowed_origin}'" : "'*'"
  }

  depends_on = [aws_api_gateway_integration.root_options]
}

# Macro to create OPTIONS method for any resource
locals {
  # List all resources that need OPTIONS methods
  cors_resources = {
    auth                           = aws_api_gateway_resource.auth.id
    register                      = aws_api_gateway_resource.register.id
    login                         = aws_api_gateway_resource.login.id
    forgot_password               = aws_api_gateway_resource.forgot_password.id
    reset_password                = aws_api_gateway_resource.reset_password.id
    verify                        = aws_api_gateway_resource.verify.id
    analytics                     = aws_api_gateway_resource.analytics.id
    analytics_system              = aws_api_gateway_resource.analytics_system.id
    analytics_query               = aws_api_gateway_resource.analytics_query.id
    analytics_forecast            = aws_api_gateway_resource.analytics_forecast.id
    analytics_insights            = aws_api_gateway_resource.analytics_insights.id
    market_intelligence           = aws_api_gateway_resource.market_intelligence.id
    mi_forecast                   = aws_api_gateway_resource.mi_forecast.id
    mi_trends                     = aws_api_gateway_resource.mi_trends.id
    mi_competitive_pricing        = aws_api_gateway_resource.mi_competitive_pricing.id
    mi_compare_models             = aws_api_gateway_resource.mi_compare_models.id
    demand_insights               = aws_api_gateway_resource.demand_insights.id
    di_segments                   = aws_api_gateway_resource.di_segments.id
    di_forecast                   = aws_api_gateway_resource.di_forecast.id
    di_price_elasticity           = aws_api_gateway_resource.di_price_elasticity.id
    di_price_optimization         = aws_api_gateway_resource.di_price_optimization.id
    di_clv                        = aws_api_gateway_resource.di_clv.id
    di_churn                      = aws_api_gateway_resource.di_churn.id
    di_at_risk_customers          = aws_api_gateway_resource.di_at_risk_customers.id
    compliance                    = aws_api_gateway_resource.compliance.id
    compliance_fraud_detection    = aws_api_gateway_resource.compliance_fraud_detection.id
    compliance_risk_score         = aws_api_gateway_resource.compliance_risk_score.id
    compliance_high_risk_transactions = aws_api_gateway_resource.compliance_high_risk_transactions.id
    compliance_pci_compliance     = aws_api_gateway_resource.compliance_pci_compliance.id
    compliance_compliance_report  = aws_api_gateway_resource.compliance_compliance_report.id
    compliance_fraud_statistics   = aws_api_gateway_resource.compliance_fraud_statistics.id
    copilot                       = aws_api_gateway_resource.copilot.id
    copilot_chat                  = aws_api_gateway_resource.copilot_chat.id
    copilot_conversations         = aws_api_gateway_resource.copilot_conversations.id
    copilot_conversation          = aws_api_gateway_resource.copilot_conversation.id
    copilot_inventory             = aws_api_gateway_resource.copilot_inventory.id
    copilot_orders                = aws_api_gateway_resource.copilot_orders.id
    copilot_customers             = aws_api_gateway_resource.copilot_customers.id
    copilot_recommendations       = aws_api_gateway_resource.copilot_recommendations.id
    copilot_sales_report          = aws_api_gateway_resource.copilot_sales_report.id
    global_market                 = aws_api_gateway_resource.global_market.id
    gm_trends                     = aws_api_gateway_resource.gm_trends.id
    gm_regional_prices            = aws_api_gateway_resource.gm_regional_prices.id
    gm_price_comparison           = aws_api_gateway_resource.gm_price_comparison.id
    gm_opportunities              = aws_api_gateway_resource.gm_opportunities.id
    gm_competitor_analysis        = aws_api_gateway_resource.gm_competitor_analysis.id
    gm_market_share               = aws_api_gateway_resource.gm_market_share.id
    gm_growth_rates               = aws_api_gateway_resource.gm_growth_rates.id
    gm_trend_changes              = aws_api_gateway_resource.gm_trend_changes.id
  }
}

# OPTIONS methods for all resources
resource "aws_api_gateway_method" "options" {
  for_each = local.cors_resources

  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = each.value
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = each.value
  http_method = aws_api_gateway_method.options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = each.value
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = each.value
  http_method = aws_api_gateway_method.options[each.key].http_method
  status_code = aws_api_gateway_method_response.options[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,X-Amz-User-Agent'"
    "method.response.header.Access-Control-Allow-Methods" = "'DELETE,GET,HEAD,OPTIONS,PATCH,POST,PUT'"
    "method.response.header.Access-Control-Allow-Origin"  = var.cors_allowed_origin != "*" ? "'${var.cors_allowed_origin}'" : "'*'"
  }

  depends_on = [aws_api_gateway_integration.options]
}
