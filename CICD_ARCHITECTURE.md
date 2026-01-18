# CI/CD Pipeline Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         GitHub Repository                                │
│                   futureimadmin/hackathons (master)                      │
└────────────────────────────┬────────────────────────────────────────────┘
                             │ Webhook on commit/PR merge
                             ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS CodePipeline                                 │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Stage 1: Source                                                  │   │
│  │ - CodeStar Connection (GitHub OAuth)                            │   │
│  │ - Pull latest code from master branch                           │   │
│  │ - Output: source_output artifact                                │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                             ↓                                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Stage 2: Infrastructure                                          │   │
│  │ - CodeBuild Project: infrastructure                             │   │
│  │ - Install Terraform 1.6.6                                       │   │
│  │ - Run: terraform init/plan/apply                                │   │
│  │ - Create/Update:                                                │   │
│  │   • VPC (10.0.0.0/16 dev, 10.1.0.0/16 prod)                    │   │
│  │   • API Gateway (60+ endpoints)                                 │   │
│  │   • DynamoDB (users table)                                      │   │
│  │   • S3 (data lakes + frontend bucket)                           │   │
│  │   • KMS (encryption keys)                                       │   │
│  │   • IAM (Lambda execution role)                                 │   │
│  │ - Export: api_gateway_url.txt                                   │   │
│  │ - Output: infrastructure_output artifact                        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                             ↓                                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Stage 3: Build Lambdas (Parallel Execution)                     │   │
│  │                                                                  │   │
│  │  ┌──────────────────────────┐  ┌──────────────────────────┐   │   │
│  │  │ Java Lambda Build        │  │ Python Lambdas Build     │   │   │
│  │  │ - CodeBuild: java-lambda │  │ - CodeBuild: python-     │   │   │
│  │  │ - Maven build            │  │   lambdas                │   │   │
│  │  │ - Package JAR            │  │ - pip install deps       │   │   │
│  │  │ - Deploy:                │  │ - zip packages           │   │   │
│  │  │   • auth-service         │  │ - Deploy:                │   │   │
│  │  │                          │  │   • analytics-service    │   │   │
│  │  │                          │  │   • market-intelligence  │   │   │
│  │  │                          │  │   • demand-insights      │   │   │
│  │  │                          │  │   • compliance-guardian  │   │   │
│  │  │                          │  │   • retail-copilot       │   │   │
│  │  │                          │  │   • global-market-pulse  │   │   │
│  │  └──────────────────────────┘  └──────────────────────────┘   │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                             ↓                                             │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Stage 4: Build Frontend                                          │   │
│  │ - CodeBuild Project: frontend                                   │   │
│  │ - Read API Gateway URL from infrastructure_output               │   │
│  │ - Create .env.production with API URL                           │   │
│  │ - npm ci (install dependencies)                                 │   │
│  │ - npm run build (Vite build)                                    │   │
│  │ - aws s3 sync dist/ to frontend bucket                          │   │
│  │ - Invalidate CloudFront cache (if exists)                       │   │
│  │ - Output: frontend_output artifact                              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────────────┐
│                         Deployed Resources                               │
│                                                                           │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐     │
│  │  API Gateway     │  │  Lambda Functions│  │  S3 Frontend     │     │
│  │  /dev or /prod   │  │  (7 functions)   │  │  Static Website  │     │
│  │  60+ endpoints   │  │  - Auth (Java)   │  │  React App       │     │
│  │                  │  │  - 6 AI (Python) │  │                  │     │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘     │
│                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### GitHub Integration
- **Connection Type**: AWS CodeStar Connection
- **Authentication**: OAuth (requires manual approval on first deployment)
- **Trigger**: Automatic on commit or PR merge to master branch
- **Repository**: https://github.com/futureimadmin/hackathons.git
- **Branch**: master

### CodePipeline Stages

#### 1. Source Stage
- **Provider**: CodeStarSourceConnection
- **Action**: Pull code from GitHub
- **Output**: source_output artifact (entire repository)
- **Trigger**: Automatic via webhook

#### 2. Infrastructure Stage
- **Provider**: CodeBuild
- **Project**: futureim-ecommerce-ai-platform-infrastructure-{env}
- **Runtime**: Amazon Linux 2, Python 3.11
- **Build Time**: ~5-8 minutes
- **Actions**:
  1. Download and install Terraform 1.6.6
  2. Initialize Terraform with S3 backend
  3. Plan changes with appropriate tfvars file
  4. Apply changes automatically
  5. Export API Gateway URL to artifact
