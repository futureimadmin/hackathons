# FutureIM eCommerce AI Platform

Enterprise-grade cloud infrastructure for AI-powered eCommerce analytics platform with automated CI/CD pipeline, data replication, and microservices architecture.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Infrastructure Modules](#infrastructure-modules)
4. [Deployment Architecture](#deployment-architecture)
5. [Prerequisites](#prerequisites)
6. [Quick Start](#quick-start)
7. [CloudFormation Stack Management](#cloudformation-stack-management)
8. [Configuration](#configuration)
9. [Post-Deployment](#post-deployment)
10. [Troubleshooting](#troubleshooting)

---

## Overview

### Purpose
Cloud infrastructure for 5 AI systems analyzing eCommerce data:
- **Compliance Guardian** - Regulatory compliance monitoring
- **Demand Insights Engine** - Demand forecasting and analytics
- **Global Market Pulse** - Market sentiment analysis
- **Market Intelligence Hub** - Competitive intelligence
- **Retail Copilot** - AI-powered retail assistant

### Technology Stack
- **Infrastructure**: Terraform 1.5+, AWS
- **Backend**: Java 17 (Auth), Python 3.11 (AI Systems)
- **Frontend**: React 18, Node.js 18
- **Data**: MySQL 8.0 → AWS DMS → S3 (Parquet) → Athena
- **CI/CD**: CodePipeline V2, CodeBuild, GitHub

### Key Features
- Automated CI/CD with GitHub integration
- Real-time data replication (MySQL → S3)
- API Gateway with 60+ endpoints
- Multi-AZ deployment
- KMS encryption at rest
- Auto-scaling Lambda functions

---

## Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
│              futureimadmin/hackathons (master)               │
└────────────────────────┬────────────────────────────────────┘
                         │ Auto-trigger on push
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              CodePipeline V2 (4 Stages)                      │
│  Source → Infrastructure → Build Lambdas → Build Frontend   │
└────────────────────────┬────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    ┌────────┐    ┌──────────┐    ┌──────────┐
    │  VPC   │    │   DMS    │    │   API    │
    │Subnets │    │Replication│   │ Gateway  │
    └────────┘    └──────────┘    └──────────┘
         │               │               │
         └───────────────┼───────────────┘
                         ▼
              ┌──────────────────────┐
              │   5 AI Systems       │
              │   Lambda Functions   │
              └──────────────────────┘
```

### Data Flow Architecture

```
On-Premise MySQL (172.20.10.4)
         │
         │ DMS Replication (Full Load + CDC)
         ▼
DMS Replication Instance (dms.t3.medium)
         │
         │ Parquet Files (Compressed + Encrypted)
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    S3 Data Buckets                           │
│  • compliance-guardian-data-dev                              │
│  • demand-insights-engine-data-dev                           │
│  • global-market-pulse-data-dev                              │
│  • market-intelligence-hub-data-dev                          │
│  • retail-copilot-data-dev                                   │
└────────────────────────┬────────────────────────────────────┘
                         │ Glue Crawlers
                         ▼
                  AWS Glue Data Catalog
                         │
                         │ SQL Queries
                         ▼
                   Amazon Athena
```

### Network Architecture

```
VPC (10.0.0.0/16)
│
├─ Public Subnets
│  ├─ 10.0.1.0/24 (us-east-2a)
│  ├─ 10.0.2.0/24 (us-east-2b)
│  └─ Resources: NAT Gateway, Internet Gateway
│
└─ Private Subnets
   ├─ 10.0.11.0/24 (us-east-2a)
   ├─ 10.0.12.0/24 (us-east-2b)
   └─ Resources: DMS, Lambda Functions, RDS (future)
```

---

## Infrastructure Modules

### 1. VPC Module (`modules/vpc/`)
**Purpose**: Network foundation with public/private subnets

**Resources Created**:
- VPC with CIDR 10.0.0.0/16
- 2 Public subnets (Multi-AZ)
- 2 Private subnets (Multi-AZ)
- Internet Gateway
- NAT Gateway
- Route tables
- Security groups (DMS, Lambda, VPC endpoints)

**Outputs**: VPC ID, subnet IDs, security group IDs

---

### 2. KMS Module (`modules/kms/`)
**Purpose**: Encryption key management

**Resources Created**:
- KMS key for encryption at rest
- Key policy for service access
- Key alias

**Used By**: S3, DMS, Secrets Manager, CloudWatch Logs

---

### 3. IAM Module (`modules/iam/`)
**Purpose**: Identity and access management

**Resources Created**:
- Lambda execution role
- CodePipeline role
- CodeBuild role
- DMS service roles
- S3 access policies

**Permissions**: Least privilege access for each service

---

### 4. S3 Data Lake Modules (`modules/s3-data-lake/`)
**Purpose**: Data storage for each AI system

**Resources Created** (per AI system):
- Raw data bucket (Parquet files from DMS)
- Processed data bucket (transformed data)
- Archive bucket (historical data)
- Bucket policies
- Lifecycle rules
- Versioning enabled
- KMS encryption

**Total**: 15 S3 buckets (5 systems × 3 buckets each)

---

### 5. DMS Module (`modules/dms/`)
**Purpose**: Real-time data replication from MySQL to S3

**Resources Created**:
- DMS replication instance (dms.t3.medium)
- Source endpoint (MySQL at 172.20.10.4)
- 5 Target endpoints (S3 buckets)
- 5 Replication tasks (one per AI system)
- IAM roles for S3 access
- CloudWatch log group

**Configuration**:
- Engine version: 3.5.4
- Format: Parquet (compressed with GZIP)
- Mode: Full Load + CDC (Change Data Capture)
- Encryption: SSE-KMS

**Data Flow**:
```
MySQL Table → DMS Task → S3 Bucket (Parquet)
ecommerce.compliance_* → compliance-guardian-data-dev
ecommerce.demand_* → demand-insights-engine-data-dev
ecommerce.market_pulse_* → global-market-pulse-data-dev
ecommerce.market_intel_* → market-intelligence-hub-data-dev
ecommerce.copilot_* → retail-copilot-data-dev
```

---

### 6. API Gateway Module (`modules/api-gateway/`)
**Purpose**: REST API for all microservices

**Resources Created**:
- REST API Gateway
- 60+ API endpoints across 6 services
- CloudWatch Logs role
- API deployment (dev stage)

**Endpoints**:
- `/auth` - Authentication (login, register, refresh)
- `/compliance-guardian` - Compliance analysis
- `/demand-insights` - Demand forecasting
- `/market-pulse` - Market sentiment
- `/market-intelligence` - Competitive intelligence
- `/retail-copilot` - AI assistant

**Integration**: Lambda functions (placeholder ARNs for now)

---

### 7. CI/CD Pipeline Module (`modules/cicd-pipeline/`)
**Purpose**: Automated deployment pipeline

**Resources Created**:
- CodePipeline V2 (auto-trigger enabled)
- 4 CodeBuild projects:
  - Infrastructure (Terraform apply)
  - Java Lambda (Auth service)
  - Python Lambdas (5 AI systems)
  - Frontend (React build + S3 deploy)
- S3 artifacts bucket
- CodeStar GitHub connection
- Secrets Manager (GitHub token)

**Pipeline Stages**:
1. **Source**: GitHub → S3 artifacts
2. **Infrastructure**: Deploy Terraform changes
3. **Build Lambdas**: Compile and deploy functions (parallel)
4. **Build Frontend**: Build React app → Deploy to S3

**Features**:
- Auto-triggers on GitHub push
- Retry individual stages
- Parallel Lambda builds
- KMS-encrypted artifacts

---

### 8. S3 Frontend Module (`modules/s3-frontend/`)
**Purpose**: Static website hosting for React frontend

**Resources Created**:
- S3 bucket with website hosting
- Bucket policy for public read
- CORS configuration

**URL**: `http://futureim-ecommerce-ai-platform-frontend-dev.s3-website.us-east-2.amazonaws.com`

---

## Deployment Architecture

### CI/CD Pipeline Flow

```
Developer Push to GitHub
         ↓
CodePipeline Auto-Triggers (V2)
         ↓
┌────────────────────────────────────────┐
│ Stage 1: Source                        │
│ • Clone from GitHub                    │
│ • Upload to S3 artifacts bucket        │
└────────────┬───────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│ Stage 2: Infrastructure                │
│ • Run Terraform plan                   │
│ • Apply infrastructure changes         │
│ • Update VPC, DMS, API Gateway, etc.   │
└────────────┬───────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│ Stage 3: Build Lambdas (Parallel)      │
│ ┌──────────────┐  ┌─────────────────┐ │
│ │ Java Lambda  │  │ Python Lambdas  │ │
│ │ (Auth)       │  │ (5 AI Systems)  │ │
│ │ • mvn package│  │ • pip install   │ │
│ │ • Deploy     │  │ • zip & deploy  │ │
│ └──────────────┘  └─────────────────┘ │
└────────────┬───────────────────────────┘
             ↓
┌────────────────────────────────────────┐
│ Stage 4: Build Frontend                │
│ • npm install                          │
│ • npm run build                        │
│ • aws s3 sync to frontend bucket       │
└────────────────────────────────────────┘
```

### Deployment Environments

| Environment | Region    | VPC CIDR    | DMS Instance  |
|-------------|-----------|-------------|---------------|
| Development | us-east-2 | 10.0.0.0/16 | dms.t3.medium |
| Production  | us-east-2 | 10.1.0.0/16 | dms.c5.xlarge |

---

## Prerequisites

### Required Tools
- Terraform 1.5+
- AWS CLI configured
- Git
- PowerShell (Windows) or Bash (Linux/Mac)

### AWS Account Requirements
- Account ID: 450133579764
- Region: us-east-2
- IAM permissions for all services

### External Dependencies
- MySQL server: 172.20.10.4:3306
- Database: ecommerce
- User: dms_remote
- Password: (stored in Secrets Manager)

---

## Quick Start

### 🚀 **Recommended: CloudFormation Stack Deployment**

**Use this approach for complete stack management and easy cleanup.**

#### **Step 1: Deploy Complete Environment**
```powershell
# Deploy dev environment with CloudFormation stack
.\cloudformation\deploy-stack.ps1 -Environment dev -GitHubToken "your_github_token"

# Deploy prod environment
.\cloudformation\deploy-stack.ps1 -Environment prod -GitHubToken "your_github_token"
```

#### **Step 2: Check Stack Status**
```powershell
# Basic status
.\cloudformation\stack-status.ps1 -Environment dev

# Detailed status with resources and events
.\cloudformation\stack-status.ps1 -Environment dev -Detailed
```

#### **Step 3: Complete GitHub Connection**
1. Go to AWS Console → CodePipeline → Settings → Connections
2. Find connection named `futureim-github-dev`
3. Click "Update pending connection" and authorize with GitHub

#### **Step 4: When You Need to Start Fresh**
```powershell
# Delete EVERYTHING (complete cleanup)
.\cloudformation\delete-stack.ps1 -Environment dev

# Recreate fresh environment
.\cloudformation\deploy-stack.ps1 -Environment dev -GitHubToken "your_github_token"
```

**Benefits of CloudFormation Approach:**
- ✅ **Complete resource management** - All resources tracked as single unit
- ✅ **Easy cleanup** - Delete stack = delete ALL resources
- ✅ **No orphaned resources** - CloudFormation tracks everything
- ✅ **Perfect for development** - Create/delete environments easily
- ✅ **No prerequisites** - All Terraform dependencies included automatically
- ✅ **One-step deployment** - No need for separate setup scripts

---

### 🔧 **Alternative: Traditional Terraform Deployment**

**Use this if you prefer direct Terraform management.**

### Step 1: One-Time Prerequisites (Terraform Only)

These create resources that Terraform depends on. Run these scripts from the `terraform/` directory:

```powershell
cd terraform

# 1. Create Terraform backend (S3 + DynamoDB)
.\create-backend-resources.ps1

# 2. Create DMS VPC role (AWS requirement)
.\create-dms-vpc-role.ps1

# 3. Create MySQL password secret
.\create-mysql-secret.ps1
```

**Available Scripts**:
- `create-backend-resources.ps1` - Creates S3 bucket and DynamoDB table for Terraform state
- `create-dms-vpc-role.ps1` - Creates required IAM role for DMS VPC management
- `create-mysql-secret.ps1` - Creates Secrets Manager secret for MySQL password

**Important**: Copy the secret ARN from step 3 output.

---

### Step 2: Configure Variables (Terraform Only)

Edit `terraform/terraform.dev.tfvars`:

```hcl
aws_region   = "us-east-2"
environment  = "dev"
project_name = "futureim-ecommerce-ai-platform"
vpc_cidr     = "10.0.0.0/16"

# GitHub Configuration
github_repo   = "futureimadmin/hackathons"
github_branch = "master"
github_token  = "github_pat_YOUR_TOKEN_HERE"

# MySQL Secret (from step 1.3)
mysql_password_secret_arn = "arn:aws:secretsmanager:us-east-2:450133579764:secret:..."
```

---

### Step 3: Deploy Infrastructure (Terraform Only)

```powershell
# Initialize Terraform
terraform init

# Review changes
terraform plan -var-file="terraform.dev.tfvars"

# Deploy (type 'yes' when prompted)
terraform apply -var-file="terraform.dev.tfvars"
```

**Deployment Time**: ~20-25 minutes

---

### Step 4: Post-Deployment Configuration (Both Methods)

#### Activate GitHub Connection
1. Go to AWS Console → Developer Tools → Connections
2. Find: `futureim-github-dev`
3. Click "Update pending connection"
4. Authorize GitHub access
5. Status should change to "AVAILABLE"

#### Start DMS Replication Tasks
```powershell
# List tasks
aws dms describe-replication-tasks --query 'ReplicationTasks[].ReplicationTaskIdentifier'

# Start each task
aws dms start-replication-task \
  --replication-task-arn <task-arn> \
  --start-replication-task-type start-replication
```

Or use AWS Console: DMS → Database migration tasks → Select task → Actions → Start

---

## CloudFormation Stack Management

### 📋 **Available CloudFormation Scripts**

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `deploy-stack.ps1` | Deploy complete environment | Initial setup, updates, recreating environment |
| `delete-stack.ps1` | Delete complete environment | Cleanup, starting fresh, cost savings |
| `stack-status.ps1` | Check stack status | Monitoring, troubleshooting, resource verification |

### 🚀 **Deployment Scenarios**

#### **Scenario 1: First Time Setup**
```powershell
# Deploy complete dev environment
.\cloudformation\deploy-stack.ps1 -Environment dev -GitHubToken "your_token"

# Check deployment status
.\cloudformation\stack-status.ps1 -Environment dev -Detailed

# Complete GitHub connection (one-time)
# AWS Console → CodePipeline → Settings → Connections → Authorize
```

#### **Scenario 2: Daily Development**
```powershell
# Environment already exists - just develop and commit
git add .
git commit -m "New feature"
git push origin master

# Pipeline auto-triggers and deploys changes
# Monitor: .\cloudformation\stack-status.ps1 -Environment dev
```

#### **Scenario 3: Clean Slate (Start Fresh)**
```powershell
# Delete everything
.\cloudformation\delete-stack.ps1 -Environment dev

# Recreate fresh environment
.\cloudformation\deploy-stack.ps1 -Environment dev -GitHubToken "your_token"
```

#### **Scenario 4: Production Deployment**
```powershell
# Deploy to production
.\cloudformation\deploy-stack.ps1 -Environment prod -GitHubToken "your_token"

# Verify production deployment
.\cloudformation\stack-status.ps1 -Environment prod -Detailed
```

#### **Scenario 5: Cost Optimization**
```powershell
# Delete dev environment when not in use (saves costs)
.\cloudformation\delete-stack.ps1 -Environment dev

# Recreate when needed
.\cloudformation\deploy-stack.ps1 -Environment dev -GitHubToken "your_token"
```

### 🔧 **Advanced Usage**

#### **Custom Parameters**
```powershell
# Deploy with custom settings
.\cloudformation\deploy-stack.ps1 `
  -Environment dev `
  -GitHubToken "your_token" `
  -ProjectName "my-custom-project" `
  -VpcCidr "172.16.0.0/16" `
  -MySQLServerIP "172.20.10.2" `
  -Region "us-west-2"
```

#### **Force Delete (Skip Confirmation)**
```powershell
# Delete without confirmation prompt
.\cloudformation\delete-stack.ps1 -Environment dev -Force
```

#### **Monitor Stack Events**
```powershell
# Watch stack deployment in real-time
.\cloudformation\stack-status.ps1 -Environment dev -Detailed

# Check specific resources
aws cloudformation list-stack-resources --stack-name futureim-ecommerce-ai-platform-dev
```

### 🎯 **When to Use Each Approach**

#### **Use CloudFormation When:**
- ✅ You want complete resource management
- ✅ You need easy environment cleanup
- ✅ You're doing development/testing
- ✅ You want to avoid orphaned resources
- ✅ You need consistent environment recreation
- ✅ You want to skip Terraform prerequisite scripts
- ✅ You prefer one-command deployment

#### **Use Direct Terraform When:**
- ✅ You need fine-grained control
- ✅ You're integrating with existing Terraform workflows
- ✅ You want to manage state files directly
- ✅ You're doing infrastructure-as-code development

### 🛠️ **Troubleshooting CloudFormation**

#### **Stack Creation Failed**
```powershell
# Check detailed status
.\cloudformation\stack-status.ps1 -Environment dev -Detailed

# View events in AWS Console
# CloudFormation → Stacks → [StackName] → Events
```

#### **Stack Deletion Failed**
```powershell
# Check for resources preventing deletion
aws cloudformation describe-stack-resources --stack-name futureim-ecommerce-ai-platform-dev

# Manually empty S3 buckets if needed
aws s3 rm s3://bucket-name --recursive

# Retry deletion
.\cloudformation\delete-stack.ps1 -Environment dev -Force
```

#### **GitHub Connection Issues**
```powershell
# Deploy stack first
.\cloudformation\deploy-stack.ps1 -Environment dev -GitHubToken "your_token"

# Then manually complete connection in AWS Console
# CodePipeline → Settings → Connections → Update pending connection
```

---

## Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `aws_region` | AWS region | us-east-2 |
| `environment` | Environment name | dev, prod |
| `project_name` | Project prefix | futureim-ecommerce-ai-platform |
| `vpc_cidr` | VPC CIDR block | 10.0.0.0/16 |
| `github_repo` | GitHub repository | futureimadmin/hackathons |
| `github_branch` | Git branch | master |
| `github_token` | GitHub PAT | github_pat_... |
| `mysql_password_secret_arn` | Secret ARN | arn:aws:secretsmanager:... |

### MySQL Configuration

**Current Settings:**
- **Host**: 172.20.10.2
- **Port**: 3306
- **User**: dms_remote
- **Database**: ecommerce

**Security Note**: We use a dedicated `dms_remote` user with minimal privileges (not root) for better security.

#### **Updating MySQL IP Address**

If your MySQL server IP changes, use the automated update script:

```powershell
# Update IP address across all configurations
.\update-mysql-ip.ps1 -NewMySQLIP "172.20.10.3" -Environment dev
```

This script updates:
- ✅ Terraform variables
- ✅ CloudFormation stack parameters  
- ✅ Security group rules
- ✅ DMS endpoint configuration

**Manual MySQL User Setup:**
```sql
-- Connect to MySQL as root and create DMS user
CREATE USER 'dms_remote'@'172.20.10.2' IDENTIFIED BY 'secure_password';
GRANT REPLICATION SLAVE ON *.* TO 'dms_remote'@'172.20.10.2';
GRANT SELECT ON ecommerce.* TO 'dms_remote'@'172.20.10.2';
FLUSH PRIVILEGES;
```

See `docs/deployment/MYSQL_DMS_USER_SETUP.md` for detailed setup instructions.

Located in `terraform/terraform.dev.tfvars`:

```hcl
dms_replication_tasks = [
  {
    task_id = "compliance-guardian-replication"
    migration_type = "full-load-and-cdc"
    target_bucket = "compliance-guardian"
    table_mappings = jsonencode({
      rules = [{
        rule-type = "selection"
        rule-id = "1"
        rule-name = "compliance-tables"
        object-locator = {
          schema-name = "ecommerce"
          table-name = "compliance_%"
        }
        rule-action = "include"
      }]
    })
  },
  # ... 4 more tasks
]
```

---

## Post-Deployment

### Verify Deployment

```powershell
# Check DMS instance
terraform output dms_replication_instance_id

# Check API Gateway
terraform output api_gateway_url

# Check frontend URL
terraform output frontend_url

# Check pipeline
aws codepipeline get-pipeline-state \
  --name futureim-ecommerce-ai-platform-pipeline-dev
```

### Test Pipeline Auto-Trigger

```powershell
# Make a change
git add .
git commit -m "Test pipeline"
git push origin master

# Pipeline should start within 1-2 minutes
# Check: AWS Console → CodePipeline
```

### Monitor DMS Replication

```powershell
# Check task status
aws dms describe-replication-tasks \
  --query 'ReplicationTasks[].{ID:ReplicationTaskIdentifier,Status:Status}'

# View CloudWatch logs
# AWS Console → CloudWatch → Log groups → /aws/dms/futureim-ecommerce-ai-platform-dev
```

---

## Troubleshooting

### Terraform State Lock

**Error**: `Error acquiring the state lock`

**Solution**:
```powershell
terraform force-unlock <LOCK_ID>
```

### DMS VPC Role Error

**Error**: `The IAM Role arn:aws:iam::450133579764:role/dms-vpc-role is not configured properly`

**Solution**:
```powershell
.\create-dms-vpc-role.ps1
```

### GitHub Connection Pending

**Error**: Pipeline fails at Source stage

**Solution**: Activate connection in AWS Console (see Step 4 above)

### DMS Replication Not Starting

**Error**: Tasks created but not running

**Solution**: Start tasks manually (see Step 4 above)

### Pipeline Not Auto-Triggering

**Check**:
1. GitHub connection status = AVAILABLE
2. Pipeline type = V2
3. DetectChanges = true

**Verify**:
```powershell
aws codepipeline get-pipeline \
  --name futureim-ecommerce-ai-platform-pipeline-dev \
  --query 'metadata.pipelineType'
```

---

## Resource Naming Convention

All resources follow: `{project_name}-{resource_type}-{environment}`

Examples:
- `futureim-ecommerce-ai-platform-pipeline-dev`
- `futureim-ecommerce-ai-platform-auth-dev`
- `futureim-ecommerce-ai-platform-frontend-dev`

---

## Security

### Encryption
- **At Rest**: KMS encryption for S3, DMS, Secrets Manager, CloudWatch
- **In Transit**: HTTPS/TLS for all API calls

### Access Control
- IAM roles with least privilege
- Private subnets for sensitive resources
- Security groups with minimal ports
- VPC endpoints for AWS services

### Secrets Management
- GitHub token: Secrets Manager
- MySQL password: Secrets Manager
- No secrets in code or version control

---

## Cost Optimization

### Current Resources
- DMS: dms.t3.medium (~$0.20/hour)
- Lambda: Pay per invocation
- S3: Pay per GB stored
- API Gateway: Pay per request
- CodePipeline: $1/month per pipeline

### Recommendations
- Stop DMS instance when not replicating
- Use S3 lifecycle policies for old data
- Monitor Lambda concurrency limits
- Review CloudWatch log retention

---

## Future Enhancements

1. CloudFront distribution for frontend
2. WAF for API Gateway protection
3. Cognito for user authentication
4. RDS for application database
5. ElastiCache for caching
6. Step Functions for orchestration
7. EventBridge for event-driven architecture
8. SageMaker for ML model deployment

---

## Quick Reference

### 🚀 **Most Common Commands**

```powershell
# Deploy dev environment
.\cloudformation\deploy-stack.ps1 -Environment dev -GitHubToken "your_token"

# Check status
.\cloudformation\stack-status.ps1 -Environment dev

# Delete environment (save costs)
.\cloudformation\delete-stack.ps1 -Environment dev

# Update MySQL IP
.\update-mysql-ip.ps1 -NewMySQLIP "172.20.10.2" -Environment dev
```

### 📋 **File Structure**

```
├── cloudformation/                 # CloudFormation stack management
│   ├── deploy-stack.ps1           # Deploy complete environment
│   ├── delete-stack.ps1           # Delete complete environment
│   ├── stack-status.ps1           # Check stack status
│   └── ecommerce-ai-platform-stack.yaml  # CloudFormation template
├── terraform/                     # Terraform infrastructure
│   ├── main.tf                    # Main configuration
│   ├── variables.tf               # Variable definitions
│   └── modules/                   # Reusable modules
├── docs/deployment/               # Deployment guides
│   ├── MYSQL_DMS_USER_SETUP.md   # MySQL security setup
│   └── PIPELINE_AUTO_TRIGGER_SETUP.md  # CI/CD configuration
├── update-mysql-ip.ps1           # MySQL IP update script
└── README.md                     # This file
```

### 🎯 **Decision Matrix: CloudFormation vs Terraform**

| Need | CloudFormation | Direct Terraform |
|------|----------------|------------------|
| Easy cleanup | ✅ Perfect | ❌ Manual cleanup |
| Dev/test environments | ✅ Ideal | ⚠️ Complex |
| Production stability | ✅ Good | ✅ Excellent |
| Fine-grained control | ⚠️ Limited | ✅ Full control |
| Learning curve | ✅ Simple | ⚠️ Moderate |
| Resource tracking | ✅ Automatic | ⚠️ Manual |

**Recommendation**: Use CloudFormation for development and testing, consider direct Terraform for production.

---

## Support

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section
2. Review AWS CloudWatch Logs
3. Check Terraform error messages
4. Review AWS Console for resource status

---

## License

Proprietary - FutureIM

---

**Last Updated**: January 2026  
**Version**: 1.0  
**Status**: Production Ready
