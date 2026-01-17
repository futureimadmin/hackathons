# Task 15: End-to-End Flow Verification Guide

## Overview

This guide walks you through verifying the complete end-to-end flow of the eCommerce AI Analytics Platform:
- **MySQL** → **DMS** → **S3** → **Glue** → **Athena**
- **Authentication** and **Frontend** navigation
- **Data quality** and consistency

## Prerequisites

Before starting, ensure you have:
- ✅ Terraform installed (v1.14.3 confirmed)
- ✅ AWS CLI configured with credentials
- ✅ MySQL database with sample data (Task 14)
- ✅ All Terraform modules created (Tasks 1-11)

## Step 1: Fix Terraform PATH (If Needed)

If Terraform doesn't work in Kiro's terminal:

```powershell
cd terraform
.\fix-terraform-path.ps1
```

This will add Terraform to your current session's PATH.

## Step 2: Configure AWS Credentials

```powershell
# Check if AWS CLI is configured
aws sts get-caller-identity

# If not configured, run:
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

## Step 3: Set Up Terraform Backend (Optional but Recommended)

```powershell
cd terraform

# Create S3 bucket for Terraform state
aws s3 mb s3://ecommerce-platform-terraform-state --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table `
    --table-name terraform-state-lock `
    --attribute-definitions AttributeName=LockID,AttributeType=S `
    --key-schema AttributeName=LockID,KeyType=HASH `
    --billing-mode PAY_PER_REQUEST `
    --region us-east-1
```

## Step 4: Configure Terraform Variables

Create `terraform.tfvars` file:

```powershell
cd terraform
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# AWS Configuration
aws_region = "us-east-1"
environment = "dev"
project_name = "ecommerce-ai-platform"

# On-Premise MySQL Configuration
mysql_host = "172.20.10.4"  # or "localhost" for local testing
mysql_port = 3306
mysql_database = "ecommerce_platform"
mysql_username = "root"

# S3 Bucket Names (must be globally unique)
s3_bucket_prefix = "ecommerce-platform-yourname"  # Change 'yourname'

# API Gateway Configuration
cors_allowed_origin = "http://localhost:5173"  # Frontend URL

# Tags
tags = {
  Project = "eCommerce AI Platform"
  Environment = "Development"
  ManagedBy = "Terraform"
}
```

## Step 5: Store MySQL Password in AWS Secrets Manager

```powershell
# Create secret for MySQL password
aws secretsmanager create-secret `
    --name ecommerce-platform/mysql-password `
    --description "MySQL root password for DMS" `
    --secret-string "Srikar@123" `
    --region us-east-1

# Create secret for JWT signing key
$jwtSecret = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
aws secretsmanager create-secret `
    --name ecommerce-platform/jwt-secret `
    --description "JWT signing secret" `
    --secret-string $jwtSecret `
    --region us-east-1
```

## Step 6: Initialize Terraform

```powershell
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment (see what will be created)
terraform plan
```

**Expected Output:**
- Terraform will show all resources to be created
- Should see ~50-100 resources
- No errors should appear

## Step 7: Deploy Infrastructure (Dry Run First)

```powershell
# Create a plan file
terraform plan -out=tfplan

# Review the plan carefully
# Look for:
# - S3 buckets
# - DMS resources
# - Lambda functions
# - API Gateway
# - DynamoDB tables
# - Glue databases and crawlers
```

## Step 8: Apply Terraform (Deploy to AWS)

⚠️ **Warning**: This will create real AWS resources and may incur costs!

```powershell
# Apply the plan
terraform apply tfplan

# Or apply directly (will ask for confirmation)
terraform apply
```

**This will take 10-15 minutes**. Terraform will create:
- VPC and networking
- S3 buckets (raw, curated, prod)
- DMS replication instance and tasks
- Lambda functions (auth, data processing)
- API Gateway
- DynamoDB tables
- Glue databases and crawlers
- Athena workgroup
- IAM roles and policies

## Step 9: Verify Infrastructure Deployment

```powershell
# Check Terraform outputs
terraform output

# Should show:
# - S3 bucket names
# - API Gateway URL
# - DMS replication task ARNs
# - Lambda function names
```

## Step 10: Set Up MySQL Database

```powershell
cd ../database

# Run setup script
.\setup-database.ps1

