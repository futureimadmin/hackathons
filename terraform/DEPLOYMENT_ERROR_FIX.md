# Deployment Error Fix Guide

## Errors Encountered

### Error 1: CodeStar Connection Name Too Long
```
Error: creating CodeStar Connections Connection (futureim-ecommerce-ai-platform-github-dev): 
operation error CodeStar connections: CreateConnection, https response error StatusCode: 400, 
api error ValidationException: 1 validation error detected: 
Value 'futureim-ecommerce-ai-platform-github-dev' at 'connectionName' failed to satisfy constraint: 
Member must have length less than or equal to 32
```

**Cause**: Connection name was 43 characters, AWS limit is 32 characters

**Fix Applied**: ✅ Changed connection name in `terraform/modules/cicd-pipeline/main.tf`
- Old: `futureim-ecommerce-ai-platform-github-dev` (43 chars)
- New: `futureim-github-dev` (21 chars)

### Error 2: S3 Frontend Bucket Already Exists
```
Error: creating S3 Bucket (futureim-ecommerce-ai-platform-frontend-dev): 
operation error S3: CreateBucket, https response error StatusCode: 409, 
BucketAlreadyOwnedByYou
```

**Cause**: The S3 frontend bucket was created in a previous deployment and exists in AWS but not in Terraform state

**Fix Options**:

#### Option A: Import Existing Bucket (Recommended)
```powershell
cd terraform
terraform import module.frontend_bucket.aws_s3_bucket.frontend futureim-ecommerce-ai-platform-frontend-dev
```

This will import the existing bucket into Terraform state without recreating it.

#### Option B: Use Existing Bucket Module
If you already have a frontend bucket module from a previous deployment, you can remove the new module and use the existing one.

#### Option C: Delete and Recreate (Not Recommended)
Only if the bucket is empty and you don't need its contents:
```powershell
# WARNING: This will delete the bucket and all its contents
# Only use if you're sure you don't need the existing bucket
# aws s3 rb s3://futureim-ecommerce-ai-platform-frontend-dev --force
```

## Quick Fix Steps

### Step 1: Fix CodeStar Connection Name
✅ **Already Fixed** - The code has been updated

### Step 2: Import S3 Frontend Bucket
```powershell
cd terraform

# Import the existing bucket
terraform import module.frontend_bucket.aws_s3_bucket.frontend futureim-ecommerce-ai-platform-frontend-dev

# If you get an error about the bucket not existing, that's OK - proceed to next step
```

### Step 3: Re-run Terraform Apply
```powershell
# Plan to see what will be created
terraform plan -var-file="terraform.dev.tfvars"

# Apply the changes
terraform apply -var-file="terraform.dev.tfvars"
```

## Alternative: Use Automated Fix Script

Run the provided fix script:
```powershell
cd terraform
.\fix-deployment-errors.ps1
```

Then re-run terraform apply:
```powershell
terraform apply -var-file="terraform.dev.tfvars"
```

## Expected Outcome

After applying the fixes:

1. ✅ CodeStar connection will be created with shorter name: `futureim-github-dev`
2. ✅ S3 frontend bucket will be imported (if it exists) or created (if it doesn't)
3. ✅ All other resources will be created successfully
4. ✅ Pipeline will be ready to use

## Verification

After successful deployment, verify:

```powershell
# Check CodeStar connection
terraform output github_connection_arn

# Check frontend bucket
terraform output frontend_bucket_name
terraform output frontend_website_url

# Check pipeline
terraform output pipeline_name
terraform output pipeline_url
```

## If You Still Get Errors

### S3 Bucket Import Fails
If the import command fails, the bucket might not exist. In that case:
1. Remove the import command
2. Just run `terraform apply` again
3. Terraform will create a new bucket

### CodeStar Connection Still Fails
If you still get a name length error:
1. Check `terraform/modules/cicd-pipeline/main.tf` line 210
2. Verify the name is: `futureim-github-${var.environment}`
3. For dev environment, this should be: `futureim-github-dev` (21 characters)

### Other Resources Already Exist
If other resources already exist (like CodeBuild projects, CodePipeline, etc.), you can import them:

```powershell
# Import CodeBuild projects
terraform import module.cicd_pipeline.aws_codebuild_project.infrastructure futureim-ecommerce-ai-platform-infrastructure-dev
terraform import module.cicd_pipeline.aws_codebuild_project.java_lambda futureim-ecommerce-ai-platform-java-lambda-dev
terraform import module.cicd_pipeline.aws_codebuild_project.python_lambdas futureim-ecommerce-ai-platform-python-lambdas-dev
terraform import module.cicd_pipeline.aws_codebuild_project.frontend futureim-ecommerce-ai-platform-frontend-dev

# Import CodePipeline
terraform import module.cicd_pipeline.aws_codepipeline.main futureim-ecommerce-ai-platform-pipeline-dev

# Import S3 artifacts bucket
terraform import module.cicd_pipeline.aws_s3_bucket.pipeline_artifacts futureim-ecommerce-ai-platform-pipeline-artifacts-dev
```

## Clean Slate Option (Nuclear Option)

If you want to start completely fresh and don't need any existing resources:

```powershell
# WARNING: This will destroy ALL resources in the dev environment
# Only use if you're absolutely sure you want to start over

cd terraform
terraform destroy -var-file="terraform.dev.tfvars"

# Then deploy fresh
terraform apply -var-file="terraform.dev.tfvars"
```

## Summary

**Fixes Applied**:
1. ✅ CodeStar connection name shortened to 21 characters
2. ✅ Import script provided for existing S3 bucket

**Action Required**:
1. Import existing S3 bucket (if it exists)
2. Re-run terraform apply

**Expected Time**: 2-3 minutes to fix and redeploy

---

**Status**: Errors identified and fixes provided
**Next Step**: Run the import command and terraform apply
