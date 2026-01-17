# Authentication Flow Verification Guide

Complete guide for verifying the authentication system works end-to-end.

## Overview

This guide provides step-by-step instructions to verify that all authentication components are working correctly:

1. Infrastructure verification
2. API endpoint testing
3. User registration flow
4. Login and JWT generation
5. Token verification (protected endpoints)
6. Password reset flow
7. Monitoring and logging

## Prerequisites

Before running verification:

- ✅ Terraform infrastructure deployed
- ✅ Auth Lambda function built and deployed
- ✅ API Gateway authorizer packaged and deployed
- ✅ DynamoDB users table created
- ✅ JWT secret created in Secrets Manager
- ✅ SES sender email verified
- ✅ AWS CLI configured with appropriate credentials

## Quick Verification

Run the automated verification script:

```powershell
cd terraform/scripts
.\verify-authentication-flow.ps1
```

This script performs 25+ automated tests covering all authentication flows.

### Script Options

```powershell
# Basic usage
.\verify-authentication-flow.ps1

# Specify API URL manually
.\verify-authentication-flow.ps1 -ApiUrl "https://abc123.execute-api.us-east-1.amazonaws.com/prod"

# Skip infrastructure checks (faster)
.\verify-authentication-flow.ps1 -SkipInfrastructureCheck

# Verbose output (shows tokens and detailed info)
.\verify-authentication-flow.ps1 -Verbose

# Specify AWS region
.\verify-authentication-flow.ps1 -Region "us-west-2"
```

## Manual Verification Steps

### Step 1: Verify Infrastructure

#### 1.1 Check DynamoDB Table

```powershell
aws dynamodb describe-table --table-name ecommerce-users --region us-east-1
```

**Expected output:**
- TableStatus: ACTIVE
- BillingModeSummary: PAY_PER_REQUEST
- GlobalSecondaryIndexes: email-index

#### 1.2 Check JWT Secret

```powershell
aws secretsmanager describe-secret --secret-id ecommerce-jwt-secret --region us-east-1
```

**Expected output:**
- Name: ecommerce-jwt-secret
- ARN: arn:aws:secretsmanager:...

#### 1.3 Check Auth Lambda

```powershell
aws lambda get-function --function-name ecommerce-auth-service --region us-east-1
```

**Expected output:**
- Runtime: java17
- Handler: com.ecommerce.platform.auth.AuthHandler::handleRequest
- State: Active

#### 1.4 Check Authorizer Lambda

```powershell
aws lambda get-function --function-name ecommerce-platform-api-authorizer --region us-east-1
```

**Expected output:**
- Runtime: nodejs20.x
- Handler: index.handler
- State: Active

#### 1.5 Check API Gateway

```powershell
aws apigateway get-rest-apis --region us-east-1 --query "items[?name=='ecommerce-platform-api']"
```

**Expected output:**
- name: ecommerce-platform-api
- id: (API ID)
- endpointConfiguration: REGIONAL

#### 1.6 Get API Endpoint URL

```powershell
# From Terraform
terraform output api_endpoint

# Or construct manually
$apiId = "abc123xyz"  # From step 1.5
$region = "us-east-1"
$apiUrl = "https://$apiId.execute-api.$region.amazonaws.com/prod"
Write-Host $apiUrl
```

### Step 2: Test User Registration

#### 2.1 Register New User

```powershell
$apiUrl = "https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod"

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

Write-Host "User ID: $($registerResponse.userId)"
Write-Host "Email: $($registerResponse.email)"
Write-Host "Name: $($registerResponse.name)"
```

**Expected response:**
```json
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "email": "john.doe@example.com",
  "name": "John Doe"
}
```

#### 2.2 Verify User in DynamoDB

```powershell
$userId = $registerResponse.userId

aws dynamodb get-item `
    --table-name ecommerce-users `
    --key "{\"userId\": {\"S\": \"$userId\"}}" `
    --region us-east-1
```

**Expected output:**
- userId: (matches registration)
- email: john.doe@example.com
- passwordHash: (BCrypt hash starting with $2a$)
- createdAt: (timestamp)

#### 2.3 Test Duplicate Registration (Should Fail)

```powershell
# Try to register same email again
try {
    $duplicateResponse = Invoke-RestMethod `
        -Uri "$apiUrl/auth/register" `
        -Method POST `
        -Body $registerBody `
        -ContentType "application/json"
    
    Write-Host "ERROR: Duplicate registration should have failed!" -ForegroundColor Red
} catch {
    Write-Host "✓ Duplicate registration correctly rejected" -ForegroundColor Green
    Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Gray
}
```

**Expected:** 400 Bad Request with error message "Email already registered"

#### 2.4 Test Weak Password (Should Fail)

```powershell
$weakPasswordBody = @{
    email = "weak@example.com"
    password = "weak"
    name = "Weak User"
} | ConvertTo-Json

