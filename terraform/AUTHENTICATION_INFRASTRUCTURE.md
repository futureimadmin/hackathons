# Authentication Infrastructure Overview

Complete reference for the authentication system architecture.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Frontend (React)                        │
│                    https://platform.example.com                 │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ HTTPS
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                          AWS WAF                                │
│  • Rate limiting (2000 req/5min per IP)                        │
│  • OWASP Top 10 protection                                     │
│  • SQL injection prevention                                    │
│  • Known bad inputs blocking                                   │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    API Gateway REST API                         │
│                                                                 │
│  Public Endpoints:                                             │
│  • POST /auth/register                                         │
│  • POST /auth/login                                            │
│  • POST /auth/forgot-password                                  │
│  • POST /auth/reset-password                                   │
│                                                                 │
│  Protected Endpoints:                                          │
│  • POST /auth/verify (requires JWT)                            │
│                                                                 │
│  Features:                                                     │
│  • CORS enabled                                                │
│  • Throttling: 10K req/sec, 5K burst                          │
│  • CloudWatch logging                                          │
│  • X-Ray tracing                                               │
└────────┬────────────────────────────────┬─────────────────────┘
         │                                │
         │ Lambda Proxy                   │ TOKEN auth
         │ Integration                    │
         ▼                                ▼
┌──────────────────────┐      ┌──────────────────────────┐
│   Auth Lambda        │      │   JWT Authorizer         │
│   (Java 17)          │      │   (Node.js 20)           │
│                      │      │                          │
│  • Registration      │      │  • Verify JWT token      │
│  • Login             │      │  • Generate IAM policy   │
│  • Password reset    │      │  • Cache results (5min)  │
│  • JWT generation    │      │                          │
│  • BCrypt hashing    │      └──────────┬───────────────┘
│                      │                 │
└──────┬───────────────┘                 │
       │                                 │
       │ Read/Write                      │ Read
       ▼                                 ▼
┌──────────────────────┐      ┌──────────────────────────┐
│   DynamoDB           │      │   Secrets Manager        │
│   ecommerce-users    │      │   ecommerce-jwt-secret   │
│                      │      │                          │
│  • userId (PK)       │      │  • JWT signing key       │
│  • email (GSI)       │      │  • Auto-rotation (90d)   │
│  • passwordHash      │      │                          │
│  • name              │      └──────────────────────────┘
│  • createdAt         │
│  • resetToken        │
│  • resetTokenExpiry  │
│                      │
└──────────────────────┘
       │
       │ Send email
       ▼
┌──────────────────────┐
│   AWS SES            │
│                      │
│  • Password reset    │
│  • Welcome emails    │
│  • Verified sender   │
│                      │
└──────────────────────┘
```

## Components

### 1. API Gateway REST API
- **Name**: ecommerce-platform-api
- **Stage**: prod
- **Endpoint**: https://{api-id}.execute-api.{region}.amazonaws.com/prod
- **Features**: CORS, throttling, logging, X-Ray tracing

### 2. Auth Lambda Function
- **Name**: ecommerce-auth-service
- **Runtime**: Java 17
- **Memory**: 512 MB
- **Timeout**: 30 seconds
- **Handler**: com.ecommerce.platform.auth.AuthHandler::handleRequest

### 3. JWT Authorizer Lambda
- **Name**: ecommerce-platform-api-authorizer
- **Runtime**: Node.js 20
- **Memory**: 256 MB
- **Timeout**: 10 seconds
- **Cache TTL**: 5 minutes

### 4. DynamoDB Table
- **Name**: ecommerce-users
- **Billing**: PAY_PER_REQUEST (on-demand)
- **Encryption**: AWS KMS
- **Backup**: Point-in-time recovery enabled
- **GSI**: email-index (for login lookup)

### 5. AWS WAF
- **Name**: ecommerce-platform-api-waf
- **Scope**: REGIONAL
- **Rules**: 
  - Rate limiting (2000 req/5min per IP)
  - AWS Managed Rules - Common Rule Set
  - AWS Managed Rules - Known Bad Inputs
  - AWS Managed Rules - SQL Injection

### 6. Secrets Manager
- **Secret**: ecommerce-jwt-secret
- **Type**: String
- **Rotation**: 90 days
- **Encryption**: AWS KMS

### 7. AWS SES
- **Sender**: noreply@example.com
- **Status**: Verified
- **Templates**: Password reset, welcome email

## Authentication Flow

### Registration Flow

```
1. User submits email, password, name
   ↓