- **Outputs**: 
  - infrastructure_output artifact (api_gateway_url.txt)
  - All AWS resources created/updated

#### 3. Build Lambdas Stage (Parallel)

##### Java Lambda Build
- **Provider**: CodeBuild
- **Project**: futureim-ecommerce-ai-platform-java-lambda-{env}
- **Runtime**: Amazon Linux 2, Java 17
- **Build Time**: ~3-5 minutes
- **Actions**:
  1. Maven clean package
  2. Create deployment package
  3. Create or update Lambda function
- **Output**: java_lambda_output artifact

##### Python Lambdas Build
- **Provider**: CodeBuild
- **Project**: futureim-ecommerce-ai-platform-python-lambdas-{env}
- **Runtime**: Amazon Linux 2, Python 3.11
- **Build Time**: ~5-7 minutes
- **Actions**:
  1. For each AI system:
     - Install dependencies with pip
     - Create zip package
     - Create or update Lambda function
  2. Deploy all 6 Python Lambdas
- **Output**: python_lambdas_output artifact

#### 4. Build Frontend Stage
- **Provider**: CodeBuild
- **Project**: futureim-ecommerce-ai-platform-frontend-{env}
- **Runtime**: Amazon Linux 2, Node.js 18
- **Build Time**: ~3-5 minutes
- **Inputs**: 
  - source_output (code)
  - infrastructure_output (API Gateway URL)
- **Actions**:
  1. Read API Gateway URL from artifact
  2. Create .env.production with API URL
  3. Install npm dependencies
  4. Build React app with Vite
  5. Deploy to S3 bucket
  6. Invalidate CloudFront cache (if exists)
- **Output**: frontend_output artifact

### IAM Roles and Permissions

#### CodePipeline Role
- **Service**: codepipeline.amazonaws.com
- **Permissions**:
  - S3: Read/write artifacts bucket
  - CodeBuild: Start builds, get build status
  - CodeStar: Use GitHub connection

#### CodeBuild Role
- **Service**: codebuild.amazonaws.com
- **Permissions**:
  - CloudWatch Logs: Create log groups/streams, write logs
  - S3: Full access to project buckets
  - Lambda: Create, update, get functions
  - IAM: Full access (for Terraform)
  - EC2/VPC: Full access (for Terraform)
  - API Gateway: Full access (for Terraform)
  - DynamoDB: Full access (for Terraform)
  - KMS: Decrypt, describe keys
  - Secrets Manager: Full access (for Terraform)
  - Glue: Full access (for Terraform)

#### Lambda Execution Role
- **Service**: lambda.amazonaws.com
- **Permissions**:
  - CloudWatch Logs: Write logs
  - DynamoDB: Read/write tables
  - S3: Read/write buckets
  - Secrets Manager: Read secrets
  - KMS: Decrypt, generate data keys
  - VPC: Create/manage network interfaces

### S3 Buckets

#### Pipeline Artifacts Bucket
- **Name**: futureim-ecommerce-ai-platform-pipeline-artifacts-{env}
- **Purpose**: Store pipeline artifacts between stages
- **Encryption**: KMS with customer-managed key
- **Versioning**: Enabled
- **Lifecycle**: Artifacts retained for 30 days (configurable)

#### Frontend Bucket
- **Name**: futureim-ecommerce-ai-platform-frontend-{env}
- **Purpose**: Host React application
- **Configuration**: Static website hosting
- **Access**: Public read
- **Encryption**: AES256
- **Versioning**: Enabled
- **URL**: http://{bucket-name}.s3-website.us-east-2.amazonaws.com

### Secrets Management

#### GitHub Token
- **Storage**: AWS Secrets Manager
- **Name**: futureim-ecommerce-ai-platform-github-token-{env}
- **Encryption**: KMS with customer-managed key
- **Value**: GitHub Classic PAT with repo access
- **Usage**: Stored but not actively used (CodeStar connection uses OAuth)

### Environment Separation

#### DEV Environment
- **VPC CIDR**: 10.0.0.0/16
- **State File**: s3://...terraform-state/dev/terraform.tfstate
- **API Stage**: dev
- **Resources**: All prefixed with -dev
- **Pipeline**: futureim-ecommerce-ai-platform-pipeline-dev

#### PROD Environment
- **VPC CIDR**: 10.1.0.0/16
- **State File**: s3://...terraform-state/prod/terraform.tfstate
- **API Stage**: prod
- **Resources**: All prefixed with -prod
- **Pipeline**: futureim-ecommerce-ai-platform-pipeline-prod

