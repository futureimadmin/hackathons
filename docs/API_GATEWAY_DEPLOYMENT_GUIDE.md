# API Gateway Deployment Guide

## Overview

This guide explains how to deploy the API Gateway infrastructure and integrate it with Lambda functions.

## Current Status

✅ **Completed:**
- VPC, S3, IAM, KMS, DynamoDB infrastructure deployed
- MySQL database with sample data
- Frontend deployed to S3
- API Gateway module added to Terraform
- Lambda authorizer packaged

❌ **Pending:**
- API Gateway deployment
- Lambda functions deployment
- Frontend update with API Gateway URL

## Deployment Approach

We're using a **two-phase approach**:

1. **Phase 1 (Now):** Deploy API Gateway infrastructure with placeholder Lambda ARNs
2. **Phase 2 (Later):** Deploy Lambda functions and update integrations

This allows you to get the API Gateway URL immediately and update the frontend, even though the Lambda functions aren't deployed yet.

## Phase 1: Deploy API Gateway Infrastructure

### Prerequisites

1. **Terraform installed** - Download from https://www.terraform.io/downloads
2. **AWS CLI configured** - With credentials for account 450133579764
3. **Node.js installed** - For Lambda authorizer packaging

### Step 1: Deploy API Gateway

Run the deployment script:

```powershell
cd terraform
.\deploy-api-gateway.ps1
```

This script will:
1. Check Terraform installation
2. Package Lambda authorizer (if not already done)
3. Run `terraform init`
4. Run `terraform plan`
5. Ask for confirmation
6. Run `terraform apply`
7. Output the API Gateway URL
8. Update `frontend/.env.production` with the API Gateway URL

### Step 2: Verify Deployment

Check AWS Console:
- API Gateway: `futureim-ecommerce-ai-platform-api`
- Lambda: `futureim-ecommerce-ai-platform-api-authorizer`
- CloudWatch Logs: `/aws/apigateway/futureim-ecommerce-ai-platform-api`

Get the API Gateway URL:

```powershell
cd terraform
terraform output api_gateway_url
```

Example output:
```
https://abc123xyz.execute-api.us-east-2.amazonaws.com/dev
```

### Step 3: Update Frontend

The script automatically updates `frontend/.env.production`, but verify:

```powershell
cat frontend\.env.production
```

Should contain:
```
VITE_API_URL=https://abc123xyz.execute-api.us-east-2.amazonaws.com/dev
```

### Step 4: Rebuild and Redeploy Frontend

```powershell
cd frontend
npm run build
aws s3 sync dist/ s3://futureim-ecommerce-ai-platform-frontend-dev/ --delete
```

Verify frontend:
```
http://futureim-ecommerce-ai-platform-frontend-dev.s3-website.us-east-2.amazonaws.com
```

## Phase 2: Deploy Lambda Functions

### Option A: Manual Deployment (Quick Test)

#### Auth Service (Java/Maven)

```powershell
cd auth-service
mvn clean package

aws lambda create-function `
  --function-name futureim-ecommerce-ai-platform-auth-dev `
  --runtime java17 `
  --role arn:aws:iam::450133579764:role/futureim-ecommerce-ai-platform-lambda-execution-dev `
  --handler com.ecommerce.auth.LambdaHandler::handleRequest `
  --zip-file fileb://target/auth-service-1.0.0.jar `
  --timeout 30 `
  --memory-size 512 `
  --region us-east-2 `
  --environment Variables="{DB_HOST=172.20.10.4,DB_USER=dms_remote,DB_PASSWORD=SaiesaShanmukha@123,DB_NAME=ecommerce,JWT_SECRET=your-secret-key}"
```

#### Analytics Service (Python)

```powershell
cd analytics-service
.\build.ps1

aws lambda create-function `
  --function-name futureim-ecommerce-ai-platform-analytics-dev `
  --runtime python3.11 `
  --role arn:aws:iam::450133579764:role/futureim-ecommerce-ai-platform-lambda-execution-dev `
  --handler lambda_function.lambda_handler `
  --zip-file fileb://analytics-service.zip `
  --timeout 30 `
  --memory-size 512 `
  --region us-east-2
```

### Option B: CI/CD Pipeline (Recommended)

Deploy the CI/CD pipeline:

```powershell
cd deployment/deployment-pipeline
.\setup-pipeline.ps1 `
  -GitHubRepo "futureimadmin/hackathons" `
  -GitHubBranch "master" `
  -GitHubToken "YOUR_GITHUB_TOKEN" `
  -DevApprovalEmail "your-email@example.com" `
  -ProdApprovalEmail "your-email@example.com"
```

This creates:
- CodePipeline for automated deployments
- CodeBuild projects for building Lambda functions
- S3 buckets for artifacts
- SNS topics for approval notifications

Push code to GitHub to trigger the pipeline:

```powershell
git add .
git commit -m "Deploy Lambda functions"
git push origin master
```

### Update API Gateway Integrations

After Lambda functions are deployed, update the API Gateway integrations:

```powershell
cd terraform
terraform apply
```

Terraform will detect the Lambda functions now exist and update the integrations.

## API Endpoints

### Authentication Endpoints (Public)
- `POST /auth/register` - User registration
- `POST /auth/login` - User login
- `POST /auth/forgot-password` - Request password reset
- `POST /auth/reset-password` - Reset password

