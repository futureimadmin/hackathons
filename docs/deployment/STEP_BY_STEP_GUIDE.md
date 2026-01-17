# Step-by-Step Deployment Guide

## Overview
This guide provides a detailed walkthrough of deploying the eCommerce AI Platform following your specified workflow.

## Prerequisites
- AWS CLI configured
- Terraform installed
- MySQL client installed
- Python 3.9+
- Maven (for Java builds)
- Node.js 18+ (for React frontend)
- PowerShell 7+

## Deployment Steps

### Quick Start
Run the automated step-by-step script:
```powershell
cd deployment
.\step-by-step-deployment.ps1
```

The script will guide you through each step with prompts and confirmations.

---

## Detailed Step-by-Step Process

### STEP 1: Create MySQL Schema and Insert Sample Data

**Objective**: Setup database schema and generate 500MB of sample data on your local MySQL server (172.20.10.4)

**Actions**:
1. Test MySQL connection
2. Create database schema
3. Generate 500MB of sample data

**Commands**:
```powershell
cd database

# Test connection
mysql -h 172.20.10.4 -u root -p'Srikar@123' -e "SELECT VERSION();"

# Create database
mysql -h 172.20.10.4 -u root -p'Srikar@123' -e "CREATE DATABASE IF NOT EXISTS ecommerce;"

# Run schema scripts
mysql -h 172.20.10.4 -u root -p'Srikar@123' ecommerce < schema/01_main_ecommerce_schema.sql
mysql -h 172.20.10.4 -u root -p'Srikar@123' ecommerce < schema/02_system_specific_schemas.sql

# Generate sample data (500MB)
$env:MYSQL_HOST = "172.20.10.4"
$env:MYSQL_USER = "root"
$env:MYSQL_PASSWORD = "Srikar@123"
$env:MYSQL_DATABASE = "ecommerce"
$env:TARGET_SIZE_MB = "500"
python data_generator/generate_sample_data.py

# Verify
mysql -h 172.20.10.4 -u root -p'Srikar@123' ecommerce -e "SHOW TABLES;"
```

**Expected Result**:
- Database `ecommerce` created
- All tables created (customers, products, orders, etc.)
- ~500MB of sample data inserted
- Data ready for replication

**Time**: 5-10 minutes

---

### STEP 2: Configure MySQL Connection and JWT in AWS

**Objective**: Store MySQL credentials and JWT secrets in AWS SSM Parameter Store

**Actions**:
1. Generate secure JWT secrets (64-byte random)
2. Store MySQL connection details in SSM
3. Store JWT secrets in SSM (encrypted)

**Commands**:
```powershell
cd deployment
.\configure-mysql-connection.ps1
```

**Interactive Prompts**:
- Confirm DEV MySQL configuration (172.20.10.4)
- Choose whether to use same MySQL for PROD
- Optionally save JWT secrets to local backup
- Optionally test MySQL connection

**Parameters Stored**:
```
/ecommerce-ai-platform/dev/mysql/host = 172.20.10.4
/ecommerce-ai-platform/dev/mysql/port = 3306
/ecommerce-ai-platform/dev/mysql/user = root
/ecommerce-ai-platform/dev/mysql/password = Srikar@123 (encrypted)
/ecommerce-ai-platform/dev/mysql/database = ecommerce
/ecommerce-ai-platform/dev/jwt/secret = <generated> (encrypted)
```

**Expected Result**:
- All parameters stored in AWS SSM
- JWT secrets generated and stored
- Configuration ready for Terraform

**Time**: 2-3 minutes

---

### STEP 3: Create AWS Infrastructure with Terraform

**Objective**: Deploy all AWS resources including VPC, S3, DMS, Lambda, API Gateway

**Actions**:
1. Setup Terraform backend (S3 + DynamoDB)
2. Initialize Terraform
3. Plan infrastructure
4. Apply infrastructure

**Commands**:
```powershell
cd terraform

# Setup backend
.\setup-terraform.ps1

# Plan infrastructure
terraform plan -out=tfplan

# Review the plan, then apply
terraform apply tfplan
```

**Interactive Prompts**:
- Confirm Terraform plan
- Wait for infrastructure creation (15-20 minutes)

