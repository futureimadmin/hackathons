# Apply KMS Permissions Fix

## 🔧 Quick Fix

The CodePipeline role is missing KMS permissions. This has been fixed in the Terraform code.

## 🚀 Apply the Fix Now

```powershell
cd terraform
terraform apply -var-file="terraform.dev.tfvars"
```

**Expected output**: Terraform will update the CodePipeline IAM role policy (takes ~30 seconds)

## ✅ After Applying

The pipeline will automatically work. You can:

### Option 1: Wait for Automatic Retry
The pipeline may automatically retry the failed stage.

### Option 2: Manual Trigger
```powershell
# Trigger the pipeline manually
aws codepipeline start-pipeline-execution --name futureim-ecommerce-ai-platform-pipeline-dev
```

Or use AWS Console:
1. Go to CodePipeline
2. Select `futureim-ecommerce-ai-platform-pipeline-dev`
3. Click "Release change"

## 📊 What Was Fixed

Added KMS permissions to CodePipeline role:
- ✅ `kms:Decrypt`
- ✅ `kms:DescribeKey`
- ✅ `kms:Encrypt`
- ✅ `kms:ReEncrypt*`
- ✅ `kms:GenerateDataKey*`

## 🎯 Expected Result

Pipeline stages will now complete successfully:
1. ✅ Source (GitHub) - Will upload to S3 with KMS encryption
2. ✅ Infrastructure - Will deploy Terraform
3. ✅ Build Lambdas - Will build and deploy Lambda functions
4. ✅ Build Frontend - Will build and deploy React app

---

**Ready?** Run: `terraform apply -var-file="terraform.dev.tfvars"`
