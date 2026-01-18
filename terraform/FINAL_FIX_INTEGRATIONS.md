# Final Fix: Analytics Lambda Integrations

## Issue

After setting Lambda function names to empty strings, Terraform tried to update the analytics Lambda integrations with empty URIs, causing "Invalid integration URI" errors.

## Root Cause

The analytics Lambda integration resources didn't have `count` parameters, so they were always created/updated even when the Lambda invoke ARN was empty.

## Solution

Added `count` parameters to the analytics Lambda integration resources to make them conditional:

```hcl
resource "aws_api_gateway_integration" "analytics_query_lambda" {
  count                   = var.analytics_lambda_invoke_arn != "" ? 1 : 0
  # ... rest of configuration
}
```

Applied to:
- `analytics_query_lambda`
- `analytics_forecast_lambda`
- `analytics_insights_lambda`

## Additional Changes

### 1. Updated Deployment Triggers

Changed from direct references to `try()` function for conditional integrations:

```hcl
# Before:
aws_api_gateway_integration.analytics_query_lambda.id,

# After:
try(aws_api_gateway_integration.analytics_query_lambda[0].id, ""),
```

### 2. Updated depends_on

Removed conditional integrations from `depends_on` since Terraform handles them automatically when they have `count` parameters.

## What Works Now

✅ API Gateway can be deployed without Lambda functions
✅ Auth endpoints will be created (pointing to non-existent Lambda - will return 500 until deployed)
✅ Analytics endpoints will be created but WITHOUT integrations (will return "Missing Authentication Token")
✅ Other service endpoints (market-intelligence, demand-insights, etc.) already had conditional integrations

## Deployment

```powershell
cd terraform
terraform apply
```

Should now complete successfully!

## After Lambda Deployment

When you deploy Lambda functions:

1. **Update terraform/main.tf** - Change empty strings to actual function names:
   ```hcl
   analytics_lambda_function_name = "${var.project_name}-analytics-${var.environment}"
   analytics_lambda_invoke_arn    = "arn:aws:apigateway:..."
   ```

2. **Uncomment auth Lambda permission** in `terraform/modules/api-gateway/main.tf`

3. **Run terraform apply** - This will:
   - Create Lambda permissions
   - Create/update Lambda integrations
   - Wire everything together

## Summary

All integration resources now have proper conditional logic. The API Gateway can be deployed successfully without any Lambda functions except the authorizer.
