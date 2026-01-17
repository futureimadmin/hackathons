# Terraform Modules Integration Guide

## Current Situation

**What's deployed:** VPC, S3, IAM, KMS (basic infrastructure)
**What's missing:** Lambda functions, API Gateway, DMS, Glue

## Problem

The Terraform modules exist but aren't integrated in `main.tf`. Adding them all requires:
1. Lambda function code to be built and packaged
2. Proper configuration for each module
3. Dependencies between modules to be resolved
4. This is a 4-6 hour task minimum

## Recommended Approach

### Option 1: Incremental Addition (Recommended)

Add modules one at a time, test each:

1. **Add DynamoDB Users Table** (no dependencies)
2. **Package and add one Lambda function** (e.g., analytics)
3. **Add API Gateway** (depends on Lambda)
4. **Test end-to-end**
5. **Repeat for other Lambdas**

### Option 2: Use Deployment Script

The `step-by-step-deployment.ps1` script in Step 4 attempts to build and deploy microservices. This might work without Terraform changes.

### Option 3: Manual Deployment (Fastest for Testing)

Deploy components manually to test the system:
1. Build one microservice JAR
2. Create Lambda function manually in AWS Console
3. Create API Gateway manually
4. Test with frontend

## Quick Win: Add DynamoDB Users Table

This has no dependencies and can be added immediately:

```hcl
# Add to terraform/main.tf after the IAM module

# DynamoDB Users Table
module "dynamodb_users" {
  source = "./modules/dynamodb-users"
  
  table_name                    = "${var.project_name}-users-${var.environment}"
  billing_mode                  = "PAY_PER_REQUEST"
  enable_point_in_time_recovery = true
  kms_key_arn                   = module.kms.kms_key_arn
  enable_streams                = true
  
  tags = {
    Environment = var.environment
    System      = "Authentication"
  }
}

output "dynamodb_users_table_name" {
  description = "DynamoDB users table name"
  value       = module.dynamodb_users.table_name
}
```

Then run:
```powershell
terraform apply
```

## Why Lambda Integration is Complex

Each Lambda module needs:
1. **Function code** - JAR/ZIP file must exist
2. **S3 bucket** - To store the deployment package
3. **IAM role** - With proper permissions
4. **VPC configuration** - Security groups, subnets
5. **Environment variables** - Database connections, API keys
6. **Dependencies** - Other services it needs

Example for analytics Lambda:
- Needs analytics-service JAR built
- Needs S3 bucket to upload JAR
- Needs database connection string
- Needs access to data lake S3 buckets
- Needs KMS key for encryption

## Recommended Path Forward

### Immediate (Today):
1. Add DynamoDB users table module
2. Run deployment script Step 4 to see if it deploys microservices
3. If Step 4 fails, deploy one Lambda manually to test

### Short-term (This Week):
1. Build auth-service JAR
2. Create Lambda function manually
3. Create simple API Gateway manually
4. Update frontend with API URL
5. Test end-to-end

### Long-term (Production):
1. Create proper Lambda deployment pipeline
2. Add all Lambda modules to Terraform
3. Add API Gateway module
4. Add DMS and Glue modules
5. Automate everything

## Files to Check

1. **deployment/step-by-step-deployment.ps1** - Step 4 might deploy services
2. **auth-service/pom.xml** - Check if it builds a deployable JAR
3. **analytics-service/pom.xml** - Check if it builds a deployable JAR
4. **terraform/modules/*/README.md** - Module documentation

## Decision Point

**Question:** Do you want to:
A. Add DynamoDB module now (5 minutes)
B. Try running deployment script Step 4 (might work)
C. Deploy one Lambda manually to test (30 minutes)
D. Full Terraform integration (4-6 hours)

**My recommendation:** Try B first (deployment script), then C if it fails, then A for database.