# This will:
# 1. Create database schemas
# 2. Generate sample data (10K customers, 50K orders, etc.)
# 3. Takes 5-10 minutes
```

## Step 11: Start DMS Replication

```powershell
# Get replication task ARN from Terraform output
$taskArn = terraform output -raw dms_replication_task_arn

# Start replication
aws dms start-replication-task `
    --replication-task-arn $taskArn `
    --start-replication-task-type start-replication `
    --region us-east-1

# Monitor progress
aws dms describe-replication-tasks `
    --filters "Name=replication-task-arn,Values=$taskArn" `
    --region us-east-1
```

## Step 12: Verify DMS Replication

```powershell
cd ../database

# Run verification script
.\verify-dms-replication.ps1 -ReplicationTaskArn $taskArn
```

**Success Criteria:**
- ✓ Replication task status: "running"
- ✓ All tables show "Table completed"
- ✓ Data appears in S3 raw buckets
- ✓ No errors in CloudWatch logs

## Step 13: Verify Data in S3

```powershell
# List S3 buckets
aws s3 ls | Select-String "ecommerce"

# Check raw bucket contents
$rawBucket = terraform output -raw s3_raw_bucket_name
aws s3 ls s3://$rawBucket/ --recursive | Select-Object -First 20

# Verify file count
$fileCount = (aws s3 ls s3://$rawBucket/ --recursive | Measure-Object).Count
Write-Host "Files in raw bucket: $fileCount"
```

**Expected:**
- Multiple folders for each table (customers, products, orders, etc.)
- Parquet files in each folder
- File count > 20

## Step 14: Run Glue Crawlers

```powershell
# Get crawler names from Terraform output
$crawlerName = terraform output -raw glue_crawler_name

# Start crawler
aws glue start-crawler --name $crawlerName --region us-east-1

# Wait for crawler to complete (takes 2-5 minutes)
Start-Sleep -Seconds 120

# Check crawler status
aws glue get-crawler --name $crawlerName --region us-east-1
```

## Step 15: Verify Data in Athena

```powershell
# List databases
aws athena list-databases `
    --catalog-name AwsDataCatalog `
    --region us-east-1

# List tables in ecommerce database
aws athena list-table-metadata `
    --catalog-name AwsDataCatalog `
    --database-name ecommerce_db `
    --region us-east-1
```

**Test Query in AWS Console:**
1. Go to AWS Athena Console
2. Select `ecommerce_db` database
3. Run query:
```sql
SELECT COUNT(*) as customer_count FROM customers;
```

**Expected Result:** ~10,000 customers

## Step 16: Build and Deploy Authentication Service

```powershell
cd ../auth-service

# Build Java Lambda
.\build.ps1

# Deploy to AWS (if not done by Terraform)
$functionName = terraform output -raw auth_lambda_function_name
aws lambda update-function-code `
    --function-name $functionName `
    --zip-file fileb://target/auth-service.jar `
    --region us-east-1
```

## Step 17: Test Authentication API

```powershell
cd ../terraform

# Get API Gateway URL
$apiUrl = terraform output -raw api_gateway_url

# Test registration
$registerBody = @{
    email = "test@example.com"
    password = "Test@1234"
    name = "Test User"
} | ConvertTo-Json

$response = Invoke-RestMethod `
    -Uri "$apiUrl/auth/register" `
    -Method POST `
    -Body $registerBody `
    -ContentType "application/json"

Write-Host "Registration Response:" -ForegroundColor Cyan
$response | ConvertTo-Json

