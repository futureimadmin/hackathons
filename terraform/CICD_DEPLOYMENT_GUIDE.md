# CI/CD Pipeline Deployment Guide

## Overview
This guide explains how to deploy the complete CI/CD pipeline for the eCommerce AI Platform, including both DEV and PROD environments.

## What Was Created

### 1. Lambda Execution Role
- **Location**: `terraform/modules/iam/main.tf`
- **Purpose**: IAM role for all Lambda functions with permissions for:
  - CloudWatch Logs
  - DynamoDB access
  - S3 access
  - Secrets Manager
  - KMS encryption
  - VPC networking

### 2. S3 Frontend Bucket Module
- **Location**: `terraform/modules/s3-frontend/`
- **Purpose**: Hosts the React frontend with static website hosting
- **Features**:
  - Public read access
  - Website configuration
  - Versioning enabled
  - Server-side encryption

### 3. CI/CD Pipeline Module
- **Location**: `terraform/modules/cicd-pipeline/`
- **Components**:
  - CodePipeline with 4 stages
  - 4 CodeBuild projects
  - GitHub CodeStar connection
  - S3 artifacts bucket
  - IAM roles with full Terraform permissions

### 4. Pipeline Stages
1. **Source**: Pull code from GitHub (futureimadmin/hackathons, master branch)
2. **Infrastructure**: Deploy Terraform infrastructure
3. **BuildLambdas**: Build and deploy Java + Python Lambda functions
4. **BuildFrontend**: Build React app and deploy to S3

## Prerequisites

1. **AWS CLI configured** with credentials for account 450133579764
2. **Terraform installed** (v1.0+)
3. **GitHub repository** already exists at https://github.com/futureimadmin/hackathons.git
4. **Backend S3 bucket** already exists: `futureim-ecommerce-ai-platform-terraform-state`
5. **DynamoDB table** already exists: `futureim-ecommerce-ai-platform-terraform-locks`

## Deployment Steps

### Step 1: Deploy DEV Environment

```powershell
cd terraform

# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var-file="terraform.dev.tfvars" -out=dev.tfplan

# Apply the changes
terraform apply dev.tfplan
```

### Step 2: Approve GitHub Connection

After the first deployment, you need to manually approve the GitHub connection:

1. Go to AWS Console → Developer Tools → Connections
2. Find the connection: `futureim-ecommerce-ai-platform-github-dev`
3. Click "Update pending connection"
4. Follow the OAuth flow to authorize GitHub access
5. Connection status will change from "PENDING" to "AVAILABLE"

### Step 3: Deploy PROD Environment

```powershell
# Plan production deployment
terraform plan -var-file="terraform.prod.tfvars" -out=prod.tfplan

# Apply production changes
terraform apply prod.tfplan
```

### Step 4: Approve PROD GitHub Connection

Repeat Step 2 for the production connection:
- Connection name: `futureim-ecommerce-ai-platform-github-prod`

### Step 5: Trigger First Pipeline Run

The pipeline will automatically trigger on the next commit to the master branch. To manually trigger:

1. Go to AWS Console → CodePipeline
2. Select your pipeline: `futureim-ecommerce-ai-platform-pipeline-dev` or `-prod`
3. Click "Release change"

## Pipeline Behavior

### Automatic Triggers
- Pipeline triggers automatically on every commit or PR merge to master branch
- Uses GitHub webhooks via CodeStar connection

### Build Process

#### Stage 1: Infrastructure
- Runs `terraform init`, `plan`, and `apply`
- Creates/updates all AWS resources
- Outputs API Gateway URL for frontend

#### Stage 2: Build Lambdas (Parallel)
- **Java Lambda**: Builds auth-service with Maven
- **Python Lambdas**: Builds all 6 AI system Lambdas
  - analytics-service
  - market-intelligence-hub
  - demand-insights-engine
  - compliance-guardian
  - retail-copilot
  - global-market-pulse

#### Stage 3: Build Frontend
- Reads API Gateway URL from infrastructure stage
- Builds React app with production API URL
- Deploys to S3 bucket
- Frontend becomes immediately available

## Important Notes

### GitHub Token Security
- Token is stored in AWS Secrets Manager
- Encrypted with KMS
- Token: ``
- This is a Classic token with repo access

