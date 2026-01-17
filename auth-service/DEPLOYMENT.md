# Authentication Service Deployment Guide

Complete guide for deploying the Java Lambda authentication service.

## Prerequisites

- ✅ Java 17 installed
- ✅ Maven 3.8+ installed
- ✅ AWS CLI configured
- ✅ Terraform deployed (DynamoDB table, Secrets Manager)

## Step 1: Build the Service

```powershell
cd auth-service
.\build.ps1
```

This creates `target/auth-service.jar` (~15-20 MB).

## Step 2: Create JWT Secret in Secrets Manager

```powershell
# Generate a secure random secret
$jwtSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 64 | ForEach-Object {[char]$_})

# Store in Secrets Manager
aws secretsmanager create-secret `
  --name ecommerce-jwt-secret `
  --secret-string $jwtSecret `
  --region us-east-1
```

## Step 3: Deploy Lambda Function

### Using AWS CLI

```powershell
# Create Lambda function
aws lambda create-function `
  --function-name ecommerce-auth-service `
  --runtime java17 `
  --role arn:aws:iam::ACCOUNT_ID:role/lambda-auth-role `
  --handler com.ecommerce.platform.auth.AuthHandler::handleRequest `
  --zip-file fileb://target/auth-service.jar `
  --timeout 30 `
  --memory-size 512 `
  --environment Variables="{DYNAMODB_TABLE_NAME=ecommerce-users,JWT_SECRET_NAME=ecommerce-jwt-secret,SES_FROM_EMAIL=noreply@example.com,FRONTEND_URL=https://platform.example.com}" `
  --region us-east-1
```

### Update Existing Function

```powershell
aws lambda update-function-code `
  --function-name ecommerce-auth-service `
  --zip-file fileb://target/auth-service.jar `
  --region us-east-1
```

## Step 4: Configure IAM Role

The Lambda function needs these permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query"
      ],
      "Resource": [
        "arn:aws:dynamodb:*:*:table/ecommerce-users",
        "arn:aws:dynamodb:*:*:table/ecommerce-users/index/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:*:*:secret:ecommerce-jwt-secret-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## Step 5: Verify SES Email

```powershell
# Verify sender email address
aws ses verify-email-identity `
  --email-address noreply@example.com `
  --region us-east-1

# Check verification status
aws ses get-identity-verification-attributes `
  --identities noreply@example.com `
  --region us-east-1
```

## Step 6: Test the Function

### Test Registration

```powershell
aws lambda invoke `
  --function-name ecommerce-auth-service `
  --payload '{"httpMethod":"POST","path":"/auth/register","body":"{\"email\":\"test@example.com\",\"password\":\"SecurePass123!\",\"name\":\"Test User\"}"}' `
  response.json

cat response.json
```

### Test Login

```powershell
aws lambda invoke `
  --function-name ecommerce-auth-service `
  --payload '{"httpMethod":"POST","path":"/auth/login","body":"{\"email\":\"test@example.com\",\"password\":\"SecurePass123!\"}"}' `
  response.json

cat response.json
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| DYNAMODB_TABLE_NAME | DynamoDB users table | ecommerce-users |
| JWT_SECRET_NAME | Secrets Manager secret name | ecommerce-jwt-secret |
| SES_FROM_EMAIL | Email address for sending | noreply@example.com |
| FRONTEND_URL | Frontend URL for reset links | https://platform.example.com |

## Monitoring

### CloudWatch Logs

Log group: `/aws/lambda/ecommerce-auth-service`

### CloudWatch Metrics

- Invocations
- Errors
- Duration
- Throttles
- Concurrent Executions

### Custom Metrics

Create CloudWatch dashboard to monitor:
- Registration rate
- Login success/failure rate
- Password reset requests
- Average response time

## Troubleshooting

### Cold Start Issues

**Problem:** First invocation takes 2-3 seconds

**Solutions:**
- Use provisioned concurrency (costs more)
- Optimize JAR size
- Use SnapStart (Java 11+)

### DynamoDB Access Denied

**Problem:** Lambda can't access DynamoDB

**Solutions:**
- Check IAM role has DynamoDB permissions
- Verify table name in environment variable
- Check table exists in same region

### JWT Secret Not Found

**Problem:** Can't retrieve JWT secret

**Solutions:**
- Verify secret exists in Secrets Manager
- Check IAM role has secretsmanager:GetSecretValue
- Verify secret name matches environment variable

### Email Not Sending

**Problem:** SES emails not being sent

**Solutions:**
- Verify sender email in SES
- Check SES is out of sandbox mode
- Verify IAM role has SES permissions
- Check CloudWatch Logs for errors

## Performance Optimization

### Memory Configuration

Test different memory settings:
- 256 MB: Slow, may timeout
- 512 MB: Recommended for production
- 1024 MB: Faster but more expensive

### Timeout Configuration

- Recommended: 30 seconds
- Minimum: 15 seconds
- Maximum: 60 seconds

### Provisioned Concurrency

For consistent performance:
```powershell
aws lambda put-provisioned-concurrency-config `
  --function-name ecommerce-auth-service `
  --provisioned-concurrent-executions 2 `
  --qualifier $LATEST
```

## Cost Optimization

### Estimated Costs

**Assumptions:**
- 100K users
- 1M logins/month
- 10K registrations/month
- 5K password resets/month

**Lambda:**
- Requests: 1.015M * $0.20/1M = $0.20
- Duration: 1.015M * 100ms * $0.0000166667/GB-sec = $8.45
- **Total: ~$8.65/month**

**DynamoDB:**
- See DynamoDB module README

**Secrets Manager:**
- 1 secret * $0.40 = $0.40/month

**SES:**
- 15K emails * $0.10/1000 = $1.50/month

**Total: ~$11/month**

## Security Best Practices

1. **Rotate JWT Secret** every 90 days
2. **Enable CloudTrail** for audit logging
3. **Use VPC** for Lambda (optional)
4. **Enable X-Ray** for tracing
5. **Implement rate limiting** at API Gateway
6. **Monitor failed login attempts**
7. **Use AWS WAF** for DDoS protection

## Next Steps

After deploying authentication service:

1. ✅ Task 10 complete - Authentication service deployed
2. ➡️ Task 11 - Set up API Gateway
3. ➡️ Task 12 - Verify authentication flow
4. ➡️ Task 13 - Build React frontend

## References

- [AWS Lambda Java](https://docs.aws.amazon.com/lambda/latest/dg/lambda-java.html)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [AWS SES](https://docs.aws.amazon.com/ses/)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
