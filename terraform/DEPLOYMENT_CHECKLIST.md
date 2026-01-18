# Deployment Checklist

## Pre-Deployment Verification

### ✅ Files Created/Modified
- [x] Lambda execution role added to `modules/iam/main.tf`
- [x] Lambda role output added to `modules/iam/outputs.tf`
- [x] S3 frontend module created at `modules/s3-frontend/`
- [x] CI/CD pipeline module enhanced with Terraform permissions
- [x] Frontend bucket added to `main.tf`
- [x] CI/CD pipeline added to `main.tf`
- [x] GitHub variables added to `variables.tf`
- [x] DEV tfvars created: `terraform.dev.tfvars`
- [x] PROD tfvars created: `terraform.prod.tfvars`
- [x] PROD backend config created: `backend-prod.hcl`
- [x] All buildspec files exist in `buildspecs/`

### ✅ Configuration Verified
- [x] GitHub repo: futureimadmin/hackathons
- [x] GitHub branch: master
- [x] GitHub token: Configured in tfvars (will be stored in Secrets Manager)
- [x] AWS Region: us-east-2
- [x] AWS Account: 450133579764
- [x] DEV VPC CIDR: 10.0.0.0/16
- [x] PROD VPC CIDR: 10.1.0.0/16

## Deployment Steps

### Step 1: Deploy DEV Environment
```powershell
cd terraform
terraform init
terraform plan -var-file="terraform.dev.tfvars" -out=dev.tfplan
terraform apply dev.tfplan
```

**Expected Resources Created:**
- VPC with public/private subnets
- KMS key for encryption
- IAM roles (Batch, DMS, Glue, Lambda)
- DynamoDB users table
- S3 buckets (data lakes + frontend + pipeline artifacts)
- API Gateway with 60+ endpoints
- CodePipeline with 4 stages
- 4 CodeBuild projects
- GitHub CodeStar connection (PENDING status)

### Step 2: Approve GitHub Connection
1. Open AWS Console
2. Navigate to: Developer Tools → Connections
3. Find: `futureim-ecommerce-ai-platform-github-dev`
4. Click "Update pending connection"
5. Authorize GitHub access via OAuth
6. Verify status changes to "AVAILABLE"

### Step 3: Test Pipeline
```powershell
# Get pipeline URL
terraform output pipeline_url

# Or manually trigger in AWS Console:
# CodePipeline → futureim-ecommerce-ai-platform-pipeline-dev → Release change
```

**Expected Pipeline Stages:**
1. ✅ Source - Pulls from GitHub
2. ✅ Infrastructure - Deploys Terraform
3. ✅ BuildLambdas - Builds Java + Python Lambdas (parallel)
4. ✅ BuildFrontend - Builds and deploys React app

### Step 4: Verify DEV Deployment
```powershell
# Get API Gateway URL
terraform output api_gateway_url

# Get Frontend URL
terraform output frontend_website_url

# Test API endpoint
curl https://[api-id].execute-api.us-east-2.amazonaws.com/dev/health

# Test Frontend
# Open browser to: http://futureim-ecommerce-ai-platform-frontend-dev.s3-website.us-east-2.amazonaws.com
```

### Step 5: Deploy PROD Environment
```powershell
# Plan PROD deployment
terraform plan -var-file="terraform.prod.tfvars" -out=prod.tfplan

# Review the plan carefully
# Verify it's creating new resources, not modifying DEV

# Apply PROD deployment
terraform apply prod.tfplan
```

### Step 6: Approve PROD GitHub Connection
Repeat Step 2 for PROD:
- Connection name: `futureim-ecommerce-ai-platform-github-prod`

### Step 7: Verify PROD Deployment
```powershell
# Get PROD outputs
terraform output -json

# Test PROD API
curl https://[api-id].execute-api.us-east-2.amazonaws.com/prod/health

# Test PROD Frontend
# Open browser to: http://futureim-ecommerce-ai-platform-frontend-prod.s3-website.us-east-2.amazonaws.com
```

## Post-Deployment Tasks

### Monitor Pipeline
- [ ] Check CodePipeline console for build status
- [ ] Review CloudWatch Logs for any errors
- [ ] Verify all Lambda functions were created
- [ ] Test API endpoints
- [ ] Test frontend functionality

### Set Up Notifications (Optional)
```powershell
# Create SNS topic for pipeline notifications
aws sns create-topic --name ecommerce-pipeline-notifications

# Subscribe to notifications
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-2:450133579764:ecommerce-pipeline-notifications \
  --protocol email \
  --notification-endpoint your-email@example.com
```

### Configure CloudWatch Alarms (Optional)
- Pipeline failure alarms
- Lambda error rate alarms
- API Gateway 5xx error alarms
- Frontend S3 bucket access alarms

## Troubleshooting

### Issue: GitHub Connection Stays PENDING
**Solution**: Must manually approve in AWS Console (Step 2)

### Issue: Terraform Permission Errors in CodeBuild
**Solution**: CodeBuild role has been updated with full permissions. If still failing, check CloudWatch Logs for specific permission needed.

### Issue: Lambda Creation Fails
**Possible Causes:**
1. Lambda execution role not created → Check Infrastructure stage logs
2. Invalid function name → Check buildspec environment variables
3. Insufficient permissions → Check CodeBuild role policy

