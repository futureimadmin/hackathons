# FutureIM eCommerce AI Analytics Platform

**Enterprise-grade cloud infrastructure for AI-powered eCommerce analytics**

---

## 🚀 Quick Start

```powershell
# Step 1: Run prerequisite scripts
cd terraform
.\create-backend-resources.ps1
.\create-dms-vpc-role.ps1
.\create-mysql-secret.ps1 -MySQLPassword "your_password"

# Step 2: Configure Terraform
# Edit terraform/terraform.dev.tfvars with your values

# Step 3: Deploy infrastructure
terraform init -backend-config=backend.tfvars
terraform apply -var-file="terraform.dev.tfvars"

# Step 4: Complete GitHub connection in AWS Console
# CodePipeline → Settings → Connections → Authorize

# Done! Your platform is ready.
```

**Deployment Time:** 20-25 minutes

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Modules](#modules)
4. [Quick Start](#quick-start-guide)
5. [Configuration](#configuration)
6. [Operations](#operations)
7. [Troubleshooting](#troubleshooting)

---

## Overview

### What is This Platform?

The FutureIM eCommerce AI Platform provides 5 specialized AI systems that analyze eCommerce data and deliver actionable insights:

1. **Market Intelligence Hub** - Forecasting and market analytics
2. **Demand Insights Engine** - Customer insights and demand forecasting
3. **Compliance Guardian** - Fraud detection and compliance monitoring
4. **Retail Copilot** - AI-powered assistant for retail teams
5. **Global Market Pulse** - Global market trends and opportunities

### Key Features

- ✅ **Automated CI/CD** - Push to GitHub, auto-deploy to AWS
- ✅ **Real-time Data Replication** - MySQL → S3 via DMS
- ✅ **Scalable Architecture** - Serverless Lambda functions
- ✅ **Secure by Design** - KMS encryption, VPC isolation
- ✅ **Production Ready** - Monitoring, logging, error handling

### Technology Stack

| Layer | Technologies |
|-------|-------------|
| **Infrastructure** | AWS, Terraform, CloudFormation |
| **Backend** | Java 17 (Auth), Python 3.11 (AI Systems) |
| **Frontend** | React 18, TypeScript, Vite, Material-UI |
| **Database** | MySQL 9.6 (on-premises) |
| **Data Pipeline** | DMS, S3, Glue, Athena |
| **CI/CD** | CodePipeline, CodeBuild, GitHub |
| **Monitoring** | CloudWatch, CloudTrail |

---

## Architecture

### High-Level Architecture

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

### Data Flow

```
MySQL (172.20.10.2) → DMS → S3 (Parquet) → Glue → Athena → Lambda → API Gateway → Frontend
```

### Network Architecture

```
VPC (10.0.0.0/16)
├─ Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│  └─ NAT Gateway, Internet Gateway
└─ Private Subnets (10.0.11.0/24, 10.0.12.0/24)
   └─ DMS, Lambda Functions
```

---

## Modules

### 1. AI Systems (5 Lambda Functions)

#### Market Intelligence Hub
**Purpose:** Time series forecasting and market analytics

**Features:**
- ARIMA, Prophet, LSTM forecasting models
- Automatic model selection
- Confidence intervals
- Performance metrics (RMSE, MAE, MAPE, R²)

**API Endpoints:**
- `POST /market-intelligence/forecast` - Generate forecasts
- `POST /market-intelligence/compare-models` - Compare model performance
- `GET /market-intelligence/trends` - Get market trends

**Tech Stack:** Python 3.11, scikit-learn, Prophet, TensorFlow

**Location:** `ai-systems/market-intelligence-hub/`

---

#### Demand Insights Engine
**Purpose:** Customer insights, demand forecasting, pricing optimization

**Features:**
- Customer segmentation (K-Means, RFM analysis)
- Demand forecasting (XGBoost)
- Price elasticity analysis
- Customer lifetime value (CLV) prediction
- Churn prediction

**API Endpoints:**
- `GET /demand-insights/segments` - Customer segmentation
- `POST /demand-insights/forecast` - Demand forecasting
- `POST /demand-insights/price-elasticity` - Price elasticity
- `POST /demand-insights/clv` - CLV prediction
- `POST /demand-insights/churn` - Churn prediction

**Tech Stack:** Python 3.11, XGBoost, scikit-learn, pandas

**Location:** `ai-systems/demand-insights-engine/`

---

#### Compliance Guardian
**Purpose:** Fraud detection, risk scoring, PCI DSS compliance

**Features:**
- Fraud detection (Isolation Forest)
- Risk scoring (Gradient Boosting)
- PCI DSS compliance monitoring
- Document understanding (NLP with transformers)
- Credit card masking

**API Endpoints:**
- `POST /compliance/fraud-detection` - Detect fraudulent transactions
- `POST /compliance/risk-score` - Calculate risk scores
- `GET /compliance/high-risk-transactions` - Get high-risk transactions
- `POST /compliance/pci-compliance` - Check PCI DSS compliance
- `GET /compliance/compliance-report` - Generate compliance report

**Tech Stack:** Python 3.11, scikit-learn, XGBoost, transformers

**Location:** `ai-systems/compliance-guardian/`

---

#### Retail Copilot
**Purpose:** AI-powered assistant for retail teams

**Features:**
- Natural language chat interface
- Natural language to SQL conversion
- Microsoft Copilot-like behavior
- Conversation history
- Product recommendations
- Sales reports

**API Endpoints:**
- `POST /copilot/chat` - Chat with copilot
- `GET /copilot/conversations` - Get conversation history
- `POST /copilot/conversation` - Create new conversation
- `GET /copilot/inventory` - Query inventory
- `GET /copilot/orders` - Query orders
- `POST /copilot/recommendations` - Get product recommendations

**Tech Stack:** Python 3.11, AWS Bedrock (Claude), boto3

**Location:** `ai-systems/retail-copilot/`

---

#### Global Market Pulse
**Purpose:** Global market trends and expansion opportunities

**Features:**
- Market trend analysis (time series decomposition)
- Regional price comparison
- Market opportunity scoring (MCDA)
- Competitor analysis
- Currency conversion support

**API Endpoints:**
- `GET /global-market/trends` - Market trends
- `GET /global-market/regional-prices` - Regional prices
- `POST /global-market/price-comparison` - Compare prices
- `POST /global-market/opportunities` - Market opportunities
- `POST /global-market/competitor-analysis` - Competitor analysis

**Tech Stack:** Python 3.11, scipy, statsmodels, pandas

**Location:** `ai-systems/global-market-pulse/`

---

### 2. Analytics Service

**Purpose:** Execute Athena queries and provide analytics endpoints

**Features:**
- Secure query execution with SQL injection prevention
- JWT authentication
- Multi-system support
- Athena integration

**API Endpoints:**
- `GET /analytics/{system}/query` - Execute Athena query
- `POST /analytics/{system}/forecast` - Generate forecast
- `GET /analytics/{system}/insights` - Get insights

**Tech Stack:** Python 3.11, boto3, PyAthena, pandas

**Location:** `analytics-service/`

---

### 3. Authentication Service

**Purpose:** User authentication and authorization

**Features:**
- User registration with email validation
- User login with JWT token generation
- Password reset via email
- JWT token verification
- Secure password hashing (BCrypt)

**API Endpoints:**
- `POST /auth/register` - Register new user
- `POST /auth/login` - Login and get JWT token
- `POST /auth/forgot-password` - Request password reset
- `POST /auth/reset-password` - Reset password
- `POST /auth/verify` - Verify JWT token

**Tech Stack:** Java 17, AWS Lambda, DynamoDB, Secrets Manager, SES

**Location:** `auth-service/`

---

### 4. Frontend Application

**Purpose:** React-based dashboard for all AI systems

**Features:**
- User authentication (login, register, forgot password)
- JWT token management
- Home page with 5 system cards
- Protected routes
- Dashboard navigation
- Responsive design

**Tech Stack:** React 18, TypeScript, Vite, Material-UI, React Router

**Location:** `frontend/`

---

### 5. Data Processing Pipeline

**Purpose:** Validate, transform, and optimize data for analytics

**Features:**
- Raw to curated processing (validation, deduplication, compliance)
- Curated to prod processing (transformation, optimization)
- Schema validation
- Business rules validation
- PCI DSS compliance checks

**Tech Stack:** Python 3.11, pandas, pyarrow, Docker, AWS Batch

**Location:** `data-processing/`

---

### 6. Infrastructure (Terraform)

**Purpose:** Infrastructure as Code for all AWS resources

**Modules:**
- **VPC** - Network foundation with public/private subnets
- **KMS** - Encryption key management
- **IAM** - Identity and access management
- **S3 Data Lake** - Data storage for each AI system (15 buckets)
- **DMS** - Real-time data replication from MySQL to S3
- **API Gateway** - REST API with 60+ endpoints
- **CI/CD Pipeline** - Automated deployment pipeline
- **S3 Frontend** - Static website hosting

**Tech Stack:** Terraform 1.5+, AWS

**Location:** `terraform/`

---

### 7. Database

**Purpose:** MySQL database schema and setup scripts

**Features:**
- Main eCommerce schema (customers, products, orders, etc.)
- System-specific schemas for each AI system
- Sample data generator
- DMS replication setup

**Tech Stack:** MySQL 9.6, Python 3.11

**Location:** `database/`

---

## Quick Start Guide

### Prerequisites

#### Required Tools
- **AWS CLI** - Version 2.x or higher
- **Terraform** - Version 1.5 or higher
- **Git** - For repository access
- **PowerShell** - Windows PowerShell 5.1+ or PowerShell Core 7+
- **MySQL** - Version 9.6 (on-premises server)

#### AWS Account Requirements
- **Account ID:** 450133579764
- **Region:** us-east-2 (Ohio)
- **IAM Permissions:** Administrator access or equivalent

#### MySQL Server Requirements
- **Host:** 172.20.10.2
- **Port:** 3306
- **Database:** ecommerce
- **User:** dms_remote
- **Password:** SaiesaShanmukha@123
- **Bind Address:** 0.0.0.0 (must accept remote connections)

### Step 1: Verify MySQL Server

```powershell
# Verify MySQL bind address and connectivity
cd database
.\check-mysql-bind-address.ps1

# Verify MySQL is listening on all interfaces
netstat -ano | findstr :3306
# Should show: 0.0.0.0:3306

# Test dms_remote user connection
mysql -u dms_remote -p
# Enter password: SaiesaShanmukha@123
```

### Step 2: Run Prerequisite Scripts

These scripts create AWS resources that Terraform depends on:

```powershell
cd terraform

# 1. Create Terraform backend (S3 + DynamoDB)
.\create-backend-resources.ps1 -Region us-east-2

# 2. Create DMS VPC role (required by AWS DMS)
.\create-dms-vpc-role.ps1

# 3. Create MySQL password secret
.\create-mysql-secret.ps1 -MySQLPassword "SaiesaShanmukha@123" -Environment dev

# IMPORTANT: Copy the Secret ARN from output!
```

### Step 3: Configure Terraform Variables

Edit `terraform/terraform.dev.tfvars`:

```hcl
aws_region   = "us-east-2"
environment  = "dev"
project_name = "futureim-ecommerce-ai-platform"
vpc_cidr     = "10.0.0.0/16"

# GitHub Configuration
github_repo   = "futureimadmin/hackathons"
github_branch = "master"
github_token  = "ghp_your_token_here"

# MySQL Configuration
mysql_server_ip = "172.20.10.2"
mysql_port      = 3306
mysql_database  = "ecommerce"
mysql_username  = "dms_remote"
mysql_password_secret_arn = "arn:aws:secretsmanager:us-east-2:450133579764:secret:..."  # From Step 2
```

### Step 4: Deploy Infrastructure with Terraform

```powershell
cd terraform

# Initialize Terraform with backend configuration
terraform init -backend-config=backend.tfvars

# Review the execution plan
terraform plan -var-file="terraform.dev.tfvars"

# Deploy infrastructure (type 'yes' when prompted)
terraform apply -var-file="terraform.dev.tfvars"
```

**Deployment Time:** 20-25 minutes

### Step 5: Complete GitHub Connection

1. Open AWS Console
2. Navigate to: Developer Tools → Connections
3. Find connection: `futureim-github-dev`
4. Click "Update pending connection"
5. Authorize GitHub access
6. Verify status shows "AVAILABLE"

### Step 6: Start DMS Replication

```powershell
# List DMS replication tasks
aws dms describe-replication-tasks `
  --query 'ReplicationTasks[].ReplicationTaskIdentifier'

# Start each replication task
aws dms start-replication-task `
  --replication-task-arn <task-arn> `
  --start-replication-task-type start-replication
```

Or use AWS Console:
- DMS → Database migration tasks
- Select task → Actions → Start

### Step 7: Verify Deployment

```powershell
# Check Terraform outputs
terraform output

# Verify DMS replication
cd database
.\verify-dms-replication.ps1

# Check pipeline status
aws codepipeline get-pipeline-state `
  --name futureim-ecommerce-ai-platform-pipeline-dev
```

---

## Configuration

### Terraform Variables

Edit `terraform/terraform.dev.tfvars`:

```hcl
aws_region   = "us-east-2"
environment  = "dev"
project_name = "futureim-ecommerce-ai-platform"
vpc_cidr     = "10.0.0.0/16"

github_repo   = "futureimadmin/hackathons"
github_branch = "master"
github_token  = "ghp_your_token"

mysql_server_ip = "172.20.10.2"
mysql_port      = 3306
mysql_database  = "ecommerce"
mysql_username  = "dms_remote"
mysql_password_secret_arn = "arn:aws:secretsmanager:us-east-2:450133579764:secret:..."
```

### MySQL Configuration

```ini
# my.ini
[mysqld]
bind-address = 0.0.0.0
port = 3306
log_bin = mysql-bin
binlog_format = ROW
```

```sql
-- Create DMS user
CREATE USER 'dms_remote'@'%' IDENTIFIED BY 'SaiesaShanmukha@123';
GRANT REPLICATION SLAVE ON *.* TO 'dms_remote'@'%';
GRANT SELECT ON ecommerce.* TO 'dms_remote'@'%';
FLUSH PRIVILEGES;
```

---

## Operations

### Daily Operations

```powershell
# Check Terraform state
cd terraform
terraform show

# Check DMS replication
cd database
.\verify-dms-replication.ps1

# Deploy code changes
git add .
git commit -m "Changes"
git push origin master
# Pipeline auto-triggers
```

### Maintenance

```powershell
# Update infrastructure
cd terraform
terraform plan -var-file="terraform.dev.tfvars"
terraform apply -var-file="terraform.dev.tfvars"

# Restart DMS replication
aws dms stop-replication-task --replication-task-arn <arn>
aws dms start-replication-task --replication-task-arn <arn> --start-replication-task-type start-replication

# Destroy environment (use with caution!)
terraform destroy -var-file="terraform.dev.tfvars"
```

---

## Troubleshooting

### DMS Cannot Connect to MySQL

```powershell
# 1. Check MySQL bind address
cd database
.\check-mysql-bind-address.ps1

# 2. Verify MySQL is listening
netstat -ano | findstr :3306

# 3. Test connection
Test-NetConnection -ComputerName 172.20.10.2 -Port 3306

# 4. Check MySQL user
mysql -h 172.20.10.2 -u dms_remote -p
```

### Pipeline Not Auto-Triggering

```powershell
# 1. Check GitHub connection
aws codestar-connections get-connection --connection-arn <arn>

# 2. Manually trigger
aws codepipeline start-pipeline-execution `
  --name futureim-ecommerce-ai-platform-pipeline-dev
```

### Lambda Timeout

```powershell
# Increase timeout
aws lambda update-function-configuration `
  --function-name <name> `
  --timeout 300

# Increase memory
aws lambda update-function-configuration `
  --function-name <name> `
  --memory-size 3008
```

---

## Project Structure

```
futureim-ecommerce-ai-platform/
├── ai-systems/                    # 5 AI Lambda functions
│   ├── compliance-guardian/       # Fraud detection & compliance
│   ├── demand-insights-engine/    # Customer insights & forecasting
│   ├── global-market-pulse/       # Market trends & opportunities
│   ├── market-intelligence-hub/   # Time series forecasting
│   └── retail-copilot/            # AI assistant
├── analytics-service/             # Analytics API service
├── auth-service/                  # Authentication service (Java)
├── frontend/                      # React dashboard
├── data-processing/               # Data pipeline (Docker)
├── database/                      # MySQL schema & scripts
├── terraform/                     # Infrastructure as Code
│   ├── create-backend-resources.ps1  # Prerequisite: Create S3 + DynamoDB
│   ├── create-dms-vpc-role.ps1       # Prerequisite: Create DMS IAM role
│   ├── create-mysql-secret.ps1       # Prerequisite: Create MySQL secret
│   └── modules/                   # Reusable modules
└── README.md                     # This file
```

---

## Key Scripts

### Prerequisite Scripts (Run Once)

```powershell
# Create Terraform backend resources
terraform\create-backend-resources.ps1 -Region us-east-2

# Create DMS VPC role
terraform\create-dms-vpc-role.ps1

# Create MySQL password secret
terraform\create-mysql-secret.ps1 -MySQLPassword "password" -Environment dev
```

### Database Scripts

```powershell
# Check MySQL configuration
database\check-mysql-bind-address.ps1

# Setup database schema
database\setup-database.ps1

# Verify DMS replication
database\verify-dms-replication.ps1
```

### Build Scripts

```powershell
# Build AI systems
ai-systems\<system-name>\build.ps1

# Build analytics service
analytics-service\build.ps1

# Build auth service
auth-service\build.ps1

# Build data processing
data-processing\build-and-push.ps1
```

---

## Monitoring

### CloudWatch Metrics

- Lambda invocations, errors, duration
- DMS replication lag, throughput
- API Gateway requests, errors, latency
- S3 object count, storage size

### CloudWatch Logs

```powershell
# Lambda logs
aws logs tail /aws/lambda/<function-name> --follow

# DMS logs
aws logs tail /aws/dms/futureim-ecommerce-ai-platform-dev --follow

# Search for errors
aws logs filter-log-events `
  --log-group-name /aws/lambda/<function-name> `
  --filter-pattern "ERROR"
```

---

## Security

### Security Features

- ✅ KMS encryption at rest
- ✅ TLS 1.2+ encryption in transit
- ✅ Secrets Manager for credentials
- ✅ IAM roles with least privilege
- ✅ VPC isolation for sensitive resources
- ✅ Security groups with minimal ports
- ✅ CloudTrail logging enabled
- ✅ VPC Flow Logs enabled

### Security Checklist

- [ ] All S3 buckets encrypted
- [ ] No hardcoded credentials
- [ ] API Gateway authentication enabled
- [ ] CloudTrail enabled
- [ ] VPC Flow Logs enabled
- [ ] Security groups follow least privilege
- [ ] Regular security audits

---

## Cost Optimization

### Current Monthly Costs (Estimated)

- DMS: ~$144/month (dms.t3.medium)
- Lambda: ~$50/month (pay per invocation)
- S3: ~$100/month (pay per GB)
- API Gateway: ~$30/month (pay per request)
- CodePipeline: $1/month
- **Total: ~$325/month**

### Cost Reduction Tips

1. Stop DMS when not replicating
2. Use S3 lifecycle policies for old data
3. Optimize Lambda memory allocation
4. Clean up old CloudWatch logs
5. Use reserved capacity for predictable workloads

---

## Support

### Documentation

- **Complete Operations Guide:** `docs/RUNBOOK.md`
- **Module READMEs:** Each module has detailed documentation
- **AWS Documentation:** https://docs.aws.amazon.com/

### Contact

- **Technical Support:** sales@futureim.in
- **AWS Support:** AWS Support Center

---

## License

Proprietary - FutureIM

---

## Version History

- **1.0** (February 2026) - Initial production release
  - 5 AI systems deployed
  - Complete CI/CD pipeline
  - Real-time data replication
  - React frontend
  - Comprehensive documentation

---

**Last Updated:** February 1, 2026  
**Status:** Production Ready  
**Maintained By:** FutureIM Engineering Team
