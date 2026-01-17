# Infrastructure Deployment Guide

## Overview
This guide walks you through deploying the complete eCommerce AI Platform infrastructure to AWS using Terraform.

## Prerequisites

### Required Tools
- AWS CLI (configured with credentials)
- Terraform >= 1.0
- PowerShell 7+ (for Windows)
- MySQL client (optional, for testing)

### AWS Account Requirements
- AWS Account with appropriate permissions
- IAM user with AdministratorAccess or equivalent
- AWS CLI configured: `aws configure`

## Configuration Summary

### MySQL Connection
- **Host**: 172.20.10.4
- **Port**: 3306
- **User**: root
- **Password**: Srikar@123
- **Database**: ecommerce

### JWT Configuration
- **Expiration**: NO EXPIRATION (tokens never expire)
- **Algorithm**: HMAC256
- **Secret**: Auto-generated 64-byte cryptographically random string

## Step-by-Step Deployment

### Step 1: Configure MySQL Connection and JWT Secrets

Run the configuration script to store credentials in AWS SSM Parameter Store:

```powershell
cd deployment
.\configure-mysql-connection.ps1
```

This script will:
1. Generate secure JWT secrets for dev and prod
2. Store MySQL connection details in SSM Parameter Store
3. Store JWT secrets in SSM Parameter Store (encrypted)
4. Optionally test the MySQL connection
5. Optionally save JWT secrets to a local backup file

**Parameters stored:**
```
/ecommerce-ai-platform/dev/mysql/host = 172.20.10.4
/ecommerce-ai-platform/dev/mysql/port = 3306
/ecommerce-ai-platform/dev/mysql/user = root
/ecommerce-ai-platform/dev/mysql/password = Srikar@123 (encrypted)
/ecommerce-ai-platform/dev/mysql/database = ecommerce
/ecommerce-ai-platform/dev/jwt/secret = <generated> (encrypted)

/ecommerce-ai-platform/prod/mysql/* = <your prod values>
/ecommerce-ai-platform/prod/jwt/secret = <generated> (encrypted)
```

### Step 2: Setup Terraform Backend

Run the Terraform setup script:

```powershell
cd terraform
.\setup-terraform.ps1
```

This script will:
1. Create S3 bucket for Terraform state
2. Enable versioning and encryption on the bucket
3. Create DynamoDB table for state locking
4. Initialize Terraform with the backend configuration
5. Validate the Terraform configuration

### Step 3: Review Terraform Plan

Review what infrastructure will be created:

```powershell
cd terraform
terraform plan
```

This will show you:
- VPC and networking resources
- S3 data lake buckets (5 systems × 3 zones = 15 buckets)
- IAM roles and policies
- KMS encryption keys
- DMS replication infrastructure (if configured)
- Lambda functions for AI systems
- API Gateway
- DynamoDB tables
- Glue crawlers and Athena databases
- CloudWatch monitoring

### Step 4: Deploy Infrastructure

Deploy the infrastructure:

```powershell
terraform apply
```

Type `yes` when prompted to confirm.

**Deployment time**: Approximately 15-20 minutes

### Step 5: Verify Deployment

After deployment completes, verify the infrastructure:

```powershell
# Check S3 buckets
aws s3 ls | Select-String "ecommerce-ai-platform"

# Check SSM parameters
aws ssm get-parameter --name "/ecommerce-ai-platform/dev/mysql/host"

# Check Lambda functions
aws lambda list-functions --query "Functions[?contains(FunctionName, 'ecommerce')].FunctionName"

# Get outputs
terraform output
```

## Network Connectivity Setup

### Important: MySQL Access from AWS

Your MySQL server (172.20.10.4) is on a private network. For AWS DMS to replicate data, you need network connectivity:

### Option 1: AWS Site-to-Site VPN (Recommended)

1. **Create Customer Gateway**:
```powershell
aws ec2 create-customer-gateway `
    --type ipsec.1 `
    --public-ip <YOUR_PUBLIC_IP> `
    --bgp-asn 65000
```

2. **Create Virtual Private Gateway**:
```powershell
$vpcId = terraform output -raw vpc_id
aws ec2 create-vpn-gateway --type ipsec.1
aws ec2 attach-vpn-gateway --vpn-gateway-id <VGW_ID> --vpc-id $vpcId
```

3. **Create VPN Connection**:
```powershell
aws ec2 create-vpn-connection `
    --type ipsec.1 `
    --customer-gateway-id <CGW_ID> `
    --vpn-gateway-id <VGW_ID>
```

4. **Configure your local router** with the VPN configuration downloaded from AWS

5. **Update route tables** to route 172.20.10.4 traffic through the VPN

### Option 2: Development/Testing (SSH Tunnel)

For development, you can use an SSH tunnel:

```powershell
# From an EC2 instance in your VPC
ssh -L 3306:172.20.10.4:3306 user@your-local-gateway
```

### Option 3: Public IP (Not Recommended)

If you must use a public IP:
1. Expose MySQL on a public IP
2. Configure MySQL to accept remote connections
3. Add AWS IP ranges to firewall
4. Use SSL/TLS encryption

## JWT Token Configuration

### Non-Expiring Tokens

The JWT service is configured to generate tokens that **never expire**:

```java
private static final long TOKEN_EXPIRY_HOURS = 0;  // 0 = no expiration
```

**Security Considerations:**
- Non-expiring tokens are convenient for development
- For production, consider setting a reasonable expiration (e.g., 24 hours)
- Implement token refresh mechanism for better security
- Store tokens securely on the client side