### Environment Separation
- **DEV**: Uses `10.0.0.0/16` VPC CIDR
- **PROD**: Uses `10.1.0.0/16` VPC CIDR
- Separate state files: `dev/terraform.tfstate` and `prod/terraform.tfstate`
- Separate pipelines, buckets, and all resources

### API Gateway Integration
- API Gateway is deployed in Infrastructure stage
- URL is passed to Frontend build stage
- Frontend `.env.prod` is updated automatically during build
- No manual configuration needed

### Lambda Deployment
- Lambdas are created/updated by CodeBuild
- Use Lambda execution role created by Terraform
- Automatically get correct environment variables
- Support both create and update operations

## Monitoring

### View Pipeline Status
```powershell
# Get pipeline URL from Terraform output
terraform output pipeline_url
```

### View Build Logs
1. Go to CodePipeline console
2. Click on a stage
3. Click "Details" on a build action
4. View CloudWatch Logs

### Check Lambda Functions
```powershell
# List all Lambda functions
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `futureim-ecommerce-ai-platform`)].FunctionName'
```

### Check Frontend
```powershell
# Get frontend URL
terraform output frontend_website_url
```

## Troubleshooting

### GitHub Connection Pending
**Problem**: Pipeline fails with "Connection is pending"
**Solution**: Approve the GitHub connection in AWS Console (see Step 2)

### Terraform Permission Errors
**Problem**: CodeBuild fails with IAM permission errors
**Solution**: The CodeBuild role has been updated with full permissions for:
- IAM, EC2, VPC, API Gateway, Lambda, DynamoDB, S3, KMS, Secrets Manager, Glue

### Lambda Creation Fails
**Problem**: Lambda creation fails with "Role not found"
**Solution**: Ensure Infrastructure stage completed successfully and Lambda execution role was created

### Frontend Build Fails
**Problem**: Frontend build can't find API Gateway URL
**Solution**: Check that Infrastructure stage output includes `api_gateway_url.txt` artifact

## Outputs

After successful deployment, you'll have:

```
# DEV Environment
API Gateway URL: https://[api-id].execute-api.us-east-2.amazonaws.com/dev
Frontend URL: http://futureim-ecommerce-ai-platform-frontend-dev.s3-website.us-east-2.amazonaws.com
Pipeline URL: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/futureim-ecommerce-ai-platform-pipeline-dev/view

# PROD Environment
API Gateway URL: https://[api-id].execute-api.us-east-2.amazonaws.com/prod
Frontend URL: http://futureim-ecommerce-ai-platform-frontend-prod.s3-website.us-east-2.amazonaws.com
Pipeline URL: https://console.aws.amazon.com/codesuite/codepipeline/pipelines/futureim-ecommerce-ai-platform-pipeline-prod/view
```

## Next Steps

1. **Deploy DEV first** to test the pipeline
2. **Verify all stages complete** successfully
3. **Test the frontend** and API endpoints
4. **Deploy PROD** once DEV is stable
5. **Set up monitoring** with CloudWatch alarms
6. **Configure notifications** for pipeline failures

## Files Modified/Created

### New Files
- `terraform/modules/iam/main.tf` - Added Lambda execution role
- `terraform/modules/iam/outputs.tf` - Added Lambda role output
- `terraform/modules/s3-frontend/` - New module for frontend hosting
- `terraform/modules/cicd-pipeline/` - Complete CI/CD pipeline module
- `terraform/terraform.dev.tfvars` - DEV environment variables
- `terraform/terraform.prod.tfvars` - PROD environment variables
- `terraform/backend-prod.hcl` - PROD backend configuration
- `buildspecs/*.yml` - All buildspec files

### Modified Files
- `terraform/main.tf` - Added frontend bucket and CI/CD pipeline modules
- `terraform/variables.tf` - Added GitHub configuration variables
- `frontend/.env.prod` - Production API Gateway URL (placeholder)

## Cost Estimate

### Per Environment (DEV + PROD)
- **CodePipeline**: $1/month per pipeline
- **CodeBuild**: ~$0.005/minute (only when building)
- **S3 Artifacts**: ~$0.023/GB storage
- **S3 Frontend**: ~$0.023/GB + $0.004/10k requests
- **Secrets Manager**: $0.40/month per secret
- **CodeStar Connection**: Free

**Estimated Monthly Cost**: ~$5-10 per environment (excluding Lambda/API Gateway usage)