**Resources Created**:
- **VPC**: 1 VPC with public/private subnets
- **S3 Buckets**: 15 buckets (5 systems × 3 zones)
  - market-intelligence-hub-raw/curated/prod
  - demand-insights-engine-raw/curated/prod
  - compliance-guardian-raw/curated/prod
  - retail-copilot-raw/curated/prod
  - global-market-pulse-raw/curated/prod
- **DMS**: Replication instance + endpoints for MySQL → S3
- **IAM**: Roles and policies for all services
- **KMS**: Encryption keys
- **Lambda**: Function placeholders (code deployed in Step 4)
- **API Gateway**: REST API with endpoints
- **DynamoDB**: Tables for user management
- **Glue**: Crawlers for data cataloging
- **Athena**: Databases and workgroups
- **CloudWatch**: Log groups and metrics

**Expected Result**:
- All infrastructure created successfully
- Terraform outputs displayed (VPC ID, bucket names, API URL, etc.)
- DMS ready to replicate from 172.20.10.4

**Time**: 15-20 minutes

**Cost**: ~$280-450/month

---

### STEP 4: Build and Deploy Java/Python Modules

**Objective**: Build all services and deploy to AWS Lambda

**Actions**:
1. Build Auth Service (Java with Maven)
2. Build Analytics Service (Python)
3. Build 5 AI Systems (Python)
4. Deploy all to Lambda

**Commands**:

#### 4.1 Auth Service (Java)
```powershell
cd auth-service
mvn clean package

# Deploy to Lambda
aws lambda update-function-code `
    --function-name ecommerce-ai-platform-dev-auth `
    --zip-file fileb://target/auth-service-1.0.0.jar `
    --region us-east-1
```

#### 4.2 Analytics Service (Python)
```powershell
cd analytics-service
.\build.ps1
```

#### 4.3 AI Systems (Python)
```powershell
# Market Intelligence Hub
cd ai-systems/market-intelligence-hub
.\build.ps1

# Demand Insights Engine
cd ../demand-insights-engine
.\build.ps1

# Compliance Guardian
cd ../compliance-guardian
.\build.ps1

# Retail Copilot
cd ../retail-copilot
.\build.ps1

# Global Market Pulse
cd ../global-market-pulse
.\build.ps1
```

**Expected Result**:
- All services built successfully
- Lambda functions updated with new code
- Functions ready to handle requests

**Time**: 10-15 minutes

---

### STEP 5: Setup and Verify API Gateway

**Objective**: Verify API Gateway is configured and connected to Lambda functions

**Actions**:
1. Get API Gateway URL from Terraform outputs
2. Test health endpoint
3. Verify Lambda integrations

**Commands**:
```powershell
cd terraform

# Get API Gateway URL
$apiUrl = terraform output -raw api_gateway_url

# Test health endpoint
curl $apiUrl/health

# Test auth endpoint
curl -X POST $apiUrl/auth/login `
    -H "Content-Type: application/json" `
    -d '{"email":"test@example.com","password":"password123"}'
```

**Expected Result**:
- API Gateway URL retrieved
- Health endpoint responds with 200 OK
- API endpoints accessible

**Time**: 2-3 minutes

---

### STEP 6: Deploy React Frontend to S3

**Objective**: Build React application and deploy to S3 static hosting

**Actions**:
1. Install dependencies
2. Build React application
3. Deploy to S3
4. Configure static website hosting
5. Make bucket public

**Commands**:
```powershell
cd frontend

# Install dependencies
npm install

# Build application
npm run build

# Deploy to S3
$bucketName = "ecommerce-ai-platform-frontend-dev"
aws s3 mb s3://$bucketName --region us-east-1
aws s3 website s3://$bucketName --index-document index.html --error-document index.html
aws s3 sync dist/ s3://$bucketName/ --delete