2. Frontend → POST /auth/register
   ↓
3. API Gateway → Auth Lambda
   ↓
4. Auth Lambda validates:
   - Email format
   - Password strength (8+ chars, uppercase, lowercase, number, special)
   - Email uniqueness
   ↓
5. Auth Lambda:
   - Hashes password (BCrypt, cost 12)
   - Generates userId (UUID)
   - Stores in DynamoDB
   ↓
6. Auth Lambda → Response
   {
     "userId": "uuid",
     "email": "user@example.com",
     "name": "User Name"
   }
   ↓
7. Frontend receives response
```

### Login Flow

```
1. User submits email, password
   ↓
2. Frontend → POST /auth/login
   ↓
3. API Gateway → Auth Lambda
   ↓
4. Auth Lambda:
   - Queries DynamoDB by email (GSI)
   - Verifies password (BCrypt compare)
   ↓
5. Auth Lambda:
   - Retrieves JWT secret from Secrets Manager
   - Generates JWT token (HS256, 1 hour expiry)
   - Includes claims: userId, email, name
   ↓
6. Auth Lambda → Response
   {
     "token": "eyJhbGciOiJIUzI1NiIs...",
     "userId": "uuid",
     "email": "user@example.com",
     "name": "User Name"
   }
   ↓
7. Frontend stores token in localStorage
```

### Protected Request Flow

```
1. Frontend includes token in header:
   Authorization: Bearer <token>
   ↓
2. Frontend → POST /auth/verify
   ↓
3. API Gateway → JWT Authorizer
   ↓
4. JWT Authorizer:
   - Extracts token from header
   - Retrieves JWT secret from Secrets Manager
   - Verifies token signature
   - Checks expiration
   ↓
5. JWT Authorizer → IAM Policy
   {
     "principalId": "userId",
     "policyDocument": {
       "Statement": [{
         "Action": "execute-api:Invoke",
         "Effect": "Allow",
         "Resource": "arn:aws:execute-api:..."
       }]
     },
     "context": {
       "userId": "uuid",
       "email": "user@example.com"
     }
   }
   ↓
6. API Gateway → Auth Lambda (with context)
   ↓
7. Auth Lambda → Response
   {
     "valid": true,
     "userId": "uuid",
     "email": "user@example.com"
   }
```

### Password Reset Flow

```
1. User submits email
   ↓
2. Frontend → POST /auth/forgot-password
   ↓
3. API Gateway → Auth Lambda
   ↓
4. Auth Lambda:
   - Queries DynamoDB by email
   - Generates reset token (UUID)
   - Sets expiry (1 hour)
   - Updates DynamoDB
   ↓
5. Auth Lambda → AWS SES
   - Sends email with reset link
   - Link: https://platform.example.com/reset?token=<token>
   ↓
6. User clicks link
   ↓
7. Frontend → POST /auth/reset-password
   {
     "token": "reset-token",
     "newPassword": "NewSecurePass123!"
   }
   ↓
8. Auth Lambda:
   - Verifies token exists and not expired
   - Validates new password strength
   - Hashes new password
   - Updates DynamoDB
   - Clears reset token
   ↓
