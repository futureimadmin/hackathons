# FutureIM eCommerce AI Platform - Operations RunBook

**Version:** 2.0  
**Last Updated:** February 1, 2026  
**Deployment Method:** Terraform Only

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Deployment Guide](#deployment-guide)
5. [Configuration](#configuration)
6. [Daily Operations](#daily-operations)
7. [Maintenance](#maintenance)
8. [Troubleshooting](#troubleshooting)
9. [Monitoring](#monitoring)
10. [Security](#security)

---

## Overview

### Purpose

The FutureIM eCommerce AI Platform is an enterprise-grade cloud infrastructure providing AI-powered analytics for eCommerce businesses through 5 specialized AI systems.

### Key Components

1. **Infrastructure Layer** - AWS VPC, networking, security (Terraform)
2. **Data Layer** - MySQL → DMS → S3 → Athena pipeline
3. **AI Systems** - 5 specialized Lambda-based AI services
4. **API Layer** - API Gateway with 60+ endpoints
5. **Frontend** - React-based dashboard
6. **CI/CD** - Automated deployment pipeline

### Technology Stack

- **Cloud:** AWS (us-east-2)
- **Infrastructure:** Terraform 1.5+
- **Backend:** Java 17 (Auth), Python 3.11 (AI Systems)
- **Frontend:** React 18, TypeScript, Vite
- **Database:** MySQL 9.6 (on-premises at 172.20.10.2)
- **Data Pipeline:** DMS, S3, Glue, Athena
- **CI/CD:** CodePipeline, CodeBuild, GitHub

---

## Architecture

### System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     GitHub Repository                         │
│               futureimadmin/hackathons (master)               │
└────────────────────────┬─────────────────────────────────────┘
                         │ Auto-trigger on push
                         ▼
┌──────────────────────────────────────────────────────────────┐
│               CodePipeline V2 (4 Stages)                      │
│   Source → Infrastructure → Build Lambdas → Build Frontend   │
└────────────────────────┬─────────────────────────────────────┘
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
     ┌────────┐    ┌──────────┐   ┌──────────┐
     │  VPC   │    │   DMS    │   │   API    │
     │Subnets │    │Replication│  │ Gateway  │
     └────────┘    └──────────┘   └──────────┘
          │              │              │
          └──────────────┼──────────────┘
                         ▼
               ┌──────────────────────┐
               │   5 AI Systems       │
               │   Lambda Functions   │
               └──────────────────────┘
```

### Data Flow

```
MySQL (172.20.10.2:3306)
         │
         │ DMS Replication (Full Load + CDC)
         ▼
DMS Instance (dms.t3.medium)
         │
         │ Parquet Files (Compressed + Encrypted)
         ▼
┌──────────────────────────────────────────────────────────────┐
│                     S3 Data Buckets                           │
│   • compliance-guardian-data-dev                              │
│   • demand-insights-engine-data-dev                           │
│   • global-market-pulse-data-dev                              │
│   • market-intelligence-hub-data-dev                          │
│   • retail-copilot-data-dev                                   │
└────────────────────────┬─────────────────────────────────────┘
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
   └─ Resources: DMS, Lambda Functions
```

---

## Prerequisites

### Required Tools

- **AWS CLI** - Version 2.x or higher
- **Terraform** - Version 1.5 or higher
- **Git** - For repository access
- **PowerShell** - Windows PowerShell 5.1+ or PowerShell Core 7+
- **MySQL** - Version 9.6 (on-premises)

### AWS Account Requirements

- **Account ID:** 450133579764
- **Region:** us-east-2 (Ohio)
- **IAM Permissions:** Administrator access or equivalent

### MySQL Server Requirements

- **Host:** 172.20.10.2
- **Port:** 3306
- **Database:** ecommerce
- **User:** dms_remote
- **Password:** SaiesaShanmukha@123
- **Bind Address:** 0.0.0.0 (must accept remote connections)
- **Binary Logging:** Enabled (for CDC)

---

## Deployment Guide

### Pre-Deployment Checklist

- [ ] AWS CLI configured with correct credentials
- [ ] Terraform 1.5+ installed
- [ ] GitHub Personal Access Token generated
- [ ] MySQL server accessible at 172.20.10.2:3306
- [ ] MySQL user `dms_remote` can connect successfully
- [ ] MySQL bind-address set to 0.0.0.0
- [ ] Firewall allows TCP 3306 from AWS

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
# Should connect successfully
```

### Step 2: Run Prerequisite Scripts

These scripts create AWS resources that Terraform depends on:

```powershell
cd terraform

# 1. Create Terraform backend (S3 bucket + DynamoDB table)
.\create-backend-resources.ps1 -Region us-east-2 -ProjectName "futureim-ecommerce-ai-platform"

# 2. Create DMS VPC role (required by AWS DMS)
.\create-dms-vpc-role.ps1

# 3. Create MySQL password secret in Secrets Manager
.\create-mysql-secret.ps1 `
  -MySQLPassword "SaiesaShanmukha@123" `
  -Environment dev `
  -Region us-east-2

# IMPORTANT: Copy the Secret ARN from the output!
# Example: arn:aws:secretsmanager:us-east-2:450133579764:secret:futureim-ecommerce-ai-platform-mysql-password-dev-AbCdEf
```

### Step 3: Configure Terraform Variables

Create/edit `terraform/backend.tfvars`:

```hcl
bucket         = "futureim-ecommerce-ai-platform-terraform-state"
key            = "terraform.tfstate"
region         = "us-east-2"
dynamodb_table = "futureim-ecommerce-ai-platform-terraform-locks"
encrypt        = true
```

Edit `terraform/terraform.dev.tfvars`:

```hcl
# AWS Configuration
aws_region   = "us-east-2"
environment  = "dev"
project_name = "futureim-ecommerce-ai-platform"
vpc_cidr     = "10.0.0.0/16"

# GitHub Configuration
github_repo   = "futureimadmin/hackathons"
github_branch = "master"
github_token  = "ghp_your_github_personal_access_token_here"

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
  --query 'ReplicationTasks[].{ID:ReplicationTaskIdentifier,Status:Status}'

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
cd terraform
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

### Terraform Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| `aws_region` | AWS region | us-east-2 |
| `environment` | Environment name | dev, prod |
| `project_name` | Project prefix | futureim-ecommerce-ai-platform |
| `vpc_cidr` | VPC CIDR block | 10.0.0.0/16 |
| `github_repo` | GitHub repository | futureimadmin/hackathons |
| `github_branch` | Git branch | master |
| `github_token` | GitHub PAT | ghp_... |
| `mysql_server_ip` | MySQL host | 172.20.10.2 |
| `mysql_port` | MySQL port | 3306 |
| `mysql_database` | Database name | ecommerce |
| `mysql_username` | MySQL user | dms_remote |
| `mysql_password_secret_arn` | Secret ARN | arn:aws:secretsmanager:... |

### MySQL Configuration

#### Required MySQL Settings

```ini
# my.ini location: C:\ProgramData\MySQL\MySQL Server 9.6\my.ini

[mysqld]
bind-address = 0.0.0.0
port = 3306

# Binary logging (required for DMS CDC)
log_bin = mysql-bin
binlog_format = ROW
binlog_row_image = FULL
expire_logs_days = 7

# Performance
max_connections = 200
innodb_buffer_pool_size = 2G
```

#### MySQL User Setup

```sql
-- Create DMS user
CREATE USER 'dms_remote'@'%' IDENTIFIED BY 'SaiesaShanmukha@123';

-- Grant replication privileges
GRANT REPLICATION SLAVE ON *.* TO 'dms_remote'@'%';
GRANT REPLICATION CLIENT ON *.* TO 'dms_remote'@'%';

-- Grant read access to ecommerce database
GRANT SELECT ON ecommerce.* TO 'dms_remote'@'%';

-- Apply changes
FLUSH PRIVILEGES;

-- Verify user
SELECT user, host FROM mysql.user WHERE user = 'dms_remote';
SHOW GRANTS FOR 'dms_remote'@'%';
```

---

## Daily Operations

### Check System Health

```powershell
# Check Terraform state
cd terraform
terraform show

# Check specific resources
terraform state list
terraform state show <resource_name>

# Check DMS replication status
cd database
.\verify-dms-replication.ps1

# Check pipeline status
aws codepipeline get-pipeline-state `
  --name futureim-ecommerce-ai-platform-pipeline-dev
```

### Monitor Data Replication

```powershell
# Check DMS task status
aws dms describe-replication-tasks `
  --query 'ReplicationTasks[].{ID:ReplicationTaskIdentifier,Status:Status,Progress:ReplicationTaskStats}'

# View CloudWatch logs
aws logs tail /aws/dms/futureim-ecommerce-ai-platform-dev --follow

# Check S3 data buckets
aws s3 ls s3://compliance-guardian-data-dev/ --recursive --human-readable
```

### Deploy Code Changes

```powershell
# Commit and push changes
git add .
git commit -m "Your changes"
git push origin master

# Pipeline auto-triggers within 1-2 minutes
# Monitor in AWS Console → CodePipeline
```

---

## Maintenance

### Update Infrastructure

```powershell
cd terraform

# Review changes
terraform plan -var-file="terraform.dev.tfvars"

# Apply changes
terraform apply -var-file="terraform.dev.tfvars"
```

### Restart DMS Replication

```powershell
# Stop task
aws dms stop-replication-task --replication-task-arn <task-arn>

# Wait for task to stop
aws dms describe-replication-tasks --filters Name=replication-task-arn,Values=<task-arn>

# Start task
aws dms start-replication-task `
  --replication-task-arn <task-arn> `
  --start-replication-task-type start-replication
```

### Backup MySQL Database

```powershell
# Full backup
mysqldump -h 172.20.10.2 -u root -p ecommerce > backup_$(Get-Date -Format 'yyyyMMdd').sql

# Backup to S3
aws s3 cp backup_$(Get-Date -Format 'yyyyMMdd').sql `
  s3://your-backup-bucket/mysql-backups/
```

### Destroy Environment

**⚠️ WARNING: This will delete all infrastructure!**

```powershell
cd terraform

# Review what will be destroyed
terraform plan -destroy -var-file="terraform.dev.tfvars"

# Destroy (type 'yes' when prompted)
terraform destroy -var-file="terraform.dev.tfvars"
```

---

## Troubleshooting

### Issue: DMS Cannot Connect to MySQL

**Symptoms:**
- DMS test connection fails
- Error: "Can't connect to MySQL server"

**Solutions:**

1. **Check MySQL bind address:**
```powershell
cd database
.\check-mysql-bind-address.ps1
```

2. **Verify MySQL is listening:**
```powershell
netstat -ano | findstr :3306
# Should show: 0.0.0.0:3306
```

3. **Test connection from local machine:**
```powershell
Test-NetConnection -ComputerName 172.20.10.2 -Port 3306
```

4. **Verify MySQL user:**
```sql
SELECT user, host FROM mysql.user WHERE user = 'dms_remote';
SHOW GRANTS FOR 'dms_remote'@'%';
```

5. **Check firewall:**
```powershell
# Windows Firewall
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*MySQL*"}
```

### Issue: Pipeline Not Auto-Triggering

**Symptoms:**
- Code pushed to GitHub
- Pipeline doesn't start

**Solutions:**

1. **Check GitHub connection:**
```powershell
aws codestar-connections get-connection --connection-arn <arn>
# Status should be "AVAILABLE"
```

2. **Verify pipeline configuration:**
```powershell
aws codepipeline get-pipeline `
  --name futureim-ecommerce-ai-platform-pipeline-dev `
  --query 'metadata.pipelineType'
# Should return "V2"
```

3. **Manually trigger pipeline:**
```powershell
aws codepipeline start-pipeline-execution `
  --name futureim-ecommerce-ai-platform-pipeline-dev
```

### Issue: Lambda Function Timeout

**Symptoms:**
- API requests timeout
- CloudWatch shows Lambda timeout errors

**Solutions:**

1. **Increase Lambda timeout:**
```powershell
aws lambda update-function-configuration `
  --function-name <function-name> `
  --timeout 300
```

2. **Increase Lambda memory:**
```powershell
aws lambda update-function-configuration `
  --function-name <function-name> `
  --memory-size 3008
```

3. **Optimize Athena queries:**
- Add partitioning
- Reduce date ranges
- Use LIMIT clauses

### Issue: Terraform State Lock

**Symptoms:**
- Error: "Error acquiring the state lock"

**Solutions:**

```powershell
# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>

# Check DynamoDB table
aws dynamodb scan --table-name futureim-ecommerce-ai-platform-terraform-locks
```

---

## Monitoring

### CloudWatch Dashboards

#### Key Metrics to Monitor

1. **Lambda Functions**
   - Invocations
   - Errors
   - Duration
   - Throttles
   - Concurrent executions

2. **DMS Replication**
   - Full load throughput
   - CDC latency
   - Replication lag
   - Errors

3. **API Gateway**
   - Request count
   - 4xx errors
   - 5xx errors
   - Latency

4. **S3 Buckets**
   - Object count
   - Storage size

### CloudWatch Alarms

```powershell
# Lambda error rate > 1%
aws cloudwatch put-metric-alarm `
  --alarm-name lambda-high-error-rate `
  --metric-name Errors `
  --namespace AWS/Lambda `
  --statistic Sum `
  --period 300 `
  --evaluation-periods 1 `
  --threshold 10 `
  --comparison-operator GreaterThanThreshold

# DMS replication lag > 5 minutes
aws cloudwatch put-metric-alarm `
  --alarm-name dms-high-replication-lag `
  --metric-name CDCLatencySource `
  --namespace AWS/DMS `
  --statistic Average `
  --period 300 `
  --evaluation-periods 1 `
  --threshold 300 `
  --comparison-operator GreaterThanThreshold
```

### View Logs

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

### Security Best Practices

1. **Encryption**
   - All data encrypted at rest (KMS)
   - All data encrypted in transit (TLS 1.2+)
   - Secrets stored in Secrets Manager

2. **Access Control**
   - IAM roles with least privilege
   - No hardcoded credentials
   - MFA enabled for AWS Console

3. **Network Security**
   - Private subnets for sensitive resources
   - Security groups with minimal ports
   - VPC Flow Logs enabled

4. **Monitoring**
   - CloudTrail enabled
   - CloudWatch Logs enabled
   - Regular security audits

### Security Checklist

- [ ] All S3 buckets have encryption enabled
- [ ] All Lambda functions use IAM roles
- [ ] No secrets in code or environment variables
- [ ] API Gateway has authentication enabled
- [ ] DMS uses encrypted connections
- [ ] CloudTrail logging enabled
- [ ] VPC Flow Logs enabled
- [ ] Security groups follow least privilege

---

## Appendix

### Useful Commands Reference

```powershell
# Terraform
terraform init -backend-config=backend.tfvars
terraform plan -var-file="terraform.dev.tfvars"
terraform apply -var-file="terraform.dev.tfvars"
terraform destroy -var-file="terraform.dev.tfvars"
terraform output
terraform state list
terraform state show <resource>

# AWS CLI
aws sts get-caller-identity
aws dms describe-replication-tasks
aws codepipeline get-pipeline-state --name <pipeline-name>
aws lambda list-functions
aws s3 ls
aws logs tail <log-group> --follow

# Database
cd database
.\check-mysql-bind-address.ps1
.\setup-database.ps1
.\verify-dms-replication.ps1
```

### Support Contacts

- **Technical Support:** sales@futureim.in
- **AWS Support:** AWS Support Center

### Additional Resources

- [AWS Documentation](https://docs.aws.amazon.com/)
- [Terraform Documentation](https://www.terraform.io/docs)
- [MySQL Documentation](https://dev.mysql.com/doc/)

---

**End of RunBook**
