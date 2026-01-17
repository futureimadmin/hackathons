# MySQL and JWT Configuration Summary

## Overview
This document summarizes the MySQL connection and JWT token configuration for the eCommerce AI Platform.

## MySQL Configuration

### Connection Details
```
Host:     172.20.10.4
Port:     3306
User:     root
Password: Srikar@123
Database: ecommerce
```

### Storage Location
Credentials are stored in AWS Systems Manager Parameter Store (encrypted):

**Development Environment:**
```
/ecommerce-ai-platform/dev/mysql/host     = 172.20.10.4
/ecommerce-ai-platform/dev/mysql/port     = 3306
/ecommerce-ai-platform/dev/mysql/user     = root
/ecommerce-ai-platform/dev/mysql/password = Srikar@123 (SecureString)
/ecommerce-ai-platform/dev/mysql/database = ecommerce
```

**Production Environment:**
```
/ecommerce-ai-platform/prod/mysql/host     = <configured separately>
/ecommerce-ai-platform/prod/mysql/port     = 3306
/ecommerce-ai-platform/prod/mysql/user     = <configured separately>
/ecommerce-ai-platform/prod/mysql/password = <configured separately> (SecureString)
/ecommerce-ai-platform/prod/mysql/database = ecommerce
```

### Network Connectivity

#### Current Setup
- MySQL server is on local network: 172.20.10.4
- This is a private IP address (not accessible from internet)
- AWS services need network connectivity to reach this server

#### Required Setup
To enable AWS DMS and other services to connect to your MySQL server, you need ONE of:

1. **AWS Site-to-Site VPN** (Recommended)
   - Encrypted tunnel between your network and AWS VPC
   - Cost: ~$36/month
   - Setup time: 1-2 hours
   - See: `deployment/mysql-connection-setup.md`

2. **AWS Direct Connect**
   - Dedicated network connection
   - Cost: $300+/month
   - Setup time: 2-4 weeks
   - For enterprise production use

3. **SSH Tunnel** (Development only)
   - Temporary solution for testing
   - Requires SSH server on your network
   - Not suitable for production

### MySQL Server Requirements

Ensure your MySQL server is configured for remote connections:

```sql
-- Check current configuration
SHOW VARIABLES LIKE 'bind_address';

-- Should be 0.0.0.0 or specific IP, not 127.0.0.1
```

Edit MySQL configuration (`my.cnf` or `my.ini`):
```ini
[mysqld]
bind-address = 0.0.0.0
port = 3306

# For DMS CDC (Change Data Capture)
server-id = 1
log_bin = mysql-bin
binlog_format = ROW
binlog_row_image = FULL
```

Restart MySQL after changes.

### Security Recommendations

#### For Development
Current setup is acceptable for development/testing.