# Make public
$policy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::$bucketName/*"
        }
    ]
}
"@
$policy | Out-File -FilePath "bucket-policy.json" -Encoding UTF8
aws s3api put-bucket-policy --bucket $bucketName --policy file://bucket-policy.json
```

**Expected Result**:
- React application built
- Files uploaded to S3
- Static website hosting enabled
- Frontend accessible via S3 URL

**Time**: 5-7 minutes

---

### STEP 7: Publish URLs and Summary

**Objective**: Display all deployment URLs and save for reference

**URLs Published**:

#### Frontend Application
```
http://ecommerce-ai-platform-frontend-dev.s3-website-us-east-1.amazonaws.com
```

#### API Gateway
```
https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/dev
```

#### AWS Console Links
- **CloudWatch Logs**: https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups
- **Lambda Functions**: https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions
- **S3 Buckets**: https://s3.console.aws.amazon.com/s3/home?region=us-east-1
- **API Gateway**: https://console.aws.amazon.com/apigateway/home?region=us-east-1
- **DMS**: https://console.aws.amazon.com/dms/v2/home?region=us-east-1

#### Database
- **Host**: 172.20.10.4
- **Database**: ecommerce
- **Data Size**: ~500MB

**URLs saved to**: `DEPLOYMENT_URLS.txt`

---

## Verification Steps

### 1. Verify Database
```powershell
mysql -h 172.20.10.4 -u root -p'Srikar@123' ecommerce -e "SELECT COUNT(*) FROM customers;"
```

### 2. Verify AWS Resources
```powershell
# S3 Buckets
aws s3 ls | Select-String "ecommerce-ai-platform"

# Lambda Functions
aws lambda list-functions --query "Functions[?contains(FunctionName, 'ecommerce')].FunctionName"

# DMS Replication
aws dms describe-replication-instances
```

### 3. Verify API Gateway
```powershell
$apiUrl = "https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/dev"
curl $apiUrl/health
```

### 4. Verify Frontend
Open browser to: `http://ecommerce-ai-platform-frontend-dev.s3-website-us-east-1.amazonaws.com`

---

## Troubleshooting

### MySQL Connection Issues
**Problem**: Can't connect to MySQL from AWS
**Solution**: 
- Verify MySQL is running
- Check bind-address in my.cnf (should be 0.0.0.0)
- Setup VPN connection (see `mysql-connection-setup.md`)

### Terraform Errors
**Problem**: Terraform apply fails
**Solution**:
- Check AWS credentials: `aws sts get-caller-identity`
- Verify SSM parameters exist
- Check Terraform logs for specific errors

### Lambda Deployment Fails
**Problem**: Lambda function not found
**Solution**:
- Ensure Terraform created Lambda functions first
- Check function name matches: `ecommerce-ai-platform-dev-<service>`
- Verify IAM permissions

### Frontend Not Loading
**Problem**: S3 website returns 403 Forbidden
**Solution**:
- Verify bucket policy allows public read
- Check static website hosting is enabled
- Ensure index.html exists in bucket

---

## Next Steps

1. **Setup Monitoring**:
   ```powershell
   # Configure CloudWatch alarms
   cd terraform
   terraform apply -target=module.monitoring
   ```

2. **Setup CI/CD Pipeline**:
   ```powershell
   cd deployment/deployment-pipeline
   .\setup-pipeline.ps1
   ```

3. **Configure Custom Domain** (Optional):
   - Register domain in Route 53
   - Create CloudFront distribution
   - Point domain to CloudFront

4. **Enable DMS Replication**:
   - Start DMS replication tasks
   - Monitor replication lag
   - Verify data in S3

5. **Run Integration Tests**:
   ```powershell
   cd tests/integration
   .\run_integration_tests.ps1
   ```

---

## Cost Breakdown

### Monthly Costs (Development)
| Service | Cost |
|---------|------|
| VPC (NAT Gateway) | $32 |
| S3 Storage (100GB) | $2.30 |
| Lambda (1M requests) | $0.20 |
| DMS (c5.xlarge) | $184 |
| API Gateway | $3.50 |
| CloudWatch | $5-10 |
| Data Transfer | $10-20 |
| **Total** | **~$280-450** |

### Cost Optimization
- Stop DMS when not in use
- Use S3 Intelligent-Tiering
- Set CloudWatch log retention to 7 days
- Use Lambda reserved concurrency

---

## Support

For issues or questions:
1. Check `TROUBLESHOOTING_GUIDE.md`
2. Review CloudWatch Logs
3. Verify Terraform state
4. Check AWS service health

---

## Summary

✅ **Step 1**: MySQL schema and 500MB data created
✅ **Step 2**: MySQL and JWT configured in AWS SSM
✅ **Step 3**: AWS infrastructure deployed (VPC, S3, DMS, Lambda, API Gateway)
✅ **Step 4**: Java/Python modules built and deployed
✅ **Step 5**: API Gateway verified and tested
✅ **Step 6**: React frontend deployed to S3
✅ **Step 7**: URLs published and saved

**Total Time**: ~45-60 minutes
**Total Cost**: ~$280-450/month

🎉 **Deployment Complete!**