try {
    $weakResponse = Invoke-RestMethod `
        -Uri "$apiUrl/auth/register" `
        -Method POST `
        -Body $weakPasswordBody `
        -ContentType "application/json"
    
    Write-Host "ERROR: Weak password should have been rejected!" -ForegroundColor Red
} catch {
    Write-Host "✓ Weak password correctly rejected" -ForegroundColor Green
    Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Gray
}
```

**Expected:** 400 Bad Request with error message about password requirements

### Step 3: Test User Login

#### 3.1 Login with Correct Credentials

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

Write-Host "✓ Login successful" -ForegroundColor Green
Write-Host "Token: $($token.Substring(0, 50))..." -ForegroundColor Gray
Write-Host "User ID: $($loginResponse.userId)" -ForegroundColor Gray
Write-Host "Email: $($loginResponse.email)" -ForegroundColor Gray
Write-Host "Name: $($loginResponse.name)" -ForegroundColor Gray
```

**Expected response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "email": "john.doe@example.com",
  "name": "John Doe"
}
```

#### 3.2 Decode JWT Token (Optional)

```powershell
# Extract payload (middle part of JWT)
$parts = $token.Split('.')
$payload = $parts[1]

# Add padding if needed
while ($payload.Length % 4 -ne 0) {
    $payload += "="
}

# Decode from Base64
$decodedBytes = [System.Convert]::FromBase64String($payload)
$decodedJson = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
$claims = $decodedJson | ConvertFrom-Json

Write-Host "Token Claims:" -ForegroundColor Cyan
Write-Host "  User ID: $($claims.userId)" -ForegroundColor Gray
Write-Host "  Email: $($claims.email)" -ForegroundColor Gray
Write-Host "  Name: $($claims.name)" -ForegroundColor Gray
Write-Host "  Issued At: $(Get-Date -UnixTimeSeconds $claims.iat)" -ForegroundColor Gray
Write-Host "  Expires At: $(Get-Date -UnixTimeSeconds $claims.exp)" -ForegroundColor Gray
```

#### 3.3 Test Wrong Password (Should Fail)

```powershell
$wrongPasswordBody = @{
    email = "john.doe@example.com"
    password = "WrongPassword123!"
} | ConvertTo-Json

try {
    $wrongResponse = Invoke-RestMethod `
        -Uri "$apiUrl/auth/login" `
        -Method POST `
        -Body $wrongPasswordBody `
        -ContentType "application/json"
    
    Write-Host "ERROR: Wrong password should have been rejected!" -ForegroundColor Red
} catch {
    Write-Host "✓ Wrong password correctly rejected" -ForegroundColor Green
    Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Gray
}
```

**Expected:** 401 Unauthorized

#### 3.4 Test Non-Existent User (Should Fail)

```powershell
$nonExistentBody = @{
    email = "nonexistent@example.com"
    password = "SecurePass123!"
} | ConvertTo-Json

try {
    $nonExistentResponse = Invoke-RestMethod `
        -Uri "$apiUrl/auth/login" `
        -Method POST `
        -Body $nonExistentBody `
        -ContentType "application/json"
    
    Write-Host "ERROR: Non-existent user should have been rejected!" -ForegroundColor Red
} catch {
    Write-Host "✓ Non-existent user correctly rejected" -ForegroundColor Green
    Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Gray
}
```

**Expected:** 401 Unauthorized

### Step 4: Test Token Verification (Protected Endpoint)

#### 4.1 Verify Valid Token

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

Write-Host "✓ Token verified successfully" -ForegroundColor Green
Write-Host "Valid: $($verifyResponse.valid)" -ForegroundColor Gray
Write-Host "User ID: $($verifyResponse.userId)" -ForegroundColor Gray
Write-Host "Email: $($verifyResponse.email)" -ForegroundColor Gray
```

**Expected response:**
```json
{
  "valid": true,
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "email": "john.doe@example.com"
}
```

#### 4.2 Test Without Authorization Header (Should Fail)

```powershell
try {
    $noAuthResponse = Invoke-RestMethod `
        -Uri "$apiUrl/auth/verify" `
        -Method POST `
        -Body $verifyBody `
        -ContentType "application/json"
    
    Write-Host "ERROR: Request without auth header should have been rejected!" -ForegroundColor Red
} catch {
    Write-Host "✓ Missing Authorization header correctly rejected" -ForegroundColor Green
    Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Gray
}
```

