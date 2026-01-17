# Deployment Documentation

## Overview
This directory contains all deployment-related scripts, configurations, and documentation for the eCommerce AI Platform.

## Quick Start

### Option 1: Automated Deployment (Recommended)
Run the quick start script to deploy everything automatically:

```powershell
.\quick-start.ps1
```

This will:
1. Configure MySQL connection (172.20.10.4:3306)
2. Generate and store JWT secrets (non-expiring tokens)
3. Setup Terraform backend (S3 + DynamoDB)
4. Deploy infrastructure to AWS
5. Verify deployment

**Time**: ~20-30 minutes

### Option 2: Step-by-Step Deployment
For more control, run each step manually:

```powershell
# Step 1: Configure MySQL and JWT
.\configure-mysql-connection.ps1

# Step 2: Setup Terraform
cd ..\terraform
.\setup-terraform.ps1

# Step 3: Deploy infrastructure
terraform plan
terraform apply

# Step 4: Deploy CI/CD pipeline (optional)
cd ..\deployment\deployment-pipeline
.\setup-pipeline.ps1
```

## Configuration Summary

### MySQL Connection
- **Host**: 172.20.10.4
- **Port**: 3306
- **User**: root
- **Password**: Srikar@123
- **Database**: ecommerce

### JWT Tokens
- **Expiration**: NEVER (tokens do not expire)
- **Algorithm**: HMAC256
- **Secret**: Auto-generated 64-byte random string
- **Storage**: AWS SSM Parameter Store (encrypted)

## Directory Structure

```
deployment/
├── README.md                              # This file
├── quick-start.ps1                        # Automated deployment script
├── configure-mysql-connection.ps1         # MySQL and JWT configuration
├── mysql-connection-setup.md              # Network connectivity guide
├── INFRASTRUCTURE_DEPLOYMENT_GUIDE.md     # Complete deployment guide
├── MYSQL_JWT_CONFIGURATION_SUMMARY.md     # Configuration reference
├── PRODUCTION_DEPLOYMENT_CHECKLIST.md     # Production readiness checklist
├── CICD_IMPLEMENTATION_SUMMARY.md         # CI/CD overview
│
└── deployment-pipeline/                   # CI/CD Pipeline
    ├── README.md                          # Pipeline documentation
    ├── setup-pipeline.ps1                 # Pipeline setup script
    ├── local-deploy.ps1                   # Local deployment script
    ├── teardown-pipeline.ps1              # Cleanup script
    ├── buildspec-dev.yml                  # Dev build specification
    ├── buildspec-prod.yml                 # Prod build specification
    ├── pipeline-template.yml              # CloudFormation template
    ├── PIPELINE_SUMMARY.md                # Pipeline details
    └── QUICK_START.md                     # Quick reference
```

## Scripts

### configure-mysql-connection.ps1
Configures MySQL connection and JWT secrets.

**What it does:**
- Stores MySQL credentials in AWS SSM Parameter Store
- Generates secure JWT secrets (64-byte random)
- Stores JWT secrets in SSM (encrypted)
- Optionally tests MySQL connection
- Optionally saves secrets to local backup

**Usage:**
```powershell
.\configure-mysql-connection.ps1
```

**Parameters stored:**
```
/ecommerce-ai-platform/dev/mysql/host
/ecommerce-ai-platform/dev/mysql/port
/ecommerce-ai-platform/dev/mysql/user
/ecommerce-ai-platform/dev/mysql/password (encrypted)
/ecommerce-ai-platform/dev/mysql/database
/ecommerce-ai-platform/dev/jwt/secret (encrypted)
```

### quick-start.ps1
Automated end-to-end deployment.

**What it does:**
- Checks prerequisites (AWS CLI, Terraform)
- Runs MySQL/JWT configuration
- Sets up Terraform backend
- Deploys infrastructure
- Verifies deployment

**Usage:**
```powershell
# Full deployment
.\quick-start.ps1

# Skip MySQL config (if already done)
.\quick-start.ps1 -SkipMySQLConfig

# Auto-approve Terraform (use with caution)
.\quick-start.ps1 -AutoApprove
```

**Options:**
- `-SkipMySQLConfig` - Skip MySQL and JWT configuration
- `-SkipTerraformSetup` - Skip Terraform backend setup
- `-AutoApprove` - Automatically approve Terraform apply

