# API Gateway Quick Start

## Deploy API Gateway (Now)

```powershell
cd terraform
.\deploy-api-gateway.ps1
```

This will:
- ✅ Create API Gateway REST API
- ✅ Deploy Lambda authorizer
- ✅ Create all API resources and methods
- ✅ Output API Gateway URL
- ✅ Update frontend .env.production

## Get API Gateway URL

```powershell
cd terraform
terraform output api_gateway_url
```

## Update Frontend

```powershell
cd frontend
npm run build
aws s3 sync dist/ s3://futureim-ecommerce-ai-platform-frontend-dev/ --delete
```

## Deploy Lambda Functions (Later)

### Option 1: Manual (Quick Test)

**Auth Service:**
```powershell
cd auth-service
mvn clean package
aws lambda create-function --function-name futureim-ecommerce-ai-platform-auth-dev --runtime java17 --role arn:aws:iam::450133579764:role/futureim-ecommerce-ai-platform-lambda-execution-dev --handler com.ecommerce.auth.LambdaHandler::handleRequest --zip-file fileb://target/auth-service-1.0.0.jar --region us-east-2
```

**Analytics Service:**
```powershell
cd analytics-service
.\build.ps1
aws lambda create-function --function-name futureim-ecommerce-ai-platform-analytics-dev --runtime python3.11 --role arn:aws:iam::450133579764:role/futureim-ecommerce-ai-platform-lambda-execution-dev --handler lambda_function.lambda_handler --zip-file fileb://analytics-service.zip --region us-east-2
```

### Option 2: CI/CD Pipeline (Recommended)

```powershell
cd deployment/deployment-pipeline
.\setup-pipeline.ps1 -GitHubRepo "futureimadmin/hackathons" -GitHubBranch "master" -GitHubToken "YOUR_TOKEN" -DevApprovalEmail "your@email.com" -ProdApprovalEmail "your@email.com"
```

## Test API

```powershell
# Get API URL
$apiUrl = terraform output -raw api_gateway_url

# Test login (will fail until Lambda deployed)
curl -X POST "$apiUrl/auth/login" -H "Content-Type: application/json" -d '{"email":"test@example.com","password":"password123"}'
```

## Troubleshooting

**Terraform not found?**
- Install from: https://www.terraform.io/downloads

**API returns 500 errors?**
- Lambda functions not deployed yet (Phase 2)

**CORS errors?**
- Check frontend URL matches `cors_allowed_origin` in terraform/main.tf

## Resources

- **Frontend:** http://futureim-ecommerce-ai-platform-frontend-dev.s3-website.us-east-2.amazonaws.com
- **Region:** us-east-2
- **Account:** 450133579764
- **GitHub:** https://github.com/futureimadmin/hackathons.git

## Full Documentation

See `docs/API_GATEWAY_DEPLOYMENT_GUIDE.md` for complete instructions.