**Expected:** 401 Unauthorized

#### 4.3 Test Invalid Token (Should Fail)

```powershell
$invalidToken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.invalid"

try {
    $invalidResponse = Invoke-RestMethod `
        -Uri "$apiUrl/auth/verify" `
        -Method POST `
        -Headers @{ Authorization = "Bearer $invalidToken" } `
        -Body (@{ token = $invalidToken } | ConvertTo-Json) `
        -ContentType "application/json"
    
    Write-Host "ERROR: Invalid token should have been rejected!" -ForegroundColor Red
} catch {
    Write-Host "✓ Invalid token correctly rejected" -ForegroundColor Green
    Write-Host "Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Gray
}
```

**Expected:** 401 Unauthorized

### Step 5: Test Password Reset Flow

#### 5.1 Request Password Reset

```powershell
$forgotBody = @{
    email = "john.doe@example.com"
} | ConvertTo-Json

$forgotResponse = Invoke-RestMethod `
    -Uri "$apiUrl/auth/forgot-password" `
    -Method POST `
    -Body $forgotBody `
    -ContentType "application/json"

Write-Host "✓ Password reset requested" -ForegroundColor Green
Write-Host "Message: $($forgotResponse.message)" -ForegroundColor Gray
```

**Expected response:**
```json
{
  "message": "If the email exists, a password reset link has been sent"
}
```

#### 5.2 Check Reset Token in DynamoDB

```powershell
Start-Sleep -Seconds 2  # Wait for DynamoDB update

$dbUser = aws dynamodb get-item `
    --table-name ecommerce-users `
    --key "{\"userId\": {\"S\": \"$userId\"}}" `
    --region us-east-1 `
    --output json | ConvertFrom-Json

if ($dbUser.Item.resetToken) {
    Write-Host "✓ Reset token stored in DynamoDB" -ForegroundColor Green
    Write-Host "Reset Token: $($dbUser.Item.resetToken.S.Substring(0, 20))..." -ForegroundColor Gray
    Write-Host "Expires: $(Get-Date -UnixTimeSeconds $dbUser.Item.resetTokenExpiry.N)" -ForegroundColor Gray
} else {
    Write-Host "✗ Reset token not found in DynamoDB" -ForegroundColor Red
}
```

#### 5.3 Check SES Email Sent (Optional)

```powershell
# Check SES sending statistics
aws ses get-send-statistics --region us-east-1
```

**Note:** In SES sandbox mode, emails are only sent to verified addresses.

#### 5.4 Reset Password with Token

```powershell
# Get reset token from DynamoDB
$resetToken = $dbUser.Item.resetToken.S

$resetBody = @{
    token = $resetToken
    newPassword = "NewSecurePass123!"
} | ConvertTo-Json

$resetResponse = Invoke-RestMethod `
    -Uri "$apiUrl/auth/reset-password" `
    -Method POST `
    -Body $resetBody `
    -ContentType "application/json"

Write-Host "✓ Password reset successful" -ForegroundColor Green
Write-Host "Message: $($resetResponse.message)" -ForegroundColor Gray
```

#### 5.5 Login with New Password

```powershell
$newLoginBody = @{
    email = "john.doe@example.com"
    password = "NewSecurePass123!"
} | ConvertTo-Json

$newLoginResponse = Invoke-RestMethod `
    -Uri "$apiUrl/auth/login" `
    -Method POST `
    -Body $newLoginBody `
    -ContentType "application/json"