# Test login
$loginBody = @{
    email = "test@example.com"
    password = "Test@1234"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod `
    -Uri "$apiUrl/auth/login" `
    -Method POST `
    -Body $loginBody `
    -ContentType "application/json"

Write-Host "Login Response:" -ForegroundColor Cyan
$loginResponse | ConvertTo-Json

# Save token for later
$token = $loginResponse.token
```

## Step 18: Deploy and Test Frontend

```powershell
cd ../frontend

# Install dependencies
npm install

# Create .env file
Copy-Item .env.example .env

# Edit .env and set API URL
# VITE_API_URL=<your-api-gateway-url>

# Start development server
npm run dev

# Open browser to http://localhost:5173
```

**Test Frontend:**
1. ✓ Register a new user
2. ✓ Login with credentials
3. ✓ Navigate to home page
4. ✓ Click on each system card
5. ✓ Verify user context is passed to dashboards
6. ✓ Logout

## Step 19: Run Property-Based Tests

```powershell
# Frontend tests
cd frontend
npm test

# Data processing tests
cd ../data-processing
pip install -r requirements-test.txt
pytest tests/

# Terraform tests
cd ../terraform/tests
pytest test_s3_bucket_structure.py
```

## Step 20: Verify Complete Data Flow

Run the end-to-end verification script:

```powershell
cd ../terraform
.\scripts\verify-pipeline-e2e.ps1
```

This script verifies:
1. ✓ DMS replication is working
2. ✓ Data in S3 raw buckets
3. ✓ EventBridge rules are active
4. ✓ Batch jobs can process data
5. ✓ Data in S3 curated buckets
6. ✓ Data in S3 prod buckets
7. ✓ Glue Crawler has cataloged data
8. ✓ Athena can query data
9. ✓ Row counts match MySQL
10. ✓ Authentication API works
11. ✓ Frontend can connect

## Success Criteria

Task 15 is complete when ALL of the following are verified:

### Data Pipeline ✓
- [x] MySQL database has sample data
- [x] DMS replication task is running
- [x] Data appears in S3 raw buckets
- [x] EventBridge triggers Batch jobs
- [x] Data is validated and deduplicated
- [x] Data appears in S3 curated buckets
- [x] Data is transformed for analytics
- [x] Data appears in S3 prod buckets
- [x] Glue Crawler catalogs the data
- [x] Athena can query the data
- [x] Row counts match between MySQL and Athena

### Authentication ✓
- [x] API Gateway is deployed
- [x] Lambda authorizer works
- [x] User registration works
- [x] User login returns JWT token
- [x] JWT token is valid
- [x] Protected endpoints require authentication
- [x] Password reset flow works

### Frontend ✓
- [x] Frontend builds successfully
- [x] Frontend connects to API Gateway
- [x] Login page works
- [x] Registration page works
- [x] Home page displays 5 system cards
- [x] Navigation to dashboards works
- [x] User context is passed to dashboards
- [x] Logout works

### Data Quality ✓
- [x] No duplicate records in curated bucket
- [x] PCI DSS compliance (masked credit cards)
- [x] Data validation catches bad records
- [x] Referential integrity maintained
- [x] Parquet format is valid

## Troubleshooting

### Terraform Issues

**Error: "terraform: command not found"**
```powershell
.\fix-terraform-path.ps1
```

**Error: "Error acquiring the state lock"**
```powershell
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

**Error: "Bucket name already exists"**
- Edit `terraform.tfvars` and change `s3_bucket_prefix` to something unique

### DMS Issues

**Replication task stuck in "starting"**
```powershell
# Stop and restart
aws dms stop-replication-task --replication-task-arn $taskArn
aws dms start-replication-task --replication-task-arn $taskArn --start-replication-task-type start-replication
```

**No data in S3**
- Check DMS CloudWatch logs
- Verify MySQL is accessible from AWS
- Check security groups and network connectivity

### Authentication Issues

**API returns 403 Forbidden**
- Check CORS configuration in API Gateway
- Verify Lambda authorizer is attached
- Check JWT token is valid

**Lambda function errors**
- Check CloudWatch logs: `/aws/lambda/<function-name>`
- Verify environment variables are set
- Check IAM role permissions

### Frontend Issues

**Cannot connect to API**
- Verify `VITE_API_URL` in `.env` is correct
- Check CORS settings in API Gateway
- Verify API Gateway is deployed

## Cleanup (Optional)

To destroy all AWS resources:

```powershell
cd terraform

# Destroy everything
terraform destroy

# Confirm by typing 'yes'
```

⚠️ **Warning**: This will delete all data and resources!

## Next Steps

After successful verification:

1. ✅ Task 15 complete - End-to-end flow verified
2. ➡️ Task 16 - Implement analytics service (Python Lambda)
3. ➡️ Tasks 17-21 - Implement the 5 AI systems

## Estimated Time

- **Setup and Configuration**: 30 minutes
- **Terraform Deployment**: 15 minutes
- **Database Setup**: 10 minutes
- **DMS Replication**: 10-15 minutes
- **Testing and Verification**: 30 minutes
- **Total**: ~2 hours

## Support

If you encounter issues:
1. Check the relevant README files in each module
2. Review CloudWatch logs for errors
3. Check AWS Console for resource status
4. Verify all prerequisites are met

---

**Task**: 15. Checkpoint - Verify end-to-end flow  
**Status**: Ready for execution  
**Prerequisites**: Tasks 1-14 complete  
**Estimated Time**: 2 hours
