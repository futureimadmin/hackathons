# Deployment Guide

## Overview

Complete deployment guide for the eCommerce AI Analytics Platform.

## Prerequisites

- AWS Account with admin access
- Terraform 1.0+
- AWS CLI configured
- Docker installed
- Java 11+ (for auth service)
- Python 3.9+ (for AI systems)
- Node.js 18+ (for frontend)
- MySQL 8.0+ (on-premise)

## Deployment Steps

### 1. Configure AWS Credentials

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (us-east-1), Output format (json)
```

### 2. Set Up Terraform Backend

```bash
cd terraform
./scripts/setup-backend.sh
```

### 3. Configure Secrets

```bash
# Store MySQL credentials
aws secretsmanager create-secret \
  --name ecommerce-ai-platform/mysql \
  --secret-string '{"username":"root","password":"your-password","host":"your-mysql-host","port":"3306"}'

# Store JWT secret
aws secretsmanager create-secret \
  --name ecommerce-ai-platform/jwt-secret \
  --secret-string "your-jwt-secret-key"
```

### 4. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 5. Build and Deploy Docker Images

```bash
cd data-processing
./build-and-push.ps1
```

### 6. Deploy Lambda Functions

```bash
# Auth Service
cd auth-service
mvn clean package
aws lambda update-function-code \
  --function-name ecommerce-ai-platform-auth \
  --zip-file fileb://target/auth-service.jar

# AI Systems
cd ai-systems/market-intelligence-hub
./build.ps1
# Repeat for all AI systems
```

### 7. Deploy Frontend

```bash
cd frontend
npm install
npm run build
aws s3 sync dist/ s3://ecommerce-ai-platform-frontend/
```

### 8. Set Up Database

```bash
cd database
./setup-database.ps1
python data_generator/generate_sample_data.py
```

### 9. Start DMS Replication

```bash
aws dms start-replication-task \
  --replication-task-arn <task-arn> \
  --start-replication-task-type start-replication
```

### 10. Verify Deployment

```bash
# Run verification tests
cd tests/integration
./run_integration_tests.ps1 -TestType all
```

## Post-Deployment

1. Configure CloudWatch dashboards
2. Set up alarms and notifications
3. Enable CloudTrail logging
4. Configure backup policies
5. Document API endpoints
6. Train users

## Troubleshooting

See `docs/TROUBLESHOOTING_GUIDE.md`

## Rollback Procedures

```bash
terraform destroy
# Or revert to previous version
terraform apply -var="version=previous"
```
