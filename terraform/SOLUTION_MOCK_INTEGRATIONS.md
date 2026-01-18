# Solution: Mock Integrations for Undeployed Lambda Functions

## The Problem

API Gateway requires that **every method must have an integration**. When we made the analytics Lambda integrations conditional (not created when Lambda ARN is empty), the analytics methods had no integrations, causing deployment to fail with:

```
Error: No integration defined for method
```

## The Solution

Create **mock integrations** for methods when Lambda functions aren't deployed. This keeps the API structure intact while providing meaningful responses.

### Mock Integration Approach

For each analytics endpoint, we now have TWO integration resources:

1. **Lambda Integration** - Created when Lambda function exists (`count = var.analytics_lambda_invoke_arn != "" ? 1 : 0`)
2. **Mock Integration** - Created when Lambda function doesn't exist (`count = var.analytics_lambda_invoke_arn == "" ? 1 : 0`)

Only ONE of these will exist at any time.

### Mock Integration Response

Mock integrations return HTTP 501 (Not Implemented) with a JSON message:

```json
{
  "message": "Lambda function not deployed yet",
  "endpoint": "/analytics/{system}/query"
}
```

This is better than:
- ❌ 500 Internal Server Error (looks like a bug)
- ❌ 404 Not Found (endpoint doesn't exist)
- ✅ 501 Not Implemented (feature not ready yet)

## Implementation

### Example: Analytics Query Endpoint

```hcl
# Lambda integration (when Lambda deployed)
resource "aws_api_gateway_integration" "analytics_query_lambda" {
  count                   = var.analytics_lambda_invoke_arn != "" ? 1 : 0
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.analytics_query.id
  http_method             = aws_api_gateway_method.analytics_query_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.analytics_lambda_invoke_arn
}

# Mock integration (when Lambda NOT deployed)
resource "aws_api_gateway_integration" "analytics_query_mock" {
  count       = var.analytics_lambda_invoke_arn == "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.analytics_query.id
  http_method = aws_api_gateway_method.analytics_query_get.http_method
  type        = "MOCK"
  
  request_templates = {
    "application/json" = jsonencode({
      statusCode = 501
    })
  }
}

# Mock integration response
resource "aws_api_gateway_integration_response" "analytics_query_mock" {
  count       = var.analytics_lambda_invoke_arn == "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.analytics_query.id
  http_method = aws_api_gateway_method.analytics_query_get.http_method
  status_code = "501"
  
  response_templates = {
    "application/json" = jsonencode({
      message = "Lambda function not deployed yet"
      endpoint = "/analytics/{system}/query"
    })
  }
  
  depends_on = [aws_api_gateway_integration.analytics_query_mock]
}

# Method response
resource "aws_api_gateway_method_response" "analytics_query_501" {
  count       = var.analytics_lambda_invoke_arn == "" ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.analytics_query.id
  http_method = aws_api_gateway_method.analytics_query_get.http_method
  status_code = "501"
}
```

### Applied To

- `/analytics/{system}/query` (GET)
- `/analytics/{system}/forecast` (POST)
- `/analytics/{system}/insights` (GET)

## What This Means

### Before Lambda Deployment

```bash
curl https://your-api.execute-api.us-east-2.amazonaws.com/dev/analytics/market-intelligence-hub/query
```

**Response:**
```json
HTTP/1.1 501 Not Implemented
{
  "message": "Lambda function not deployed yet",
  "endpoint": "/analytics/{system}/query"
}
```

### After Lambda Deployment

1. Update `terraform/main.tf`:
   ```hcl
   analytics_lambda_function_name = "${var.project_name}-analytics-${var.environment}"
   analytics_lambda_invoke_arn    = "arn:aws:apigateway:..."
   ```

2. Run `terraform apply`

3. Mock integrations are destroyed, Lambda integrations are created

4. Same request now goes to Lambda function

## Benefits

✅ API Gateway deploys successfully without Lambda functions
✅ All endpoints exist and are documented
✅ Clear error messages (501 Not Implemented)
✅ Easy transition when Lambda functions are deployed
✅ No API structure changes needed

## Other Endpoints

**Auth endpoints** - Use placeholder Lambda ARNs (will return 500 until Lambda deployed)
**Other service endpoints** - Already have conditional integrations with `count` parameters

## Deployment

```powershell
cd terraform
terraform apply
```

Should now complete successfully with all endpoints created!

## Testing

### Test Mock Integration

```powershell
$apiUrl = terraform output -raw api_gateway_url
curl "$apiUrl/analytics/market-intelligence-hub/query"
```

**Expected:** 501 Not Implemented with JSON message

### Test After Lambda Deployment

After deploying analytics Lambda and running `terraform apply`:

```powershell
curl "$apiUrl/analytics/market-intelligence-hub/query" -H "Authorization: Bearer YOUR_TOKEN"
```

**Expected:** 200 OK with actual data from Lambda

## Summary

Mock integrations solve the "No integration defined for method" error by providing placeholder integrations that return meaningful 501 responses. This allows the API Gateway to deploy successfully while clearly indicating which features aren't ready yet.