## Data Flow

### Build Artifacts Flow
```
Source Stage
    ↓ (source_output)
Infrastructure Stage
    ↓ (source_output + infrastructure_output)
    ├─→ Java Lambda Build (source_output)
    └─→ Python Lambdas Build (source_output)
    ↓
Frontend Build (source_output + infrastructure_output)
```

### API Gateway URL Flow
```
Terraform Output
    ↓
api_gateway_url.txt (artifact)
    ↓
Frontend Build (reads file)
    ↓
.env.production (created)
    ↓
Vite Build (uses env var)
    ↓
React App (configured with API URL)
```

## Deployment Timeline

### First Deployment (Cold Start)
```
0:00 - Start terraform apply
0:01 - Create VPC, subnets, route tables
0:02 - Create KMS keys
0:03 - Create IAM roles
0:04 - Create DynamoDB table
0:05 - Create S3 buckets
0:08 - Create API Gateway
0:10 - Create CodePipeline resources
0:12 - Terraform apply complete
0:13 - Manual: Approve GitHub connection
0:15 - Trigger pipeline (manual or commit)
0:16 - Source stage (30 seconds)
0:17 - Infrastructure stage (5 minutes)
0:22 - Lambda builds (5 minutes, parallel)
0:27 - Frontend build (3 minutes)
0:30 - Deployment complete ✅
```

### Subsequent Deployments (Warm Start)
```
0:00 - Commit to master branch
0:01 - Pipeline triggered automatically
0:02 - Source stage (30 seconds)
0:03 - Infrastructure stage (2 minutes, no changes)
0:05 - Lambda builds (3 minutes, updates only)
0:08 - Frontend build (2 minutes)
0:10 - Deployment complete ✅
```

## Monitoring and Observability

### CloudWatch Logs
- **Log Groups**:
  - /aws/codebuild/futureim-ecommerce-ai-platform-infrastructure-{env}
  - /aws/codebuild/futureim-ecommerce-ai-platform-java-lambda-{env}
  - /aws/codebuild/futureim-ecommerce-ai-platform-python-lambdas-{env}
  - /aws/codebuild/futureim-ecommerce-ai-platform-frontend-{env}
  - /aws/lambda/futureim-ecommerce-ai-platform-*-{env}

### Pipeline Metrics
- **Available in**: CodePipeline console
- **Metrics**:
  - Pipeline execution time
  - Stage success/failure rates
  - Build duration per stage
  - Artifact sizes

### Cost Tracking
- **Tags Applied**:
  - Project: eCommerce-AI-Platform
  - Environment: dev/prod
  - ManagedBy: Terraform
  - System: CI/CD

## Security Features

### Encryption
- **At Rest**: All S3 buckets encrypted with KMS
- **In Transit**: HTTPS for all API calls
- **Secrets**: GitHub token in Secrets Manager with KMS

### Access Control
- **IAM Roles**: Least privilege principle
- **S3 Buckets**: Private by default (except frontend)
- **API Gateway**: CORS configured
- **VPC**: Private subnets for Lambda functions

### Compliance
- **Versioning**: Enabled on all critical buckets
- **Logging**: CloudWatch Logs for all builds
- **Audit Trail**: CloudTrail for API calls
- **Backup**: Terraform state versioned in S3

## Disaster Recovery

### Backup Strategy
- **Terraform State**: Versioned in S3, DynamoDB locking
- **S3 Buckets**: Versioning enabled
- **DynamoDB**: Point-in-time recovery enabled
- **Code**: Version controlled in GitHub

### Recovery Procedures
1. **Pipeline Failure**: Automatic retry, manual trigger
2. **Infrastructure Corruption**: Restore from Terraform state
3. **Data Loss**: Restore from S3 versions or DynamoDB backup
4. **Complete Failure**: Redeploy from Terraform configuration

## Scaling Considerations

### Current Limits
- **CodeBuild**: 60 concurrent builds (AWS default)
- **Lambda**: 1000 concurrent executions per region
- **API Gateway**: 10,000 requests per second
- **S3**: Unlimited storage, 5,500 requests/second per prefix

### Optimization Opportunities
- **CodeBuild**: Use larger compute types for faster builds
- **Lambda**: Configure reserved concurrency
- **API Gateway**: Enable caching
- **S3**: Use CloudFront CDN for frontend

---

**Architecture Status**: ✅ Production Ready
**Last Updated**: January 2026
**Version**: 1.0
