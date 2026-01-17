# API Gateway Setup Guide

Complete guide for deploying API Gateway with authentication endpoints.

## Overview

This guide walks through setting up API Gateway REST API with:
- Authentication endpoints (register, login, forgot/reset password, verify)
- JWT token authorizer for protected endpoints
- CORS configuration for frontend access
- Rate limiting and throttling
- AWS WAF with OWASP security rules
- CloudWatch monitoring and alarms

## Prerequisites

- ✅ Terraform installed
- ✅ AWS CLI configured
- ✅ Auth Lambda function deployed (Task 10)
- ✅ DynamoDB users table created
- ✅ JWT secret in Secrets Manager
- ✅ Node.js installed (for packaging authorizer)

## Architecture

```
Frontend (React)
    ↓
AWS WAF (Security)
    ↓
API Gateway REST API
    ├── /auth/register → Auth Lambda
    ├── /auth/login → Auth Lambda
    ├── /auth/forgot-password → Auth Lambda
    ├── /auth/reset-password → Auth Lambda
    └── /auth/verify → JWT Authorizer → Auth Lambda
```

## Step-by-Step Deployment

### Step 1: Package Lambda Authorizer

The JWT authorizer is a Node.js Lambda function that verifies JWT tokens.

```powershell
# Navigate to authorizer directory
cd terraform/modules/api-gateway/lambda

# Package the function
.\package.ps1
```

This creates `authorizer.zip` containing:
- `index.js` - Authorizer logic
- `package.json` - Dependencies
- `node_modules/` - AWS SDK and jsonwebtoken

**Expected output:**
```
Packaging Lambda authorizer...
Installing dependencies...
Creating deployment package...
✓ Package created: authorizer.zip (2.5 MB)
Packaging complete!
```

### Step 2: Add API Gateway Module to Main Terraform

Edit `terraform/main.tf`:

```hcl
# API Gateway Module
module "api_gateway" {
  source = "./modules/api-gateway"

  api_name                   = "ecommerce-platform-api"
  stage_name                 = var.environment
  auth_lambda_function_name  = "ecommerce-auth-service"
  auth_lambda_invoke_arn     = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:ecommerce-auth-service"
  jwt_secret_name            = "ecommerce-jwt-secret"
  kms_key_arn                = module.kms.key_arn
  cors_allowed_origin        = var.frontend_url

  # Throttling configuration
  throttling_burst_limit = 5000
  throttling_rate_limit  = 10000
  quota_limit            = 1000000

  # WAF configuration
  enable_waf             = true
  waf_rate_limit         = 2000
  waf_blocked_countries  = []  # Add country codes to block if needed

  # Monitoring
  enable_xray_tracing    = true
  log_retention_days     = 30
  alarm_actions          = []  # Add SNS topic ARN for alerts

  tags = local.common_tags
}

# Output API endpoint
output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "api_endpoints" {
  description = "All API endpoints"
  value       = module.api_gateway.api_endpoints
}
```

### Step 3: Add Variables

Edit `terraform/variables.tf`:

```hcl
variable "frontend_url" {
  description = "Frontend URL for CORS configuration"
  type        = string
  default     = "*"  # Change to specific URL in production
}
```

### Step 4: Deploy with Terraform

```powershell
cd terraform

# Initialize Terraform (if not already done)
terraform init

# Plan deployment
terraform plan

# Apply changes
terraform apply
```

**Review the plan carefully:**
- API Gateway REST API
- 5 API resources (/auth/register, /auth/login, etc.)
- 5 POST methods + 5 OPTIONS methods (CORS)
- Lambda integrations
- JWT authorizer Lambda function
- WAF Web ACL with 4 managed rule sets
- CloudWatch log groups and alarms
- IAM roles and policies

**Type `yes` to confirm.**

### Step 5: Verify Deployment

```powershell
# Get API endpoint
terraform output api_endpoint
# Output: https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod

# Get all endpoints
terraform output api_endpoints
```

### Step 6: Test API Endpoints

#### Test Registration