9. User can login with new password
```

## Security Features

### Password Security
- **Minimum length**: 8 characters
- **Required**: Uppercase, lowercase, number, special character
- **Hashing**: BCrypt with cost factor 12
- **Storage**: Only hash stored, never plaintext

### JWT Security
- **Algorithm**: HS256 (HMAC with SHA-256)
- **Expiry**: 1 hour
- **Secret**: Stored in Secrets Manager
- **Rotation**: 90 days
- **Claims**: userId, email, name, iat, exp

### API Security
- **WAF**: OWASP Top 10 protection
- **Rate limiting**: 2000 requests per 5 minutes per IP
- **Throttling**: 10,000 requests/second, 5,000 burst
- **CORS**: Configurable allowed origins
- **Encryption**: TLS 1.2+ in transit, KMS at rest

### DynamoDB Security
- **Encryption**: AWS KMS at rest
- **Backup**: Point-in-time recovery
- **Access**: IAM roles with least privilege
- **Audit**: CloudTrail logging

## Monitoring

### CloudWatch Metrics

**API Gateway:**
- Count (total requests)
- 4XXError (client errors)
- 5XXError (server errors)
- Latency (response time)
- CacheHitCount (authorizer cache)

**Lambda:**
- Invocations
- Errors
- Duration
- Throttles
- ConcurrentExecutions

**DynamoDB:**
- ConsumedReadCapacityUnits
- ConsumedWriteCapacityUnits
- UserErrors (throttling)

**WAF:**
- AllowedRequests
- BlockedRequests
- CountedRequests

### CloudWatch Alarms

| Alarm | Threshold | Action |
|-------|-----------|--------|
| API 4XX Errors | > 100 in 5 min | Alert |
| API 5XX Errors | > 10 in 5 min | Alert |
| API Latency | > 1000 ms avg | Alert |
| Lambda Errors | > 5 in 5 min | Alert |
| DynamoDB Throttles | > 10 in 5 min | Alert |

### CloudWatch Logs

- `/aws/apigateway/ecommerce-platform-api` - API Gateway logs
- `/aws/lambda/ecommerce-auth-service` - Auth Lambda logs
- `/aws/lambda/ecommerce-platform-api-authorizer` - Authorizer logs
- `/aws/waf/ecommerce-platform-api` - WAF logs

## Cost Breakdown

### Monthly Costs (1M requests)

| Service | Usage | Cost |
|---------|-------|------|
| API Gateway | 1M requests | $3.50 |
| Auth Lambda | 1M invocations, 100ms avg | $8.45 |
| Authorizer Lambda | 100K invocations (90% cached) | $0.20 |
| DynamoDB | 1M reads, 100K writes | $1.50 |
| Secrets Manager | 1 secret | $0.40 |
| SES | 15K emails | $1.50 |
| WAF | 1M requests | $5.00 |
| CloudWatch Logs | 10 GB | $5.00 |
| Data Transfer | 10 GB | $0.90 |
| **Total** | | **~$26.45/month** |

## Deployment Checklist

- [ ] Package auth Lambda JAR
- [ ] Package authorizer Lambda ZIP
- [ ] Create JWT secret in Secrets Manager
- [ ] Verify SES sender email
- [ ] Deploy Terraform modules
- [ ] Test registration endpoint
- [ ] Test login endpoint
- [ ] Test protected endpoint
- [ ] Test password reset flow
- [ ] Configure CloudWatch alarms
- [ ] Set up SNS notifications
- [ ] Review WAF logs
- [ ] Update frontend with API URL

## Testing

### Manual Testing

```powershell
# Run comprehensive test suite
cd terraform/scripts
.\test-api-gateway.ps1
```

### Integration Testing

```powershell
# Test complete authentication flow
cd terraform/scripts
.\verify-authentication-flow.ps1
```

### Load Testing

```powershell
# Test with 1000 concurrent users
cd terraform/scripts
.\load-test-api.ps1 -ConcurrentUsers 1000
```

## Troubleshooting

### Common Issues

1. **401 Unauthorized on protected endpoints**
   - Check JWT token is valid and not expired
   - Verify Authorization header format: `Bearer <token>`
   - Check JWT secret matches in both services

2. **CORS errors in browser**
   - Verify `cors_allowed_origin` matches frontend URL
   - Check OPTIONS method returns correct headers
   - Test with curl to isolate browser issues

3. **Rate limit exceeded (429)**
   - Check WAF rate limits
   - Increase throttling limits if legitimate traffic
   - Implement exponential backoff in client

4. **High latency**
   - Check Lambda cold starts
   - Review DynamoDB performance
   - Enable X-Ray tracing to identify bottlenecks

## Next Steps

1. ✅ Task 11 complete - API Gateway deployed
2. ➡️ Task 12 - Verify authentication flow end-to-end
3. ➡️ Task 13 - Build React frontend with auth integration
4. ➡️ Task 16 - Add analytics endpoints to API Gateway

## References

- [API Gateway Module README](./modules/api-gateway/README.md)
- [API Gateway Setup Guide](./API_GATEWAY_SETUP.md)
- [Auth Service Deployment](../auth-service/DEPLOYMENT.md)
- [DynamoDB Module README](./modules/dynamodb-users/README.md)
