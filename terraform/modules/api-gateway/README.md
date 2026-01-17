# API Gateway Module

Terraform module for creating API Gateway REST API with Lambda integration, JWT authorization, CORS, throttling, and WAF protection.

## Features

- ✅ REST API with authentication endpoints
- ✅ Lambda integration for auth service
- ✅ JWT token authorizer
- ✅ CORS configuration
- ✅ Rate limiting and throttling
- ✅ AWS WAF with OWASP rules
- ✅ CloudWatch logging and monitoring
- ✅ X-Ray tracing
- ✅ Usage plans and API keys

## Architecture

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│         AWS WAF                     │
│  - Rate limiting                    │
│  - OWASP Top 10 rules              │
│  - SQL injection protection        │
│  - Known bad inputs                │
└──────┬──────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│      API Gateway REST API           │
│  - /auth/register (POST)            │
│  - /auth/login (POST)               │
│  - /auth/forgot-password (POST)     │
│  - /auth/reset-password (POST)      │
│  - /auth/verify (POST) [Protected]  │
└──────┬──────────────────────────────┘
       │
       ├──────────────┬─────────────────┐
       │              │                 │
       ▼              ▼                 ▼
┌──────────┐   ┌──────────┐   ┌──────────────┐
│  Auth    │   │   JWT    │   │  CloudWatch  │
│  Lambda  │   │Authorizer│   │   Logging    │
└──────────┘   └──────────┘   └──────────────┘
```

## API Endpoints

### Public Endpoints (No Authorization)

| Method | Path | Description |
|--------|------|-------------|
| POST | /auth/register | Register new user |
| POST | /auth/login | Login with credentials |
| POST | /auth/forgot-password | Request password reset |
| POST | /auth/reset-password | Reset password with token |

### Protected Endpoints (JWT Required)

| Method | Path | Description |
|--------|------|-------------|
| POST | /auth/verify | Verify JWT token |

## Usage

### Basic Configuration

```hcl
module "api_gateway" {
  source = "./modules/api-gateway"

  api_name                   = "ecommerce-platform-api"
  stage_name                 = "prod"
  auth_lambda_function_name  = "ecommerce-auth-service"
  auth_lambda_invoke_arn     = aws_lambda_function.auth.invoke_arn
  jwt_secret_name            = "ecommerce-jwt-secret"
  kms_key_arn                = aws_kms_key.main.arn
  cors_allowed_origin        = "https://platform.example.com"

  tags = {
    Environment = "production"
    Project     = "ecommerce-platform"
  }
}
```

### With Custom Throttling

```hcl
module "api_gateway" {
  source = "./modules/api-gateway"

  # ... other variables ...

  throttling_burst_limit = 10000
  throttling_rate_limit  = 20000
  quota_limit            = 5000000
}
```

### With WAF Geo-Blocking

```hcl
module "api_gateway" {
  source = "./modules/api-gateway"

  # ... other variables ...

  enable_waf             = true
  waf_rate_limit         = 1000
  waf_blocked_countries  = ["CN", "RU", "KP"]
}
```

### Disable WAF (Not Recommended)

```hcl
module "api_gateway" {
  source = "./modules/api-gateway"

  # ... other variables ...

  enable_waf = false
}
```

## Deployment

### Step 1: Package Lambda Authorizer

```powershell
cd terraform/modules/api-gateway/lambda
.\package.ps1
```

This creates `authorizer.zip` with Node.js dependencies.

### Step 2: Deploy with Terraform

```powershell
cd terraform
terraform init
terraform plan
terraform apply
```

### Step 3: Get API Endpoint

```powershell
terraform output api_endpoint
# Output: https://abc123.execute-api.us-east-1.amazonaws.com/prod
```

## Testing

### Test Registration

```powershell
$apiUrl = "https://abc123.execute-api.us-east-1.amazonaws.com/prod"

$body = @{
    email = "test@example.com"
    password = "SecurePass123!"
    name = "Test User"
} | ConvertTo-Json

Invoke-RestMethod -Uri "$apiUrl/auth/register" `
    -Method POST `
    -Body $body `
    -ContentType "application/json"
```

### Test Login