```powershell
$apiUrl = terraform output -raw api_endpoint

$registerBody = @{
    email = "john.doe@example.com"
    password = "SecurePass123!"
    name = "John Doe"
} | ConvertTo-Json

$registerResponse = Invoke-RestMethod `
    -Uri "$apiUrl/auth/register" `
    -Method POST `
    -Body $registerBody `
    -ContentType "application/json"

Write-Host "Registration successful!"
Write-Host "User ID: $($registerResponse.userId)"
```

#### Test Login

```powershell
$loginBody = @{
    email = "john.doe@example.com"
    password = "SecurePass123!"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod `
    -Uri "$apiUrl/auth/login" `
    -Method POST `
    -Body $loginBody `
    -ContentType "application/json"

$token = $loginResponse.token
Write-Host "Login successful!"
Write-Host "Token: $token"
Write-Host "User ID: $($loginResponse.userId)"
Write-Host "Name: $($loginResponse.name)"
```

#### Test Token Verification (Protected Endpoint)

```powershell
$verifyBody = @{
    token = $token
} | ConvertTo-Json

$verifyResponse = Invoke-RestMethod `
    -Uri "$apiUrl/auth/verify" `
    -Method POST `
    -Headers @{ Authorization = "Bearer $token" } `
    -Body $verifyBody `
    -ContentType "application/json"

Write-Host "Token verified!"
Write-Host "Valid: $($verifyResponse.valid)"
Write-Host "User ID: $($verifyResponse.userId)"
```

#### Test Forgot Password

```powershell
$forgotBody = @{
    email = "john.doe@example.com"
} | ConvertTo-Json

$forgotResponse = Invoke-RestMethod `
    -Uri "$apiUrl/auth/forgot-password" `
    -Method POST `
    -Body $forgotBody `
    -ContentType "application/json"

Write-Host "Password reset email sent!"
Write-Host "Message: $($forgotResponse.message)"
```

## Monitoring and Troubleshooting

### View CloudWatch Logs

```powershell
# API Gateway logs
aws logs tail /aws/apigateway/ecommerce-platform-api --follow

# Authorizer logs
aws logs tail /aws/lambda/ecommerce-platform-api-authorizer --follow

