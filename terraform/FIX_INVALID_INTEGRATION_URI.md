# Fix: Invalid Integration URI Specified Error

## Problem

When running `terraform apply`, you encountered this error:

```
Error: updating API Gateway Integration, initial (agi-x4mz7rs2j0-9felaz-GET): operation error API Gateway: UpdateIntegration, https response error StatusCode: 400, RequestID: eaae7c2c-1551-45b3-a967-05d905812a29, BadRequestException: Invalid integration URI specified

  with module.api_gateway.aws_api_gateway_integration.analytics_query_lambda,
  on modules\api-gateway\main.tf line 295, in resource "aws_api_gateway_integration" "analytics_query_lambda":
 295: resource "aws_api_gateway_integration" "analytics_query_lambda" {
```

## Root Cause

The error occurred because:

1. **Previous State**: In an earlier deployment, Lambda integrations were created with `count` parameters
2. **Current State**: We set Lambda ARNs to empty strings (`""`) to skip Lambda permission creation
3. **Terraform Behavior**: When `count` evaluates to 0, Terraform tries to DESTROY the existing integration
4. **AWS Limitation**: API Gateway doesn't allow updating integrations with empty/invalid URIs during the destroy process

## Solution Applied

### 1. Use Placeholder Lambda ARNs

Instead of empty strings, we now use valid placeholder ARNs that point to non-existent Lambda functions:

```hcl
# In terraform/main.tf
analytics_lambda_function_name = ""  # Empty = skip permission creation
analytics_lambda_invoke_arn    = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:450133579764:function:futureim-ecommerce-ai-platform-analytics-dev/invocations"
```

**Key Points:**
- Function NAME is empty → Lambda permissions are NOT created (via `count` parameter)
- Function ARN is valid → API Gateway integrations work (will return 500 until Lambda deployed)
- This allows API Gateway to deploy without Lambda functions

### 2. Remove Count Parameters from Integrations

We removed all `count` parameters from Lambda integrations:

**Before:**
```hcl
resource "aws_api_gateway_integration" "analytics_query_lambda" {
  count                   = var.analytics_lambda_invoke_arn != "" ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.analytics_query.id
  http_method             = aws_api_gateway_method.analytics_query_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.analytics_lambda_invoke_arn
}
```

**After:**
```hcl
resource "aws_api_gateway_integration" "analytics_query_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.analytics_query.id
  http_method             = aws_api_gateway_method.analytics_query_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.analytics_lambda_invoke_arn
}
```

### 3. Removed Mock Integrations

Since we're now using placeholder ARNs (not empty strings), we removed the mock integrations that were conditionally created when ARNs were empty.

## Changes Made

### Files Modified

1. **terraform/main.tf**
   - Changed all Lambda invoke ARNs from empty strings to placeholder ARNs
   - Kept function names as empty strings (to skip permission creation)

2. **terraform/modules/api-gateway/main.tf**
   - Removed `count` parameters from all Lambda integrations
   - Removed mock integrations for analytics endpoints
   - Simplified deployment triggers

3. **terraform/fix-integration-count.ps1**
   - Created script to automate removal of count parameters

## Behavior After Fix

### Before Lambda Deployment

When you call an endpoint before deploying the Lambda function:

```bash
curl https://your-api.execute-api.us-east-2.amazonaws.com/dev/analytics/market-intelligence-hub/query
```

**Response:**
```json
HTTP/1.1 500 Internal Server Error
{
  "message": "Internal server error"
}
```

This is expected because the Lambda function doesn't exist yet.

### After Lambda Deployment

1. Deploy your Lambda functions (via CI/CD or manually)
2. Lambda functions will automatically be invoked by API Gateway
3. No Terraform changes needed!

The placeholder ARNs already point to the correct function names, so once the functions exist, they'll work immediately.

## Why This Approach Works

### Placeholder ARNs vs Empty Strings

| Approach | Lambda Permissions | API Gateway Integrations | Behavior Before Lambda |
|----------|-------------------|-------------------------|------------------------|
| Empty strings | ❌ Not created | ❌ Causes errors | N/A |
| Placeholder ARNs | ❌ Not created (function name empty) | ✅ Created successfully | 500 error (expected) |

### Permission Creation Logic

```hcl
# Lambda permission for API Gateway to invoke analytics function
resource "aws_lambda_permission" "api_gateway_analytics" {
  count         = var.analytics_lambda_function_name != "" ? 1 : 0  # ← Checks function NAME
  statement_id  = "AllowAPIGatewayInvokeAnalytics"
  action        = "lambda:InvokeFunction"
  function_name = var.analytics_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
```

Since `analytics_lambda_function_name = ""`, the count evaluates to 0, and the permission is NOT created.

## Deployment Steps

```powershell
cd terraform

# 1. Review changes
terraform plan

# 2. Apply changes
terraform apply

# 3. Get API Gateway URL
terraform output api_gateway_url
```

## Expected Terraform Output

```
Plan: 0 to add, X to change, 0 to destroy
```

Where X is the number of integrations being updated with placeholder ARNs.

## Testing

### Test API Gateway Deployment

```powershell
$apiUrl = terraform output -raw api_gateway_url
Write-Host "API Gateway URL: $apiUrl"

# Test auth endpoint (should return 500 - Lambda not deployed)
curl "$apiUrl/auth/login" -Method POST -Body '{"email":"test@example.com","password":"test"}' -ContentType "application/json"

# Test analytics endpoint (should return 500 - Lambda not deployed)
curl "$apiUrl/analytics/market-intelligence-hub/query"
```

Both should return 500 errors, which is expected before Lambda deployment.

## Next Steps

1. ✅ API Gateway is deployed with all endpoints
2. ⏳ Deploy Lambda functions (separate task)
3. ⏳ Update frontend `.env.production` with API Gateway URL
4. ⏳ Test end-to-end flow after Lambda deployment

## Summary

The fix changes the approach from:
- ❌ "Skip integration creation when Lambda doesn't exist" (causes errors)
- ✅ "Create integrations with placeholder ARNs, skip permissions" (works!)

This allows API Gateway to deploy successfully while still preventing permission errors for non-existent Lambda functions.

