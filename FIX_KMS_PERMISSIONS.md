# Fix KMS Permissions Error

## Error

```
[GitHub] Upload to S3 failed with the following error: 
User: arn:aws:sts::450133579764:assumed-role/futureim-ecommerce-ai-platform-codepipeline-role-dev/1768723745984 
is not authorized to perform: kms:GenerateDataKey on resource: 
arn:aws:kms:us-east-2:450133579764:key/7e0e7421-e43b-4ef3-84a2-6236e35d9779 
because no identity-based policy allows the kms:GenerateDataKey action
```

## Root Cause

The CodePipeline role needs KMS permissions to encrypt/decrypt artifacts when uploading to S3. The S3 artifacts bucket uses KMS encryption, but the CodePipeline role was missing the necessary KMS permissions.

## Fix Applied ✅

**File**: `terraform/modules/cicd-pipeline/main.tf`

Added KMS permissions to the CodePipeline IAM role policy:

```hcl
{
  Effect = "Allow"
  Action = [
    "kms:Decrypt",
    "kms:DescribeKey",
    "kms:Encrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*"
  ]
  Resource = var.kms_key_arn
}
```

## Apply the Fix

### Step 1: Update Terraform

```powershell
cd terraform

# Plan the changes
terraform plan -var-file="terraform.dev.tfvars"

# Apply the changes
terraform apply -var-file="terraform.dev.tfvars"
```

### Step 2: Verify the Fix

After applying, the CodePipeline role will have the necessary KMS permissions. The pipeline should now be able to:
- ✅ Upload source code from GitHub to S3
- ✅ Encrypt artifacts with KMS
- ✅ Pass artifacts between pipeline stages

### Step 3: Re-run the Pipeline

The pipeline should automatically retry, or you can manually trigger it:

1. Go to AWS Console → CodePipeline
2. Select: `futureim-ecommerce-ai-platform-pipeline-dev`
3. Click "Release change"

## What Changed

### Before (Missing KMS Permissions)
```hcl
resource "aws_iam_role_policy" "codepipeline" {
  # ... S3 permissions
  # ... CodeBuild permissions
  # ... CodeStar permissions
  # ❌ NO KMS permissions
}
```

### After (With KMS Permissions)
```hcl
resource "aws_iam_role_policy" "codepipeline" {
  # ... S3 permissions
  # ... CodeBuild permissions
  # ... CodeStar permissions
  # ✅ KMS permissions added
  {
    Effect = "Allow"
    Action = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    Resource = var.kms_key_arn
  }
}
```

## Why This Happened

The S3 artifacts bucket is configured with KMS encryption:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn  # ← Uses KMS
    }
  }
}
```

When CodePipeline tries to upload artifacts to this bucket, it needs to:
1. Generate a data key using KMS
2. Encrypt the artifact with that key
3. Store the encrypted artifact in S3

Without KMS permissions, step 1 fails with the error you saw.

## Expected Outcome

After applying this fix:
- ✅ Pipeline Source stage will complete successfully
- ✅ Artifacts will be encrypted and stored in S3
- ✅ Pipeline will proceed to Infrastructure stage
- ✅ All subsequent stages will work correctly

## Verification Commands

```powershell
# Check the updated IAM policy
aws iam get-role-policy --role-name futureim-ecommerce-ai-platform-codepipeline-role-dev --policy-name futureim-ecommerce-ai-platform-codepipeline-policy-dev

# Check pipeline status
aws codepipeline get-pipeline-state --name futureim-ecommerce-ai-platform-pipeline-dev
```

## Time to Apply

- Terraform apply: ~30 seconds (only updating IAM policy)
- Pipeline retry: Automatic or manual trigger

---

**Status**: ✅ Fix applied in Terraform code
**Action Required**: Run `terraform apply` to update the IAM policy
**Expected Result**: Pipeline will run successfully