## Documentation

### INFRASTRUCTURE_DEPLOYMENT_GUIDE.md
Complete step-by-step deployment guide covering:
- Prerequisites and requirements
- MySQL connection setup
- JWT configuration
- Terraform deployment
- Network connectivity options
- Post-deployment steps
- Monitoring and logging
- Cost estimation
- Troubleshooting

### MYSQL_JWT_CONFIGURATION_SUMMARY.md
Detailed reference for MySQL and JWT configuration:
- Connection details
- Storage locations
- Network connectivity requirements
- Security recommendations
- Token structure and verification
- Configuration scripts
- Troubleshooting

### mysql-connection-setup.md
Network connectivity guide for MySQL:
- VPN setup (recommended)
- Direct Connect setup
- SSH tunnel (development)
- Public IP setup (not recommended)
- MySQL server configuration
- Security best practices

### PRODUCTION_DEPLOYMENT_CHECKLIST.md
Production readiness checklist covering:
- Security hardening
- Performance optimization
- Monitoring and alerting
- Backup and disaster recovery
- Compliance requirements
- Documentation

### CICD_IMPLEMENTATION_SUMMARY.md
CI/CD pipeline overview:
- Pipeline architecture
- Build specifications
- Deployment stages
- Manual approvals
- Cost breakdown

## Prerequisites

### Required Tools
- **AWS CLI** - Configured with credentials
- **Terraform** >= 1.0
- **PowerShell** 7+
- **MySQL Client** (optional, for testing)

### AWS Account Requirements
- AWS Account with appropriate permissions
- IAM user with AdministratorAccess or equivalent
- AWS CLI configured: `aws configure`

### Installation

#### AWS CLI
```powershell
# Windows (using winget)
winget install Amazon.AWSCLI

# Or download from: https://aws.amazon.com/cli/
```

#### Terraform
```powershell
# Windows (using Chocolatey)
choco install terraform

# Or download from: https://www.terraform.io/downloads
```

#### PowerShell 7+
```powershell
# Windows (using winget)
winget install Microsoft.PowerShell

# Or download from: https://github.com/PowerShell/PowerShell
```

## Deployment Workflow

### 1. Initial Setup
```powershell
# Configure AWS credentials
aws configure

# Verify credentials
aws sts get-caller-identity
```

### 2. Configure MySQL and JWT
```powershell
cd deployment
.\configure-mysql-connection.ps1
```

### 3. Deploy Infrastructure
```powershell
# Option A: Quick start (automated)
.\quick-start.ps1

# Option B: Manual deployment
cd ..\terraform
.\setup-terraform.ps1
terraform plan
terraform apply
```

### 4. Setup Network Connectivity
Follow the guide in `mysql-connection-setup.md` to establish connectivity between AWS and your MySQL server (172.20.10.4).

**Recommended**: AWS Site-to-Site VPN

### 5. Deploy CI/CD Pipeline (Optional)
```powershell
cd deployment\deployment-pipeline
.\setup-pipeline.ps1 `
    -GitHubRepo "your-org/ecommerce-ai-platform" `
    -GitHubToken "ghp_xxx" `
    -DevApprovalEmail "dev@example.com" `
    -ProdApprovalEmail "prod@example.com"
```

### 6. Verify Deployment
```powershell
# Check S3 buckets
aws s3 ls | Select-String "ecommerce-ai-platform"

# Check Lambda functions
aws lambda list-functions --query "Functions[?contains(FunctionName, 'ecommerce')].FunctionName"

# Get Terraform outputs
cd terraform
terraform output
```

## Network Connectivity

### Important: MySQL Access from AWS

Your MySQL server (172.20.10.4) is on a private network. AWS services need network connectivity to reach it.

### Options

1. **AWS Site-to-Site VPN** (Recommended)
   - Cost: ~$36/month
   - Setup time: 1-2 hours
   - Secure encrypted tunnel

2. **AWS Direct Connect**
   - Cost: $300+/month
   - Setup time: 2-4 weeks
   - Dedicated connection

3. **SSH Tunnel** (Development only)
   - Cost: Free
   - Setup time: 30 minutes
   - Not for production

See `mysql-connection-setup.md` for detailed setup instructions.