Write-Host "✓ Login with new password successful" -ForegroundColor Green
Write-Host "New Token: $($newLoginResponse.token.Substring(0, 50))..." -ForegroundColor Gray
```

### Step 6: Verify Monitoring and Logging

#### 6.1 Check API Gateway Logs

```powershell
# Get recent log events
aws logs tail /aws/apigateway/ecommerce-platform-api --since 10m --region us-east-1
```

**Look for:**
- Request IDs
- HTTP methods and paths
- Status codes (200, 400, 401)
- Response times

#### 6.2 Check Auth Lambda Logs

```powershell
aws logs tail /aws/lambda/ecommerce-auth-service --since 10m --region us-east-1
```

**Look for:**
- Function invocations
- Registration/login events
- Password validation
- DynamoDB operations
- Any errors or exceptions

#### 6.3 Check Authorizer Lambda Logs

```powershell
aws logs tail /aws/lambda/ecommerce-platform-api-authorizer --since 10m --region us-east-1
```

**Look for:**
- Token verification attempts
- JWT validation results
- IAM policy generation
- Cache hits/misses

#### 6.4 Check CloudWatch Metrics

```powershell
# API Gateway invocations
aws cloudwatch get-metric-statistics `
    --namespace AWS/ApiGateway `
    --metric-name Count `
    --dimensions Name=ApiName,Value=ecommerce-platform-api `
    --start-time (Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ss") `
    --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") `
    --period 300 `
    --statistics Sum `
    --region us-east-1
```

#### 6.5 Check WAF Metrics

```powershell
# Get WAF Web ACL ID
$wafAcls = aws wafv2 list-web-acls --scope REGIONAL --region us-east-1 --output json | ConvertFrom-Json
$wafAcl = $wafAcls.WebACLs | Where-Object { $_.Name -like "*ecommerce-platform-api*" }

# Get blocked requests
aws cloudwatch get-metric-statistics `
    --namespace AWS/WAFV2 `
    --metric-name BlockedRequests `
    --dimensions Name=WebACL,Value=$($wafAcl.Name) Name=Region,Value=us-east-1 Name=Rule,Value=ALL `
    --start-time (Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ss") `
    --end-time (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") `
    --period 300 `
    --statistics Sum `
    --region us-east-1
```

## Troubleshooting

### Issue 1: Registration Fails with 500 Error

**Symptoms:**
- POST /auth/register returns 500 Internal Server Error
- Auth Lambda logs show errors

**Solutions:**
1. Check Lambda has permissions to write to DynamoDB
2. Verify DynamoDB table exists and is ACTIVE
3. Check Lambda environment variables are set correctly
4. Review Lambda logs for specific error messages

### Issue 2: Login Returns 401 for Valid Credentials

**Symptoms:**
- POST /auth/login returns 401 Unauthorized
- Credentials are correct

**Solutions:**
1. Verify user exists in DynamoDB
2. Check password hash in DynamoDB (should start with $2a$)
3. Ensure BCrypt cost factor matches (12)
4. Review Lambda logs for password verification errors

### Issue 3: Token Verification Fails

**Symptoms:**
- POST /auth/verify returns 401 Unauthorized
- Token appears valid

**Solutions:**
1. Check JWT secret matches in both auth service and authorizer
2. Verify token hasn't expired (1 hour lifetime)
3. Ensure Authorization header format: `Bearer <token>`
4. Review authorizer Lambda logs for verification errors
5. Check authorizer has permission to read from Secrets Manager

### Issue 4: Password Reset Email Not Received

**Symptoms:**
- POST /auth/forgot-password succeeds
- No email received

**Solutions:**
1. Verify sender email is verified in SES
2. Check SES is out of sandbox mode (or recipient is verified)
3. Review SES sending statistics
4. Check Lambda logs for SES errors
5. Verify Lambda has SES:SendEmail permission

### Issue 5: High Latency

**Symptoms:**
- API responses take > 1 second
- CloudWatch alarm triggered

**Solutions:**
1. Check Lambda cold starts (first invocation after idle)
2. Review DynamoDB performance metrics
3. Enable X-Ray tracing to identify bottlenecks
4. Consider provisioned concurrency for Lambda
5. Optimize Lambda memory allocation

## Success Criteria

Authentication flow is verified when:

- ✅ All infrastructure components exist and are active
- ✅ User registration creates user in DynamoDB
- ✅ Duplicate registration is rejected
- ✅ Weak passwords are rejected
- ✅ Login with correct credentials returns JWT token
- ✅ Login with wrong credentials is rejected
- ✅ Protected endpoints require valid JWT token
- ✅ Invalid tokens are rejected
- ✅ Password reset creates reset token in DynamoDB
- ✅ Password can be reset with valid token
- ✅ CloudWatch logs capture all operations
- ✅ CloudWatch metrics show API activity
- ✅ WAF is protecting the API

## Next Steps

After successful verification:

1. ✅ Task 12 complete - Authentication verified
2. ➡️ Task 13 - Build React frontend
3. ➡️ Task 14 - Set up on-premise MySQL database
4. ➡️ Task 16 - Implement analytics service

## References

- [Authentication Infrastructure Overview](./AUTHENTICATION_INFRASTRUCTURE.md)
- [API Gateway Setup Guide](./API_GATEWAY_SETUP.md)
- [Auth Service Deployment](../auth-service/DEPLOYMENT.md)
- [Test API Gateway Script](./scripts/test-api-gateway.ps1)
- [Verify Authentication Flow Script](./scripts/verify-authentication-flow.ps1)