### Protected Endpoints (Require JWT Token)
- `POST /auth/verify` - Verify JWT token
- `GET /analytics/{system}/query` - Query analytics data
- `POST /analytics/{system}/forecast` - Generate forecast
- `GET /analytics/{system}/insights` - Get insights
- `POST /market-intelligence/forecast` - Market forecast
- `GET /market-intelligence/trends` - Market trends
- `GET /market-intelligence/competitive-pricing` - Competitive pricing
- `POST /market-intelligence/compare-models` - Compare models
- `GET /demand-insights/segments` - Customer segments
- `POST /demand-insights/forecast` - Demand forecast
- `POST /demand-insights/price-elasticity` - Price elasticity
- `POST /demand-insights/price-optimization` - Price optimization
- `POST /demand-insights/clv` - Customer lifetime value
- `POST /demand-insights/churn` - Churn prediction
- `GET /demand-insights/at-risk-customers` - At-risk customers
- `POST /compliance/fraud-detection` - Fraud detection
- `POST /compliance/risk-score` - Risk score
- `GET /compliance/high-risk-transactions` - High-risk transactions
- `POST /compliance/pci-compliance` - PCI compliance check
- `GET /compliance/compliance-report` - Compliance report
- `GET /compliance/fraud-statistics` - Fraud statistics
- `POST /copilot/chat` - Chat with copilot
- `GET /copilot/conversations` - Get conversations
- `POST /copilot/conversation` - Create conversation
- `GET /copilot/conversation` - Get conversation
- `DELETE /copilot/conversation` - Delete conversation
- `GET /copilot/inventory` - Get inventory
- `GET /copilot/orders` - Get orders
- `GET /copilot/customers` - Get customers
- `POST /copilot/recommendations` - Get recommendations
- `GET /copilot/sales-report` - Get sales report
- `GET /global-market/trends` - Global market trends
- `GET /global-market/regional-prices` - Regional prices
- `POST /global-market/price-comparison` - Price comparison
- `POST /global-market/opportunities` - Market opportunities
- `POST /global-market/competitor-analysis` - Competitor analysis
- `GET /global-market/market-share` - Market share
- `GET /global-market/growth-rates` - Growth rates
- `POST /global-market/trend-changes` - Trend changes

## Testing

### Test API Gateway (Without Lambda)

```powershell
# Test public endpoint (will fail until Lambda is deployed)
curl -X POST https://YOUR_API_URL/auth/login `
  -H "Content-Type: application/json" `
  -d '{"email":"test@example.com","password":"password123"}'
```

Expected response (before Lambda deployment):
```json
{"message": "Internal server error"}
```

### Test with Lambda Functions

After Lambda deployment:

```powershell
# Login
$response = curl -X POST https://YOUR_API_URL/auth/login `
  -H "Content-Type: application/json" `
  -d '{"email":"test@example.com","password":"password123"}' | ConvertFrom-Json

$token = $response.token

# Test protected endpoint
curl -X GET https://YOUR_API_URL/analytics/market-intelligence-hub/query `
  -H "Authorization: Bearer $token"
```

## Troubleshooting

### Issue: Terraform not found

**Solution:** Install Terraform from https://www.terraform.io/downloads

### Issue: Lambda authorizer package not found

**Solution:** Run the package script:
```powershell
cd terraform/modules/api-gateway/lambda
.\package.ps1
```

### Issue: API Gateway returns 500 errors

**Cause:** Lambda functions not deployed yet

**Solution:** Deploy Lambda functions (Phase 2)

### Issue: API Gateway returns 403 Forbidden

**Cause:** JWT token invalid or missing

**Solution:** 
1. Login to get a valid token
2. Include token in Authorization header: `Authorization: Bearer YOUR_TOKEN`

### Issue: CORS errors in frontend

**Cause:** CORS not configured correctly

**Solution:** Check `cors_allowed_origin` in `terraform/main.tf` matches your frontend URL

## Architecture

```
Frontend (S3) → API Gateway → Lambda Authorizer (JWT)
                    ↓
                Lambda Functions:
                - Auth Service (Java)
                - Analytics Service (Python)
                - Market Intelligence (Python)
                - Demand Insights (Python)
                - Compliance Guardian (Python)
                - Retail Copilot (Python)
                - Global Market Pulse (Python)
                    ↓
                Backend Resources:
                - DynamoDB (Users)
                - MySQL (Ecommerce Data)
                - S3 (Data Lakes)
```

## Next Steps

1. ✅ Deploy API Gateway infrastructure
2. ⏳ Deploy Lambda functions (manual or CI/CD)
3. ⏳ Test API endpoints
4. ⏳ Update frontend to use API
5. ⏳ Monitor CloudWatch logs
6. ⏳ Set up alarms and monitoring

## Resources

- **Terraform State:** S3 bucket `futureim-ecommerce-ai-platform-terraform-state`
- **API Gateway:** AWS Console → API Gateway → `futureim-ecommerce-ai-platform-api`
- **Lambda Functions:** AWS Console → Lambda
- **CloudWatch Logs:** AWS Console → CloudWatch → Log groups
- **Frontend:** http://futureim-ecommerce-ai-platform-frontend-dev.s3-website.us-east-2.amazonaws.com
- **GitHub Repo:** https://github.com/futureimadmin/hackathons.git

## Support

For issues or questions:
1. Check CloudWatch logs for errors
2. Verify AWS credentials and permissions
3. Check Terraform state: `terraform show`
4. Review this guide and implementation plan
