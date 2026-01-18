# Add Mock Integrations for All Service Endpoints

## Problem

The error "Invalid integration URI specified" occurs because:

1. Analytics integrations have `count` parameters that should skip creation when Lambda ARN is empty
2. BUT Terraform is trying to UPDATE existing integrations (from previous deployment) with empty URIs
3. Other service endpoints (demand-insights, compliance, retail-copilot, global-market-pulse, market-intelligence) don't have mock integrations yet

## Solution

Add mock integrations for ALL service endpoints, just like we did for analytics endpoints.

## Services That Need Mock Integrations

1. **Market Intelligence** (4 endpoints)
   - /market-intelligence/forecast
   - /market-intelligence/trends
   - /market-intelligence/competitive-pricing
   - /market-intelligence/compare-models

2. **Demand Insights** (7 endpoints)
   - /demand-insights/segments
   - /demand-insights/forecast
   - /demand-insights/price-elasticity
   - /demand-insights/price-optimization
   - /demand-insights/clv
   - /demand-insights/churn
   - /demand-insights/at-risk-customers

3. **Compliance Guardian** (6 endpoints)
   - /compliance/fraud-detection
   - /compliance/risk-score
   - /compliance/high-risk-transactions
   - /compliance/pci-compliance
   - /compliance/compliance-report
   - /compliance/fraud-statistics

4. **Retail Copilot** (10 endpoints)
   - /copilot/chat
   - /copilot/conversations
   - /copilot/conversation (POST, GET, DELETE)
   - /copilot/inventory
   - /copilot/orders
   - /copilot/customers
   - /copilot/recommendations
   - /copilot/sales-report

5. **Global Market Pulse** (8 endpoints)
   - /global-market/trends
   - /global-market/regional-prices
   - /global-market/price-comparison
   - /global-market/opportunities
   - /global-market/competitor-analysis
   - /global-market/market-share
   - /global-market/growth-rates
   - /global-market/trend-changes

## Total: 35 endpoints need mock integrations

## Implementation Pattern

For each endpoint, add:

```hcl
# Mock integration (when Lambda NOT deployed)
resource "aws_api_gateway_integration" "ENDPOINT_NAME_mock" {
  count       = var.SERVICE_lambda_invoke_arn == "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.RESOURCE_NAME.id
  http_method = aws_api_gateway_method.METHOD_NAME.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 501
    })
  }
}

# Mock integration response
resource "aws_api_gateway_integration_response" "ENDPOINT_NAME_mock" {
  count       = var.SERVICE_lambda_invoke_arn == "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.RESOURCE_NAME.id
  http_method = aws_api_gateway_method.METHOD_NAME.http_method
  status_code = "501"
  
  response_templates = {
    "application/json" = jsonencode({
      message = "Lambda function not deployed yet"
      endpoint = "/SERVICE/ENDPOINT"
    })
  }
  
  depends_on = [aws_api_gateway_integration.ENDPOINT_NAME_mock]
}

# Method response
resource "aws_api_gateway_method_response" "ENDPOINT_NAME_501" {
  count       = var.SERVICE_lambda_invoke_arn == "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.RESOURCE_NAME.id
  http_method = aws_api_gateway_method.METHOD_NAME.http_method
  status_code = "501"
}
```

## Next Steps

1. Add mock integrations for all 35 endpoints
2. Update deployment triggers to include mock integrations
3. Run `terraform apply`
4. All endpoints will return 501 until Lambda functions are deployed

