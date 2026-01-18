# API Gateway Implementation Plan

## Current Status
- ✅ Infrastructure: VPC, S3, IAM, KMS, DynamoDB
- ✅ Database: MySQL with data
- ✅ Frontend: Deployed to S3
- ✅ CI/CD Pipeline: CloudFormation template exists
- ✅ Services: auth-service (Java), analytics-service (Python), AI systems
- ❌ API Gateway: Not created
- ❌ Lambda Functions: Not deployed
- ❌ CI/CD Pipeline: Not deployed

## Implementation Steps

### Step 1: Create API Gateway with Terraform (Infrastructure Only)

Add API Gateway module to `terraform/main.tf` with placeholder Lambda integrations.

**File: `terraform/main.tf`** - Add after DynamoDB module:

```hcl
# API Gateway (infrastructure only, Lambda integrations will be added by CI/CD)
module "api_gateway" {
  source = "./modules/api-gateway"
  
  api_name   = "${var.project_name}-api"
  stage_name = var.environment
  
  # Placeholder - will be updated after Lambda deployment
  auth_lambda_function_name = "${var.project_name}-auth-${var.environment}"
  auth_lambda_invoke_arn    = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-auth-${var.environment}"
  
  analytics_lambda_function_name = "${var.project_name}-analytics-${var.environment}"
  analytics_lambda_invoke_arn    = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.project_name}-analytics-${var.environment}"
  
  kms_key_arn = module.kms.kms_key_arn
  
  cors_allowed_origin = "http://futureim-ecommerce-ai-platform-frontend-dev.s3-website.us-east-2.amazonaws.com"
  enable_waf          = false  # Disable for dev
  enable_xray_tracing = true
  
  tags = {
    Environment = var.environment
  }
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = module.api_gateway.api_url
}
```

### Step 2: Deploy CI/CD Pipeline

Run the existing pipeline setup:

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
- CodePipeline for CI/CD
- CodeBuild projects
- S3 buckets for artifacts
- SNS topics for approvals

### Step 3: Update Frontend with API Gateway URL

After Terraform creates API Gateway:

```powershell
# Get API Gateway URL
cd terraform
$apiUrl = terraform output -raw api_gateway_url

# Update frontend
cd ../frontend
# Edit .env.production
echo "VITE_API_URL=$apiUrl" > .env.production

# Rebuild and redeploy
npm run build
aws s3 sync dist/ s3://futureim-ecommerce-ai-platform-frontend-dev/ --delete
```

### Step 4: Build and Deploy Lambda Functions

The CI/CD pipeline will handle this, but for manual deployment:

**Auth Service (Java/Maven):**
```powershell
cd auth-service
mvn clean package
aws lambda create-function `
  --function-name futureim-ecommerce-ai-platform-auth-dev `
  --runtime java17 `
  --role arn:aws:iam::450133579764:role/futureim-ecommerce-ai-platform-lambda-execution-dev `
  --handler com.ecommerce.auth.LambdaHandler::handleRequest `
  --zip-file fileb://target/auth-service-1.0.0.jar `
  --region us-east-2
```

**Analytics Service (Python):**
```powershell
cd analytics-service
.\build.ps1
aws lambda create-function `
  --function-name futureim-ecommerce-ai-platform-analytics-dev `
  --runtime python3.11 `
  --role arn:aws:iam::450133579764:role/futureim-ecommerce-ai-platform-lambda-execution-dev `
  --handler lambda_function.lambda_handler `
  --zip-file fileb://analytics-service.zip `
  --region us-east-2
```

## API Endpoints Mapping

Based on the README files, here are the API endpoints:

### Auth Service
- POST /auth/login
- POST /auth/register
- POST /auth/refresh
- GET /auth/validate

### Analytics Service
- GET /analytics/dashboard
- GET /analytics/metrics
- POST /analytics/query

### Compliance Guardian
- GET /compliance/fraud-detection
- GET /compliance/risk-score
- GET /compliance/high-risk-transactions
- GET /compliance/pci-compliance
- GET /compliance/compliance-report
- GET /compliance/fraud-statistics

### Market Intelligence Hub
- GET /market-intelligence/trends
- GET /market-intelligence/competitors
- POST /market-intelligence/analyze

### Demand Insights Engine
- GET /demand/forecast
- GET /demand/patterns
- POST /demand/predict

### Retail Copilot
- POST /retail-copilot/chat
- GET /retail-copilot/recommendations

### Global Market Pulse
- GET /global-market/pulse
- GET /global-market/regions

## Execution Order

1. **Now:** Add API Gateway module to Terraform
2. **Now:** Run `terraform apply` to create API Gateway
3. **Now:** Get API Gateway URL and update frontend
4. **Later:** Deploy CI/CD pipeline (optional, for automation)
5. **Later:** Build and deploy Lambda functions (manual or via CI/CD)

## Quick Win Approach

For immediate testing:

1. Create API Gateway with Terraform (infrastructure)
2. Build auth-service JAR manually
3. Create Lambda function manually in AWS Console
4. Test one endpoint
5. Then automate the rest

## Files to Update

1. `terraform/main.tf` - Add API Gateway module
2. `frontend/.env.production` - Add API Gateway URL
3. `terraform/variables.tf` - Add aws_region variable if missing
4. GitHub repo - Push code to trigger CI/CD

## Next Action

**Immediate:** Add API Gateway module to Terraform and apply.

Would you like me to proceed with adding the API Gateway module now?