```powershell
$body = @{
    email = "test@example.com"
    password = "SecurePass123!"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "$apiUrl/auth/login" `
    -Method POST `
    -Body $body `
    -ContentType "application/json"

$token = $response.token
Write-Host "Token: $token"
```

### Test Protected Endpoint

```powershell
$body = @{
    token = $token
} | ConvertTo-Json

Invoke-RestMethod -Uri "$apiUrl/auth/verify" `
    -Method POST `
    -Headers @{ Authorization = "Bearer $token" } `
    -Body $body `
    -ContentType "application/json"
```

## Security Features

### Rate Limiting

Prevents brute force attacks:
- Default: 10,000 requests/second
- Burst: 5,000 requests
- Daily quota: 1,000,000 requests

### WAF Protection

AWS WAF with managed rule sets:
- **OWASP Top 10**: Common web vulnerabilities
- **Known Bad Inputs**: Malicious patterns
- **SQL Injection**: SQL injection attempts
- **Rate Limiting**: 2,000 requests per 5 minutes per IP

### JWT Authorization

Protected endpoints require valid JWT token:
- Token format: `Bearer <token>`
- Algorithm: HS256
- Expiry: 1 hour
- Cached for 5 minutes

### CORS

Configurable CORS headers:
- Allowed origin: Configurable (default: *)
- Allowed methods: POST, OPTIONS
- Allowed headers: Content-Type, Authorization

## Monitoring

### CloudWatch Metrics

- **Invocations**: Total API calls
- **4XXError**: Client errors
- **5XXError**: Server errors
- **Latency**: Response time
- **CacheHitCount**: Authorizer cache hits
- **CacheMissCount**: Authorizer cache misses

### CloudWatch Alarms

| Alarm | Threshold | Description |
|-------|-----------|-------------|
| 4XX Errors | 100 in 5 min | High client error rate |
| 5XX Errors | 10 in 5 min | Server errors detected |
| Latency | 1000 ms avg | High response time |

### CloudWatch Logs

- **API Gateway**: `/aws/apigateway/ecommerce-platform-api`
- **Authorizer**: `/aws/lambda/ecommerce-platform-api-authorizer`
- **WAF**: `/aws/waf/ecommerce-platform-api`

### X-Ray Tracing

Enable X-Ray for distributed tracing:
- API Gateway → Lambda
- Lambda → DynamoDB
- Lambda → Secrets Manager

## Cost Estimation

### Assumptions
- 1M API calls/month
- 100K authorizer invocations/month (90% cached)
- WAF enabled
- CloudWatch logs retained for 30 days

### Monthly Costs

| Service | Usage | Cost |
|---------|-------|------|
| API Gateway | 1M requests | $3.50 |
| Lambda (Authorizer) | 100K invocations | $0.20 |
| WAF | 1M requests | $5.00 |
| CloudWatch Logs | 10 GB | $5.00 |
| Data Transfer | 10 GB | $0.90 |
| **Total** | | **~$14.60/month** |

### Cost Optimization

1. **Enable authorizer caching** (5 min TTL) - reduces Lambda invocations by 90%
2. **Reduce log retention** - 7 days instead of 30 days
3. **Disable data trace** - only log errors
4. **Use regional endpoints** - cheaper than edge-optimized

## Troubleshooting

### 401 Unauthorized

**Problem**: Protected endpoint returns 401

**Solutions**:
- Check JWT token is valid and not expired
- Verify Authorization header format: `Bearer <token>`
- Check JWT secret matches between auth service and authorizer
- Review authorizer CloudWatch logs

### 403 Forbidden

**Problem**: Request blocked by WAF

**Solutions**:
- Check WAF logs in CloudWatch
- Review blocked IP addresses
- Adjust WAF rate limits if legitimate traffic
- Whitelist specific IPs if needed

### 429 Too Many Requests

**Problem**: Rate limit exceeded

**Solutions**:
- Increase throttling limits
- Implement exponential backoff in client
- Use API keys for higher limits
- Distribute load across multiple IPs

### CORS Errors

**Problem**: Browser blocks request due to CORS

**Solutions**:
- Verify `cors_allowed_origin` matches frontend URL
- Check OPTIONS method is configured
- Ensure CORS headers are returned
- Test with curl to isolate browser issues

### High Latency

**Problem**: API responses are slow

**Solutions**:
- Check Lambda cold starts (use provisioned concurrency)
- Review DynamoDB performance
- Enable X-Ray to identify bottlenecks
- Optimize Lambda memory allocation

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| api_name | Name of the API Gateway | string | ecommerce-platform-api | no |
| stage_name | API Gateway stage name | string | prod | no |
| auth_lambda_function_name | Auth Lambda function name | string | - | yes |
| auth_lambda_invoke_arn | Auth Lambda invoke ARN | string | - | yes |
| jwt_secret_name | JWT secret name in Secrets Manager | string | ecommerce-jwt-secret | no |
| kms_key_arn | KMS key ARN for encryption | string | - | yes |
| cors_allowed_origin | Allowed origin for CORS | string | * | no |
| throttling_burst_limit | Throttling burst limit | number | 5000 | no |
| throttling_rate_limit | Throttling rate limit (req/sec) | number | 10000 | no |
| quota_limit | Daily quota limit | number | 1000000 | no |
| enable_waf | Enable AWS WAF | bool | true | no |
| waf_rate_limit | WAF rate limit (req/5min) | number | 2000 | no |
| waf_blocked_countries | Blocked country codes | list(string) | [] | no |
| enable_xray_tracing | Enable X-Ray tracing | bool | true | no |
| log_retention_days | Log retention in days | number | 30 | no |
| tags | Tags for all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| api_id | API Gateway REST API ID |
| api_arn | API Gateway REST API ARN |
| api_endpoint | Base URL of the API |
| api_stage_name | API Gateway stage name |
| authorizer_id | JWT authorizer ID |
| authorizer_arn | Authorizer Lambda ARN |
| usage_plan_id | Usage plan ID |
| waf_web_acl_id | WAF Web ACL ID |
| api_endpoints | Map of all API endpoints |

## Integration with Other Modules

### With Auth Lambda

```hcl
module "auth_lambda" {
  source = "./modules/lambda-auth"
  # ... configuration ...
}