**To change expiration** (if needed later):
1. Edit `auth-service/src/main/java/com/ecommerce/platform/auth/service/JwtService.java`
2. Change `TOKEN_EXPIRY_HOURS` to desired value (e.g., 24 for 24 hours)
3. Rebuild and redeploy the auth service

## Post-Deployment Steps

### 1. Setup Database Schema

Run the database setup script:

```powershell
cd database
.\setup-database.ps1 -Environment dev
```

This will:
- Create the ecommerce database schema
- Create tables for all 5 AI systems
- Generate sample data for testing

### 2. Configure DMS Replication

If using DMS for data replication:

```powershell
cd terraform
terraform apply -target=module.dms
```

### 3. Deploy Lambda Functions

Build and deploy the Lambda functions:

```powershell
# Auth Service
cd auth-service
mvn clean package
aws lambda update-function-code --function-name ecommerce-ai-platform-dev-auth --zip-file fileb://target/auth-service-1.0.0.jar

# Analytics Service
cd analytics-service
.\build.ps1

# AI Systems
cd ai-systems/market-intelligence-hub
.\build.ps1
# Repeat for other AI systems
```

### 4. Deploy Frontend

Build and deploy the frontend:

```powershell
cd frontend
npm install
npm run build

# Upload to S3
aws s3 sync dist/ s3://ecommerce-ai-platform-frontend-dev/
```

### 5. Test the System

Run integration tests:

```powershell
cd tests/integration
.\run_integration_tests.ps1
```

## Environment Variables

The following environment variables are automatically configured from SSM Parameter Store:

### For Lambda Functions
- `MYSQL_HOST` - MySQL server hostname
- `MYSQL_PORT` - MySQL server port
- `MYSQL_USER` - MySQL username
- `MYSQL_PASSWORD` - MySQL password (encrypted)
- `MYSQL_DATABASE` - Database name
- `JWT_SECRET` - JWT signing secret (encrypted)

### For DMS
- Source endpoint configured with MySQL credentials
- Target endpoints configured for S3 buckets

## Monitoring and Logging

### CloudWatch Logs
All services log to CloudWatch:
- `/aws/lambda/ecommerce-ai-platform-dev-*` - Lambda function logs
- `/aws/dms/ecommerce-ai-platform-dev` - DMS replication logs
- `/aws/batch/ecommerce-ai-platform-dev` - Batch job logs

### CloudWatch Metrics
Key metrics to monitor:
- Lambda invocations and errors
- DMS replication lag
- S3 bucket sizes
- API Gateway requests

### Alarms
Configure CloudWatch alarms for:
- Lambda errors > threshold
- DMS replication failures
- High API Gateway latency

## Cost Estimation

### Monthly Costs (Development Environment)

| Service | Estimated Cost |
|---------|---------------|
| VPC (NAT Gateway) | $32/month |
| S3 Storage (100GB) | $2.30/month |
| Lambda (1M requests) | $0.20/month |
| DMS (c5.xlarge) | $0.255/hour = ~$184/month |
| RDS (if used) | $50-200/month |
| CloudWatch Logs | $5-10/month |
| Data Transfer | $10-20/month |
| **Total** | **~$280-450/month** |

### Cost Optimization Tips
1. Stop DMS replication instance when not in use
2. Use S3 Intelligent-Tiering for data lake
3. Set CloudWatch log retention to 7-14 days
4. Use Lambda reserved concurrency
5. Enable S3 lifecycle policies

## Troubleshooting

### Common Issues

#### 1. Terraform Backend Error
```
Error: Failed to get existing workspaces
```
**Solution**: Run `.\setup-terraform.ps1` to create backend resources

#### 2. MySQL Connection Failed
```
Error: Can't connect to MySQL server on '172.20.10.4'
```
**Solution**: 
- Check network connectivity (VPN/Direct Connect)
- Verify MySQL is running and accepting remote connections
- Check security groups and firewall rules

#### 3. JWT Token Invalid
```
Error: Token verification failed
```
**Solution**:
- Verify JWT_SECRET is correctly stored in SSM
- Check token format and signature
- Ensure auth service is using the correct secret

#### 4. S3 Access Denied
```
Error: Access Denied when accessing S3 bucket
```
**Solution**:
- Check IAM role permissions
- Verify KMS key permissions
- Check bucket policies

### Getting Help

1. Check CloudWatch Logs for detailed error messages
2. Review Terraform state: `terraform show`
3. Validate configuration: `terraform validate`
4. Check AWS service health dashboard
5. Review documentation in `docs/` folder

## Cleanup

To destroy all infrastructure:

```powershell
cd terraform
terraform destroy
```

**Warning**: This will delete all resources including data in S3 buckets!

To preserve data:
1. Backup S3 buckets before destroying
2. Export DynamoDB tables
3. Save CloudWatch logs

## Next Steps

1. ✅ Configure MySQL connection
2. ✅ Setup Terraform backend
3. ✅ Deploy infrastructure
4. ⏭️ Setup CI/CD pipeline (see `deployment/deployment-pipeline/README.md`)
5. ⏭️ Configure monitoring and alerts
6. ⏭️ Setup production environment
7. ⏭️ Implement backup and disaster recovery

## Additional Resources

- [MySQL Connection Setup](mysql-connection-setup.md)
- [CI/CD Pipeline Guide](deployment-pipeline/README.md)
- [Terraform Documentation](../terraform/README.md)
- [API Gateway Setup](../terraform/API_GATEWAY_SETUP.md)
- [Monitoring Guide](../MONITORING_SETUP_GUIDE.md)
- [Troubleshooting Guide](../docs/TROUBLESHOOTING_GUIDE.md)