# WAF logs
aws logs tail /aws/waf/ecommerce-platform-api --follow
```

### Check CloudWatch Metrics

```powershell
# API Gateway metrics
aws cloudwatch get-metric-statistics `
    --namespace AWS/ApiGateway `
    --metric-name Count `
    --dimensions Name=ApiName,Value=ecommerce-platform-api `
    --start-time (Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ss") `
    --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") `
    --period 300 `
    --statistics Sum
```

### View WAF Blocked Requests

```powershell
# Get WAF Web ACL ID
$webAclId = terraform output -raw waf_web_acl_id

# Get sampled requests
aws wafv2 get-sampled-requests `
    --web-acl-arn $webAclId `
    --rule-metric-name ecommerce-platform-api-rate-limit `
    --scope REGIONAL `
    --time-window StartTime=(Get-Date).AddHours(-1),EndTime=(Get-Date) `
    --max-items 100
```

### Common Issues

#### 1. Authorizer Returns 401 Unauthorized

**Symptoms:**
- Protected endpoints return 401
- Authorizer logs show "Token verification failed"

**Solutions:**
```powershell
# Check JWT secret matches
aws secretsmanager get-secret-value --secret-id ecommerce-jwt-secret

# Verify token is not expired
# Tokens expire after 1 hour

# Check Authorization header format
# Must be: "Bearer <token>"
```

#### 2. CORS Errors in Browser

**Symptoms:**
- Browser console shows CORS error
- Preflight OPTIONS request fails

**Solutions:**
```powershell
# Test OPTIONS request
Invoke-RestMethod `
    -Uri "$apiUrl/auth/login" `
    -Method OPTIONS `
    -Headers @{ Origin = "https://your-frontend.com" }

# Check CORS headers in response
# Should include:
# - Access-Control-Allow-Origin
# - Access-Control-Allow-Methods
# - Access-Control-Allow-Headers
```

#### 3. Rate Limit Exceeded (429)

**Symptoms:**
- Requests return 429 Too Many Requests
- WAF blocks requests

**Solutions:**
```powershell
# Check current rate limits
terraform show | Select-String "throttling"

# Increase limits if needed (edit main.tf)
# throttling_rate_limit = 20000
# waf_rate_limit = 5000

# Apply changes
terraform apply
```

#### 4. High Latency

**Symptoms:**
- API responses take > 1 second
- CloudWatch alarm triggered

**Solutions:**
```powershell
# Enable X-Ray tracing to identify bottleneck
aws xray get-trace-summaries `
    --start-time (Get-Date).AddHours(-1) `
    --end-time (Get-Date)

# Check Lambda cold starts
aws cloudwatch get-metric-statistics `
    --namespace AWS/Lambda `
    --metric-name Duration `
    --dimensions Name=FunctionName,Value=ecommerce-auth-service `
    --start-time (Get-Date).AddHours(-1) `
    --end-time (Get-Date) `
    --period 300 `
    --statistics Average,Maximum

# Consider provisioned concurrency for auth Lambda
```

## Security Best Practices

### 1. Restrict CORS Origin

In production, change from wildcard to specific domain:

```hcl
module "api_gateway" {
  # ...
  cors_allowed_origin = "https://platform.example.com"
}
```

### 2. Enable CloudTrail

Track all API Gateway changes:

```hcl
resource "aws_cloudtrail" "api_gateway" {
  name           = "api-gateway-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail.id

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::ApiGateway::RestApi"
      values = ["${module.api_gateway.api_arn}/*"]
    }
  }
}
```

### 3. Implement API Keys

For programmatic access:

```hcl
resource "aws_api_gateway_api_key" "client" {
  name = "client-api-key"
}

resource "aws_api_gateway_usage_plan_key" "client" {
  key_id        = aws_api_gateway_api_key.client.id
  key_type      = "API_KEY"
  usage_plan_id = module.api_gateway.usage_plan_id
}
```

### 4. Set Up Alarms

Configure SNS notifications:

```hcl
resource "aws_sns_topic" "api_alerts" {
  name = "api-gateway-alerts"
}

resource "aws_sns_topic_subscription" "api_alerts_email" {
  topic_arn = aws_sns_topic.api_alerts.arn
  protocol  = "email"
  endpoint  = "alerts@example.com"
}

module "api_gateway" {
  # ...
  alarm_actions = [aws_sns_topic.api_alerts.arn]
}
```

## Cost Optimization

### Current Configuration Costs

**Assumptions:**
- 1M API calls/month
- 100K authorizer invocations (90% cached)
- WAF enabled
- 30-day log retention

**Monthly costs:**
- API Gateway: $3.50
- Lambda (Authorizer): $0.20
- WAF: $5.00
- CloudWatch Logs: $5.00
- Data Transfer: $0.90
- **Total: ~$14.60/month**

### Optimization Tips

1. **Increase authorizer cache TTL** (currently 5 min)
2. **Reduce log retention** to 7 days
3. **Disable data trace** in production
4. **Use regional endpoints** (already configured)
5. **Implement request caching** for read-heavy endpoints

## Next Steps

After API Gateway is deployed and tested:

1. ✅ Task 11.1 - API Gateway module created
2. ✅ Task 11.2 - JWT authorizer implemented
3. ✅ Task 11.3 - WAF and security configured
4. ➡️ Task 12 - Verify complete authentication flow
5. ➡️ Task 13 - Build React frontend
6. ➡️ Task 16 - Add analytics endpoints to API Gateway

## References

- [API Gateway Documentation](https://docs.aws.amazon.com/apigateway/)
- [Lambda Authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html)
- [AWS WAF](https://docs.aws.amazon.com/waf/)
- [API Gateway Best Practices](https://docs.aws.amazon.com/apigateway/latest/developerguide/best-practices.html)
