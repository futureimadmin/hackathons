# Deployment Workflow Guide

## Overview

This guide explains the complete deployment workflow for the FutureIM eCommerce AI Platform.

## Two Deployment Approaches

### Approach 1: Automated (Recommended for First-Time Setup)
Use `step-by-step-deployment.ps1` which handles everything in sequence.

### Approach 2: Manual (Recommended for Production)
Run each component separately for more control.

## What Each Tool Does

### 1. Terraform (`terraform apply`)
**Purpose:** Creates AWS infrastructure
**Creates:**
- VPC, subnets, security groups
- S3 buckets for data lakes
- IAM roles and policies
- Lambda function placeholders
- DMS replication instances
- Glue crawlers and databases
- CloudWatch log groups

**Does NOT:**
- Set up MySQL database
- Deploy application code
- Build microservices
- Configure API Gateway endpoints
- Deploy frontend

### 2. step-by-step-deployment.ps1
**Purpose:** Complete end-to-end deployment
**Steps:**
1. MySQL database setup (schema + sample data)
2. AWS SSM parameter configuration (MySQL credentials, JWT secrets)
3. Terraform infrastructure (can skip if already done)
4. Build and deploy microservices (auth, analytics, AI systems)
5. Configure API Gateway
6. Build and deploy frontend
7. Display deployment outputs

## Recommended Workflow

### First-Time Deployment

```powershell
# Step 1: Create Terraform backend resources
cd terraform
.\create-backend-resources.ps1

# Step 2: Run the automated deployment
cd ..\deployment
.\step-by-step-deployment.ps1
```

The script will prompt you at each step. Answer "yes" to proceed.


### If You Already Ran Terraform

```powershell
# Run the deployment script
cd deployment
.\step-by-step-deployment.ps1

# When it reaches Step 3 (Terraform), you can:
# - Answer "no" to skip it
# - Or answer "yes" to let it run again (safe, idempotent)
```

### Manual Deployment (Production)

```powershell
# 1. Create backend resources
cd terraform
.\create-backend-resources.ps1

# 2. Deploy infrastructure
terraform init
terraform plan
terraform apply

# 3. Set up MySQL database
cd ..\database
# Run schema scripts manually or use data generator

# 4. Configure AWS parameters
cd ..\deployment
.\configure-mysql-connection.ps1

# 5. Build and deploy each service
cd ..\auth-service
mvn clean package
# Deploy to Lambda

cd ..\analytics-service
mvn clean package
# Deploy to Lambda

# 6. Build and deploy AI systems
cd ..\ai-systems\market-intelligence-hub
.\build.ps1

# 7. Deploy frontend
cd ..\..\frontend
npm install
npm run build
# Deploy to S3/CloudFront
```

## Key Points

1. **Terraform creates infrastructure, not applications**
   - Think of it as building the foundation and walls
   - Applications are deployed separately

2. **step-by-step-deployment.ps1 does both**
   - Runs Terraform (Step 3)
   - Deploys applications (Steps 4-6)

3. **You can skip Terraform in the deployment script**
   - If you already ran `terraform apply`
   - Just answer "no" when prompted for Step 3

4. **Database setup is separate**
   - Terraform doesn't touch your MySQL database
   - step-by-step-deployment.ps1 handles it in Step 1

## Troubleshooting

### "Do I need to run both?"
- If using step-by-step-deployment.ps1: **No**, it includes Terraform
- If you ran terraform apply first: **Yes**, but skip Step 3 in the deployment script

### "Can I run terraform apply multiple times?"
- **Yes**, Terraform is idempotent
- It only creates/updates what changed

### "What if I only want to update one service?"
- Use manual deployment approach
- Rebuild and redeploy just that service
- No need to run full deployment script

## Next Steps

After deployment completes:
1. Verify all services are running
2. Test API endpoints
3. Check CloudWatch logs
4. Monitor DMS replication
5. Review Glue crawler results
