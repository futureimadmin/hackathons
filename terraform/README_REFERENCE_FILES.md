# Terraform Reference Files

## main-complete.tf.reference

This file is a **reference file only** and should NOT be used directly with Terraform.

It was created as a guide showing all available modules that could be added to the main Terraform configuration. However, it causes duplicate module errors if present alongside `main.tf`.

### What's in this file?

- Example configurations for all Lambda modules
- Example configurations for additional services
- Reference for how to wire modules together

### How to use it?

1. **DO NOT** rename it back to `.tf` extension
2. Open it to see example module configurations
3. Copy specific module blocks to `main.tf` if needed
4. Modify the copied blocks for your specific needs

### Current Status

The `main.tf` file already includes:
- ✅ VPC
- ✅ KMS
- ✅ IAM
- ✅ DynamoDB Users Table
- ✅ S3 Data Lakes (all 5 systems)
- ✅ API Gateway (with placeholder Lambda ARNs)

### What's NOT included (and available in reference file)?

- Lambda function modules (auth, analytics, market-intelligence, etc.)
- DMS replication
- Glue crawlers
- Athena queries
- EventBridge rules
- Batch jobs
- Monitoring/alerting

### Why aren't Lambda modules included?

We're using a **two-phase deployment approach**:

1. **Phase 1 (Current):** Deploy API Gateway with placeholder Lambda ARNs
2. **Phase 2 (Later):** Deploy Lambda functions separately (manual or CI/CD)

This allows you to:
- Get the API Gateway URL immediately
- Update the frontend with the API URL
- Deploy Lambda functions when ready
- Use CI/CD pipeline for Lambda deployments

### Adding Lambda Modules Later

If you want to deploy Lambda functions with Terraform (instead of CI/CD), you can:

1. Open `main-complete.tf.reference`
2. Copy the Lambda module blocks you need
3. Paste into `main.tf`
4. Update the API Gateway module to use the Lambda module outputs instead of placeholder ARNs
5. Run `terraform apply`

Example:
```hcl
# In main.tf, add:
module "analytics_lambda" {
  source = "./modules/analytics-lambda"
  # ... configuration ...
}

# Then update API Gateway module:
module "api_gateway" {
  # Change from:
  analytics_lambda_invoke_arn = "arn:aws:apigateway:..."
  
  # To:
  analytics_lambda_invoke_arn = module.analytics_lambda.invoke_arn
}
```

## Other Reference Files

- `terraform.tfvars.example` - Example variable values
- `backend.tfvars.example` - Example backend configuration

## Questions?

See:
- `docs/API_GATEWAY_DEPLOYMENT_GUIDE.md` - Complete deployment guide
- `terraform/QUICK_START.md` - Quick reference
- `docs/TERRAFORM_MODULES_GUIDE.md` - Module documentation
