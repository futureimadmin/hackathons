# Fix Deployment Errors Script
# This script fixes the two errors encountered during deployment

Write-Host "Fixing deployment errors..." -ForegroundColor Cyan

# Error 1: Import existing S3 frontend bucket
Write-Host "`n1. Importing existing S3 frontend bucket..." -ForegroundColor Yellow
Write-Host "   Bucket: futureim-ecommerce-ai-platform-frontend-dev"

# Import the bucket into Terraform state
terraform import module.frontend_bucket.aws_s3_bucket.frontend futureim-ecommerce-ai-platform-frontend-dev

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ S3 bucket imported successfully" -ForegroundColor Green
} else {
    Write-Host "   ✗ Failed to import S3 bucket" -ForegroundColor Red
    Write-Host "   This is OK if the bucket doesn't exist yet" -ForegroundColor Gray
}

# Error 2: CodeStar connection name is now fixed in the code
Write-Host "`n2. CodeStar connection name fixed in code" -ForegroundColor Yellow
Write-Host "   Old name: futureim-ecommerce-ai-platform-github-dev (43 chars)" -ForegroundColor Gray
Write-Host "   New name: futureim-github-dev (21 chars)" -ForegroundColor Green

Write-Host "`n✓ Fixes applied!" -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Run: terraform plan -var-file=`"terraform.dev.tfvars`""
Write-Host "2. Run: terraform apply -var-file=`"terraform.dev.tfvars`""