**Solution**: Review CodeBuild logs in CloudWatch

### Issue: Frontend Build Fails
**Possible Causes:**
1. API Gateway URL not found → Check Infrastructure stage artifacts
2. S3 bucket doesn't exist → Check Terraform apply logs
3. Build dependencies missing → Check buildspec npm install step

**Solution**: Review frontend buildspec and CloudWatch Logs

### Issue: Pipeline Doesn't Trigger on Commit
**Possible Causes:**
1. GitHub connection not approved
2. Wrong branch configured
3. Repository webhook not created

**Solution**: 
1. Verify connection status is "AVAILABLE"
2. Check pipeline source configuration
3. Manually trigger pipeline to test

## Validation Commands

### Check All Lambda Functions
```powershell
aws lambda list-functions --query 'Functions[?starts_with(FunctionName, `futureim-ecommerce-ai-platform`)].{Name:FunctionName,Runtime:Runtime,Status:State}'
```

### Check API Gateway
```powershell
aws apigateway get-rest-apis --query 'items[?name==`futureim-ecommerce-ai-platform-api`].{Name:name,Id:id,Stage:stages}'
```

### Check S3 Buckets
```powershell
aws s3 ls | findstr futureim-ecommerce-ai-platform
```

### Check Pipeline Status
```powershell
aws codepipeline get-pipeline-state --name futureim-ecommerce-ai-platform-pipeline-dev
```

### Check CodeBuild Projects
```powershell
aws codebuild list-projects --query 'projects[?starts_with(@, `futureim-ecommerce-ai-platform`)]'
```

## Expected Outputs

### DEV Environment
```
api_gateway_id           = "xxxxxxxxxx"
api_gateway_url          = "https://xxxxxxxxxx.execute-api.us-east-2.amazonaws.com/dev"
frontend_bucket_name     = "futureim-ecommerce-ai-platform-frontend-dev"
frontend_website_url     = "http://futureim-ecommerce-ai-platform-frontend-dev.s3-website.us-east-2.amazonaws.com"
pipeline_name            = "futureim-ecommerce-ai-platform-pipeline-dev"
pipeline_url             = "https://console.aws.amazon.com/codesuite/codepipeline/pipelines/futureim-ecommerce-ai-platform-pipeline-dev/view?region=us-east-2"
lambda_execution_role_arn = "arn:aws:iam::450133579764:role/futureim-ecommerce-ai-platform-lambda-execution-dev"
```

### PROD Environment
```
api_gateway_id           = "yyyyyyyyyy"
api_gateway_url          = "https://yyyyyyyyyy.execute-api.us-east-2.amazonaws.com/prod"
frontend_bucket_name     = "futureim-ecommerce-ai-platform-frontend-prod"
frontend_website_url     = "http://futureim-ecommerce-ai-platform-frontend-prod.s3-website.us-east-2.amazonaws.com"
pipeline_name            = "futureim-ecommerce-ai-platform-pipeline-prod"
pipeline_url             = "https://console.aws.amazon.com/codesuite/codepipeline/pipelines/futureim-ecommerce-ai-platform-pipeline-prod/view?region=us-east-2"
lambda_execution_role_arn = "arn:aws:iam::450133579764:role/futureim-ecommerce-ai-platform-lambda-execution-prod"
```

## Success Criteria

- [ ] Terraform apply completes without errors
- [ ] All resources created in AWS
- [ ] GitHub connection approved and AVAILABLE
- [ ] Pipeline runs successfully through all stages
- [ ] All Lambda functions created and deployed
- [ ] API Gateway responds to requests
- [ ] Frontend loads in browser
- [ ] Frontend can communicate with API Gateway
- [ ] Both DEV and PROD environments working independently

## Rollback Plan

If deployment fails:

```powershell
# Destroy resources
terraform destroy -var-file="terraform.dev.tfvars"

# Or destroy specific resources
terraform destroy -target=module.cicd_pipeline -var-file="terraform.dev.tfvars"
```

## Cost Monitoring

After deployment, monitor costs:
- CodePipeline: $1/month per pipeline
- CodeBuild: ~$0.005/minute (only during builds)
- S3: ~$0.023/GB storage
- Lambda: Pay per invocation
- API Gateway: Pay per request
- DynamoDB: Pay per request (on-demand)

**Expected Monthly Cost**: $10-50 depending on usage

## Next Steps After Successful Deployment

1. **Configure Custom Domain** (Optional)
   - Set up Route 53 hosted zone
   - Create CloudFront distribution for frontend
   - Add custom domain to API Gateway

2. **Set Up Monitoring**
   - CloudWatch dashboards
   - X-Ray tracing
   - Log aggregation

3. **Configure Backups**
   - DynamoDB point-in-time recovery (already enabled)
   - S3 versioning (already enabled)
   - Terraform state backups

4. **Security Hardening**
   - Enable WAF for API Gateway
   - Configure VPC endpoints
   - Set up AWS Config rules
   - Enable GuardDuty

5. **Performance Optimization**
   - Configure Lambda reserved concurrency
   - Set up API Gateway caching
   - Optimize S3 bucket policies
   - Configure CloudFront CDN

---

**Ready to Deploy!** 🚀

Start with: `terraform init && terraform plan -var-file="terraform.dev.tfvars"`