## Cost Estimation

### Development Environment
| Service | Monthly Cost |
|---------|-------------|
| VPC (NAT Gateway) | $32 |
| S3 Storage (100GB) | $2.30 |
| Lambda (1M requests) | $0.20 |
| DMS (c5.xlarge) | $184 |
| CloudWatch | $5-10 |
| Data Transfer | $10-20 |
| **Total** | **$280-450** |

### Production Environment
- 2-3x development costs
- Add: Load balancers, multi-AZ, backups
- Estimated: $800-1,500/month

## Security

### Credentials Storage
All sensitive credentials are stored in AWS Systems Manager Parameter Store:
- MySQL passwords: SecureString (encrypted with KMS)
- JWT secrets: SecureString (encrypted with KMS)
- Never committed to Git
- Access controlled via IAM policies

### Network Security
- VPC with private subnets
- Security groups restrict access
- VPN/Direct Connect for MySQL access
- SSL/TLS for all connections

### Best Practices
1. Use dedicated DMS user (not root)
2. Rotate passwords every 90 days
3. Enable MFA for AWS accounts
4. Use separate secrets for dev/prod
5. Enable CloudTrail for audit logging

## Troubleshooting

### Common Issues

#### 1. AWS Credentials Not Configured
```
Error: Unable to locate credentials
```
**Solution**: Run `aws configure` and enter your credentials

#### 2. Terraform Backend Error
```
Error: Failed to get existing workspaces
```
**Solution**: Run `.\terraform\setup-terraform.ps1`

#### 3. MySQL Connection Failed
```
Error: Can't connect to MySQL server on '172.20.10.4'
```
**Solution**: 
- Check network connectivity (VPN not setup yet?)
- Verify MySQL is running
- Check firewall rules

#### 4. SSM Parameters Not Found
```
Error: Parameter not found
```
**Solution**: Run `.\configure-mysql-connection.ps1`

### Getting Help

1. Check CloudWatch Logs for detailed errors
2. Review Terraform state: `terraform show`
3. Verify SSM parameters: `aws ssm describe-parameters`
4. Test MySQL connection manually
5. See `docs/TROUBLESHOOTING_GUIDE.md`

## Next Steps

After successful deployment:

1. **Setup Database Schema**
   ```powershell
   cd database
   .\setup-database.ps1 -Environment dev
   ```

2. **Deploy Lambda Functions**
   ```powershell
   cd auth-service
   mvn clean package
   # Deploy to Lambda
   ```

3. **Deploy Frontend**
   ```powershell
   cd frontend
   npm install
   npm run build
   # Upload to S3
   ```

4. **Run Integration Tests**
   ```powershell
   cd tests\integration
   .\run_integration_tests.ps1
   ```

5. **Setup Monitoring**
   - Configure CloudWatch alarms
   - Setup SNS notifications
   - Enable X-Ray tracing

## Additional Resources

### Documentation
- [Infrastructure Deployment Guide](INFRASTRUCTURE_DEPLOYMENT_GUIDE.md)
- [MySQL Configuration Summary](MYSQL_JWT_CONFIGURATION_SUMMARY.md)
- [MySQL Connection Setup](mysql-connection-setup.md)
- [CI/CD Pipeline Guide](deployment-pipeline/README.md)
- [Production Checklist](PRODUCTION_DEPLOYMENT_CHECKLIST.md)

### Terraform
- [Terraform README](../terraform/README.md)
- [Terraform Quick Start](../terraform/QUICKSTART.md)
- [API Gateway Setup](../terraform/API_GATEWAY_SETUP.md)
- [Glue & Athena Setup](../terraform/GLUE_ATHENA_SETUP.md)

### Testing
- [Integration Tests](../tests/integration/README.md)
- [Performance Tests](../tests/performance/OPTIMIZATION_GUIDE.md)
- [Security Tests](../tests/security/SECURITY_TESTING_GUIDE.md)

### Monitoring
- [Monitoring Setup Guide](../MONITORING_SETUP_GUIDE.md)
- [Troubleshooting Guide](../docs/TROUBLESHOOTING_GUIDE.md)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review CloudWatch Logs
3. Verify AWS service health
4. Check Terraform state
5. Review documentation

## License

Copyright © 2024 eCommerce AI Platform. All rights reserved.