module "api_gateway" {
  source = "./modules/api-gateway"

  auth_lambda_function_name = module.auth_lambda.function_name
  auth_lambda_invoke_arn    = module.auth_lambda.invoke_arn
}
```

### With DynamoDB

```hcl
module "dynamodb_users" {
  source = "./modules/dynamodb-users"
  # ... configuration ...
}

# Auth Lambda uses DynamoDB table
# API Gateway → Auth Lambda → DynamoDB
```

### With Frontend

```javascript
// React frontend configuration
const API_BASE_URL = 'https://abc123.execute-api.us-east-1.amazonaws.com/prod';

// Login request
const response = await fetch(`${API_BASE_URL}/auth/login`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password })
});

const { token } = await response.json();

// Protected request
const verifyResponse = await fetch(`${API_BASE_URL}/auth/verify`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({ token })
});
```

## Best Practices

1. **Always enable WAF** in production
2. **Use HTTPS only** - no HTTP endpoints
3. **Implement rate limiting** to prevent abuse
4. **Enable CloudWatch logging** for debugging
5. **Use X-Ray tracing** for performance monitoring
6. **Cache authorizer results** to reduce Lambda costs
7. **Rotate JWT secrets** every 90 days
8. **Monitor 4XX/5XX errors** with alarms
9. **Use API keys** for programmatic access
10. **Implement exponential backoff** in clients

## Next Steps

After deploying API Gateway:

1. ✅ Task 11 complete - API Gateway deployed
2. ➡️ Task 12 - Verify authentication flow end-to-end
3. ➡️ Task 13 - Build React frontend
4. ➡️ Task 16 - Add analytics endpoints

## References

- [API Gateway REST API](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-rest-api.html)
- [Lambda Authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html)
- [AWS WAF](https://docs.aws.amazon.com/waf/latest/developerguide/waf-chapter.html)
- [API Gateway Throttling](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-request-throttling.html)
- [CORS Configuration](https://docs.aws.amazon.com/apigateway/latest/developerguide/how-to-cors.html)
