# Create Terraform Backend Resources
# Creates S3 bucket and DynamoDB table for Terraform state management

param(
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-2",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "futureim-ecommerce-ai-platform"
)

$ErrorActionPreference = "Stop"

Write-Host "Creating Terraform Backend Resources..." -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Project: $ProjectName" -ForegroundColor Cyan

$BucketName = "$ProjectName-terraform-state"
$TableName = "$ProjectName-terraform-locks"

# Create S3 bucket for Terraform state
Write-Host "`nCreating S3 bucket: $BucketName" -ForegroundColor Yellow
try {
    aws s3api create-bucket `
        --bucket $BucketName `
        --region $Region `
        --create-bucket-configuration LocationConstraint=$Region
    Write-Host "S3 bucket created successfully" -ForegroundColor Green
} catch {
    Write-Host "S3 bucket may already exist or error occurred: $_" -ForegroundColor Yellow
}

# Enable versioning
Write-Host "`nEnabling versioning on S3 bucket..." -ForegroundColor Yellow
aws s3api put-bucket-versioning `
    --bucket $BucketName `
    --versioning-configuration Status=Enabled
Write-Host "Versioning enabled" -ForegroundColor Green

# Enable encryption
Write-Host "`nEnabling encryption on S3 bucket..." -ForegroundColor Yellow
$EncryptionConfig = @'
{
    "Rules": [{
        "ApplyServerSideEncryptionByDefault": {
            "SSEAlgorithm": "AES256"
        }
    }]
}
'@
aws s3api put-bucket-encryption `
    --bucket $BucketName `
    --server-side-encryption-configuration $EncryptionConfig
Write-Host "Encryption enabled" -ForegroundColor Green

# Block public access
Write-Host "`nBlocking public access on S3 bucket..." -ForegroundColor Yellow
$PublicAccessConfig = @'
{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
}
'@
aws s3api put-public-access-block `
    --bucket $BucketName `
    --public-access-block-configuration $PublicAccessConfig
Write-Host "Public access blocked" -ForegroundColor Green

# Create DynamoDB table for state locking
Write-Host "`nCreating DynamoDB table: $TableName" -ForegroundColor Yellow
try {
    aws dynamodb create-table `
        --table-name $TableName `
        --attribute-definitions AttributeName=LockID,AttributeType=S `
        --key-schema AttributeName=LockID,KeyType=HASH `
        --billing-mode PAY_PER_REQUEST `
        --region $Region
    Write-Host "DynamoDB table created successfully" -ForegroundColor Green
} catch {
    Write-Host "DynamoDB table may already exist or error occurred: $_" -ForegroundColor Yellow
}

Write-Host "`n=== Backend Resources Created ===" -ForegroundColor Green
Write-Host "S3 Bucket: $BucketName" -ForegroundColor Cyan
Write-Host "DynamoDB Table: $TableName" -ForegroundColor Cyan
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Update terraform/backend.tfvars with these values" -ForegroundColor White
Write-Host "2. Run: terraform init -backend-config=backend.tfvars" -ForegroundColor White
