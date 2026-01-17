# Authentication Service - Java Lambda

Java-based AWS Lambda authentication service for the eCommerce AI Analytics Platform.

## Features

- User registration with email validation and password strength requirements
- User login with JWT token generation
- Password reset via email
- JWT token verification
- Secure password hashing with BCrypt
- DynamoDB for user storage
- AWS Secrets Manager for JWT secret
- AWS SES for email notifications

## Project Structure

```
auth-service/
├── pom.xml                          # Maven configuration
├── src/
│   ├── main/
│   │   ├── java/com/ecommerce/platform/auth/
│   │   │   ├── AuthHandler.java     # Main Lambda handler
│   │   │   ├── model/               # Request/Response models
│   │   │   │   ├── User.java
│   │   │   │   ├── RegisterRequest.java
│   │   │   │   ├── LoginRequest.java
│   │   │   │   ├── ForgotPasswordRequest.java
│   │   │   │   ├── ResetPasswordRequest.java
│   │   │   │   └── VerifyTokenRequest.java
│   │   │   ├── service/             # Business logic services
│   │   │   │   ├── UserService.java
│   │   │   │   ├── JwtService.java
│   │   │   │   ├── PasswordService.java
│   │   │   │   └── EmailService.java
│   │   │   └── util/                # Utility classes
│   │   │       └── ResponseBuilder.java
│   │   └── resources/
│   │       └── log4j2.xml           # Logging configuration
│   └── test/
│       └── java/com/ecommerce/platform/auth/
│           └── ...                  # Unit tests
├── build.ps1                        # Build script
└── README.md                        # This file
```

## Prerequisites

- Java 17 or higher
- Maven 3.8 or higher
- AWS CLI configured
- DynamoDB table created
- Secrets Manager secret for JWT

## Building

### Using Maven

```bash
mvn clean package
```

This creates `target/auth-service.jar` - a fat JAR with all dependencies.

### Using PowerShell Script

```powershell
.\build.ps1
```

## API Endpoints

### POST /auth/register

Register a new user.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "name": "John Doe"
}
```

**Response (200):**
```json
{
  "userId": "uuid",
  "message": "Registration successful"
}
```

### POST /auth/login

Login and receive JWT token.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```

**Response (200):**
```json
{
  "token": "jwt-token",
  "userId": "uuid",
  "name": "John Doe",
  "expiresIn": 3600
}
```

### POST /auth/forgot-password

Request password reset email.

**Request:**
```json
{
  "email": "user@example.com"
}
```

**Response (200):**
```json
{
  "message": "Password reset email sent"
}
```

### POST /auth/reset-password

Reset password with token.

**Request:**
```json
{
  "token": "reset-token",
  "newPassword": "NewSecurePass123!"
}
```

**Response (200):**
```json
{
  "message": "Password reset successful"
}
```

### POST /auth/verify

Verify JWT token.

**Request:**
```json
{
  "token": "jwt-token"
}
```

**Response (200):**
```json
{
  "valid": true,
  "userId": "uuid",
  "email": "user@example.com",
  "name": "John Doe"
}
```

## Environment Variables

The Lambda function requires these environment variables:

- `DYNAMODB_TABLE_NAME` - Name of the DynamoDB users table
- `JWT_SECRET_NAME` - Name of the Secrets Manager secret containing JWT secret
- `SES_FROM_EMAIL` - Email address for sending password reset emails
- `AWS_REGION` - AWS region (automatically set by Lambda)

## DynamoDB Table Schema

Table name: `ecommerce-users`

**Primary Key:**
- `userId` (String) - Partition key

**Attributes:**
- `email` (String) - User email (GSI)
- `passwordHash` (String) - BCrypt hashed password
- `name` (String) - User's full name
- `resetToken` (String) - Password reset token (optional)
- `createdAt` (String) - ISO 8601 timestamp
- `updatedAt` (String) - ISO 8601 timestamp

**Global Secondary Index:**
- `email-index` - For querying users by email
  - Partition key: `email`

## Password Requirements

Passwords must meet these criteria:
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character

## JWT Token Structure

```json
{
  "sub": "user-uuid",
  "email": "user@example.com",
  "name": "John Doe",
  "iat": 1705392000,
  "exp": 1705395600,
  "iss": "ecommerce-ai-platform"
}
```

- **Expiration**: 1 hour (3600 seconds)
- **Algorithm**: HMAC256
- **Secret**: Stored in AWS Secrets Manager

## Testing

Run unit tests:

```bash
mvn test
```

Run integration tests:

```bash
mvn verify
```

## Deployment

### Using AWS CLI

```bash
aws lambda update-function-code \
  --function-name ecommerce-auth-service \
  --zip-file fileb://target/auth-service.jar \
  --region us-east-1
```

### Using Terraform

The Lambda function is deployed via Terraform (see `terraform/modules/lambda-auth/`).

## Security Considerations

1. **Password Hashing**: BCrypt with cost factor 12
2. **JWT Secret**: Stored in AWS Secrets Manager, never in code
3. **Rate Limiting**: Implemented at API Gateway level
4. **CORS**: Configured for frontend domain only in production
5. **Input Validation**: All inputs validated before processing
6. **SQL Injection**: Not applicable (using DynamoDB)
7. **Logging**: Sensitive data (passwords, tokens) never logged

## Monitoring

### CloudWatch Metrics

- Invocations
- Errors
- Duration
- Throttles

### CloudWatch Logs

Log group: `/aws/lambda/ecommerce-auth-service`

### Custom Metrics

- Registration count
- Login success/failure rate
- Password reset requests

## Troubleshooting

### "Invalid credentials" on login

- Verify email exists in DynamoDB
- Check password is correct
- Verify BCrypt hash matches

### "User already exists" on registration

- Email is already registered
- Check DynamoDB for existing user

### JWT token verification fails

- Token may be expired (1 hour lifetime)
- JWT secret may have changed
- Token may be malformed

### Email not sending

- Verify SES is configured
- Check SES_FROM_EMAIL is verified in SES
- Check IAM role has SES permissions
- Review CloudWatch Logs for errors

## Performance

- **Cold start**: ~2-3 seconds (Java 17 + fat JAR)
- **Warm invocation**: ~50-100ms
- **Memory**: 512 MB recommended
- **Timeout**: 30 seconds

## Cost Optimization

- Use provisioned concurrency for consistent performance
- Optimize JAR size by excluding unused dependencies
- Use ARM64 architecture for 20% cost savings
- Set appropriate memory allocation (512 MB)

## References

- [AWS Lambda Java](https://docs.aws.amazon.com/lambda/latest/dg/lambda-java.html)
- [DynamoDB SDK](https://docs.aws.amazon.com/sdk-for-java/latest/developer-guide/examples-dynamodb.html)
- [JWT Library](https://github.com/auth0/java-jwt)
- [BCrypt](https://github.com/patrickfav/bcrypt)