#### For Production
1. **Create dedicated DMS user** (don't use root):
```sql
CREATE USER 'dms_user'@'%' IDENTIFIED BY 'SecurePassword123!';
GRANT SELECT, REPLICATION CLIENT, REPLICATION SLAVE ON *.* TO 'dms_user'@'%';
FLUSH PRIVILEGES;
```

2. **Use SSL/TLS** for encrypted connections

3. **Restrict IP ranges** in MySQL firewall:
```sql
-- Only allow AWS VPC CIDR
CREATE USER 'dms_user'@'10.0.0.0/255.255.0.0' IDENTIFIED BY 'SecurePassword123!';
```

4. **Rotate passwords regularly** (every 90 days)

5. **Enable audit logging** to track access

## JWT Configuration

### Token Settings
```java
// In JwtService.java
private static final long TOKEN_EXPIRY_HOURS = 0;  // 0 = NO EXPIRATION
```

### Features
- **Algorithm**: HMAC256 (HS256)
- **Expiration**: NEVER (tokens do not expire)
- **Secret Length**: 64 bytes (512 bits)
- **Secret Generation**: Cryptographically random using RNGCryptoServiceProvider

### Storage Location
JWT secrets are stored in AWS Systems Manager Parameter Store (encrypted):

**Development Environment:**
```
/ecommerce-ai-platform/dev/jwt/secret = <64-byte random string> (SecureString)
```

**Production Environment:**
```
/ecommerce-ai-platform/prod/jwt/secret = <different 64-byte random string> (SecureString)
```

### Token Structure
```json
{
  "sub": "user-id-123",
  "email": "user@example.com",
  "name": "John Doe",
  "iat": 1234567890,
  "iss": "ecommerce-ai-platform"
  // Note: No "exp" (expiration) claim
}
```

### Security Considerations

#### Non-Expiring Tokens
**Advantages:**
- Convenient for development and testing
- No need for token refresh mechanism
- Simpler client-side implementation

**Disadvantages:**
- If token is compromised, it remains valid forever
- No automatic session timeout
- Harder to revoke access

**Recommendations:**
1. **For Development**: Current setup (no expiration) is acceptable
2. **For Production**: Consider adding expiration:
   ```java
   private static final long TOKEN_EXPIRY_HOURS = 24;  // 24 hours
   ```
3. **Implement token refresh**: Allow users to get new tokens without re-login
4. **Token revocation**: Maintain a blacklist of revoked tokens in DynamoDB
5. **Secure storage**: Store tokens in httpOnly cookies or secure storage

### Changing Token Expiration

To add expiration to tokens:

1. Edit `auth-service/src/main/java/com/ecommerce/platform/auth/service/JwtService.java`:
```java
private static final long TOKEN_EXPIRY_HOURS = 24;  // Set to desired hours
```

2. Rebuild the auth service:
```powershell
cd auth-service
mvn clean package
```

3. Redeploy to Lambda:
```powershell
aws lambda update-function-code `
    --function-name ecommerce-ai-platform-dev-auth `
    --zip-file fileb://target/auth-service-1.0.0.jar
```

### Token Verification

Tokens are verified on every API request:

```java
// In JwtService.java
public String verifyToken(String token) {
    JWTVerifier verifier = JWT.require(algorithm)
            .withIssuer(ISSUER)
            .build();
    
    DecodedJWT jwt = verifier.verify(token);
    return jwt.getSubject();  // Returns user ID
}
```

### Best Practices

1. **Never commit secrets to Git**
   - Secrets are in SSM Parameter Store
   - Local backup file is in `.gitignore`

2. **Use different secrets for dev/prod**
   - Dev and prod have separate JWT secrets
   - Prevents token reuse across environments

3. **Rotate secrets periodically**
   - Recommended: Every 90 days
   - Update SSM Parameter Store
   - Redeploy auth service

4. **Monitor token usage**
   - Log token generation and verification
   - Alert on unusual patterns
   - Track failed verification attempts

## Configuration Scripts

### 1. Configure MySQL and JWT
```powershell
cd deployment
.\configure-mysql-connection.ps1
```

This script:
- Generates secure JWT secrets
- Stores MySQL credentials in SSM
- Stores JWT secrets in SSM
- Optionally tests MySQL connection
- Optionally saves secrets to local backup

### 2. Quick Start (All-in-One)
```powershell
cd deployment
.\quick-start.ps1
```

This script:
- Runs MySQL/JWT configuration
- Sets up Terraform backend
- Deploys infrastructure
- Verifies deployment

## Verification

### Check SSM Parameters
```powershell
# List all parameters
aws ssm describe-parameters --query "Parameters[?contains(Name, 'ecommerce-ai-platform')].Name"

# Get specific parameter
aws ssm get-parameter --name "/ecommerce-ai-platform/dev/mysql/host"

# Get encrypted parameter (requires permissions)
aws ssm get-parameter --name "/ecommerce-ai-platform/dev/mysql/password" --with-decryption
```

### Test MySQL Connection
```powershell
# From local machine
mysql -h 172.20.10.4 -u root -p'Srikar@123' -e "SHOW DATABASES;"

# From AWS (after VPN setup)
# SSH into EC2 instance in VPC, then:
mysql -h 172.20.10.4 -u root -p'Srikar@123' -e "SHOW DATABASES;"
```

### Test JWT Token Generation
```powershell
# After deploying auth service
curl -X POST https://api.ecommerce-ai-platform.com/auth/login `
    -H "Content-Type: application/json" `
    -d '{"email":"user@example.com","password":"password123"}'

# Response will include JWT token
```

## Troubleshooting

### MySQL Connection Issues

**Problem**: Can't connect to MySQL from AWS
```
Error: Can't connect to MySQL server on '172.20.10.4'
```

**Solutions**:
1. Check network connectivity (VPN/Direct Connect)
2. Verify MySQL is running: `systemctl status mysql`
3. Check MySQL bind address: `SHOW VARIABLES LIKE 'bind_address';`
4. Check firewall rules: `sudo ufw status`
5. Test from local network first

### JWT Token Issues

**Problem**: Token verification fails
```
Error: Token verification failed
```

**Solutions**:
1. Check JWT_SECRET in SSM matches what auth service is using
2. Verify token format (should be `Bearer <token>`)
3. Check token signature
4. Ensure auth service has permissions to read SSM

**Problem**: Token expired (if expiration is enabled)
```
Error: Token has expired
```

**Solutions**:
1. Request new token via login
2. Implement token refresh mechanism
3. Increase TOKEN_EXPIRY_HOURS if too short

## Additional Resources

- [Infrastructure Deployment Guide](INFRASTRUCTURE_DEPLOYMENT_GUIDE.md)
- [MySQL Connection Setup](mysql-connection-setup.md)
- [CI/CD Pipeline Guide](deployment-pipeline/README.md)
- [Troubleshooting Guide](../docs/TROUBLESHOOTING_GUIDE.md)

## Support

For issues or questions:
1. Check CloudWatch Logs for detailed error messages
2. Review Terraform state: `terraform show`
3. Verify SSM parameters are correctly set
4. Test MySQL connection manually
5. Check AWS service health dashboard
