#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup Terraform backend and initialize infrastructure

.DESCRIPTION
    This script prepares the Terraform backend (S3 + DynamoDB) and initializes Terraform
    for deploying the eCommerce AI Platform infrastructure.

.EXAMPLE
    .\setup-terraform.ps1
#>

$PROJECT_NAME = "futureim-ecommerce-ai-platform"
$AWS_REGION = "us-east-2"
$STATE_BUCKET = "${PROJECT_NAME}-terraform-state"
$LOCK_TABLE = "${PROJECT_NAME}-terraform-locks"

$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput @"
============================================================
   Terraform Infrastructure Setup
============================================================
"@ $COLOR_CYAN

# Check prerequisites
Write-ColorOutput "`nChecking prerequisites..." $COLOR_CYAN

try {
    aws --version | Out-Null
    Write-ColorOutput "[OK] AWS CLI installed" $COLOR_GREEN
} catch {
    Write-ColorOutput "[X] AWS CLI not found" $COLOR_RED
    exit 1
}

try {
    terraform --version | Out-Null
    Write-ColorOutput "[OK] Terraform installed" $COLOR_GREEN
} catch {
    Write-ColorOutput "[X] Terraform not found. Please install Terraform first." $COLOR_RED
    exit 1
}

try {
    aws sts get-caller-identity | Out-Null
    Write-ColorOutput "[OK] AWS credentials configured" $COLOR_GREEN
} catch {
    Write-ColorOutput "[X] AWS credentials not configured" $COLOR_RED
    exit 1
}

# Check if MySQL and JWT parameters are configured
Write-ColorOutput "`nChecking SSM Parameter Store configuration..." $COLOR_CYAN

$requiredParams = @(
    "/${PROJECT_NAME}/dev/mysql/host",
    "/${PROJECT_NAME}/dev/mysql/user",
    "/${PROJECT_NAME}/dev/mysql/password",
    "/${PROJECT_NAME}/dev/mysql/database",
    "/${PROJECT_NAME}/dev/jwt/secret"
)

$missingParams = @()
foreach ($param in $requiredParams) {
    try {
        aws ssm get-parameter --name $param --region $AWS_REGION 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  [OK] $param" $COLOR_GREEN
        } else {
            $missingParams += $param
            Write-ColorOutput "  [X] $param" $COLOR_RED
        }
    } catch {
        $missingParams += $param
        Write-ColorOutput "  [X] $param" $COLOR_RED
    }
}

if ($missingParams.Count -gt 0) {
    Write-ColorOutput "`n[!] Missing required parameters in SSM Parameter Store!" $COLOR_YELLOW
    Write-ColorOutput "Run this first: .\deployment\configure-mysql-connection.ps1" $COLOR_YELLOW
    $continue = Read-Host "`nContinue anyway? (yes/no)"
    if ($continue -ne "yes") {
        exit 1
    }
}

# Create S3 bucket for Terraform state
Write-ColorOutput "`nSetting up Terraform backend..." $COLOR_CYAN

Write-ColorOutput "Creating S3 bucket: $STATE_BUCKET" $COLOR_CYAN
aws s3 mb s3://$STATE_BUCKET --region $AWS_REGION 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "[OK] S3 bucket created" $COLOR_GREEN
} else {
    Write-ColorOutput "[OK] S3 bucket already exists" $COLOR_GREEN
}

# Enable versioning
Write-ColorOutput "Enabling versioning on S3 bucket..." $COLOR_CYAN
aws s3api put-bucket-versioning `
    --bucket $STATE_BUCKET `
    --versioning-configuration Status=Enabled `
    --region $AWS_REGION

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "[OK] Versioning enabled" $COLOR_GREEN
} else {
    Write-ColorOutput "[X] Failed to enable versioning" $COLOR_RED
}

# Enable encryption
Write-ColorOutput "Enabling encryption on S3 bucket..." $COLOR_CYAN
$encryptionConfig = @{
    Rules = @(
        @{
            ApplyServerSideEncryptionByDefault = @{
                SSEAlgorithm = "AES256"
            }
        }
    )
} | ConvertTo-Json -Depth 10 -Compress

aws s3api put-bucket-encryption `
    --bucket $STATE_BUCKET `
    --server-side-encryption-configuration $encryptionConfig `
    --region $AWS_REGION

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "[OK] Encryption enabled" $COLOR_GREEN
} else {
    Write-ColorOutput "[X] Failed to enable encryption" $COLOR_RED
}

# Block public access
Write-ColorOutput "Blocking public access..." $COLOR_CYAN
aws s3api put-public-access-block `
    --bucket $STATE_BUCKET `
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" `
    --region $AWS_REGION

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "[OK] Public access blocked" $COLOR_GREEN
} else {
    Write-ColorOutput "[X] Failed to block public access" $COLOR_RED
}

# Create DynamoDB table for state locking
Write-ColorOutput "`nCreating DynamoDB table for state locking: $LOCK_TABLE" $COLOR_CYAN

aws dynamodb create-table `
    --table-name $LOCK_TABLE `
    --attribute-definitions AttributeName=LockID,AttributeType=S `
    --key-schema AttributeName=LockID,KeyType=HASH `
    --billing-mode PAY_PER_REQUEST `
    --region $AWS_REGION 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "[OK] DynamoDB table created" $COLOR_GREEN
    Write-ColorOutput "  Waiting for table to be active..." $COLOR_CYAN
    aws dynamodb wait table-exists --table-name $LOCK_TABLE --region $AWS_REGION
    Write-ColorOutput "[OK] Table is active" $COLOR_GREEN
} else {
    Write-ColorOutput "[OK] DynamoDB table already exists" $COLOR_GREEN
}

# Initialize Terraform
Write-ColorOutput "`n============================================================" $COLOR_CYAN
Write-ColorOutput "   Initializing Terraform" $COLOR_CYAN
Write-ColorOutput "============================================================" $COLOR_CYAN

Write-ColorOutput "`nRunning terraform init..." $COLOR_CYAN

terraform init -backend-config="backend.tfvars"

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "`n[OK] Terraform initialized successfully!" $COLOR_GREEN
} else {
    Write-ColorOutput "`n[X] Terraform initialization failed" $COLOR_RED
    exit 1
}

# Validate Terraform configuration
Write-ColorOutput "`nValidating Terraform configuration..." $COLOR_CYAN

terraform validate

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "[OK] Terraform configuration is valid" $COLOR_GREEN
} else {
    Write-ColorOutput "[X] Terraform configuration has errors" $COLOR_RED
    exit 1
}

# Format Terraform files
Write-ColorOutput "`nFormatting Terraform files..." $COLOR_CYAN
terraform fmt -recursive

# Summary
Write-ColorOutput "`n============================================================" $COLOR_GREEN
Write-ColorOutput "   Terraform Setup Complete!" $COLOR_GREEN
Write-ColorOutput "============================================================" $COLOR_GREEN

Write-ColorOutput "`nBackend Configuration:" $COLOR_CYAN
Write-ColorOutput "  S3 Bucket: $STATE_BUCKET" $COLOR_CYAN
Write-ColorOutput "  DynamoDB Table: $LOCK_TABLE" $COLOR_CYAN
Write-ColorOutput "  Region: $AWS_REGION" $COLOR_CYAN

Write-ColorOutput "`nNext Steps:" $COLOR_YELLOW
Write-ColorOutput "1. Review the Terraform plan:" $COLOR_YELLOW
Write-ColorOutput "   terraform plan" $COLOR_YELLOW
Write-ColorOutput "" $COLOR_YELLOW
Write-ColorOutput "2. Apply the infrastructure:" $COLOR_YELLOW
Write-ColorOutput "   terraform apply" $COLOR_YELLOW
Write-ColorOutput "" $COLOR_YELLOW
Write-ColorOutput "3. For production deployment:" $COLOR_YELLOW
Write-ColorOutput "   terraform plan -var='environment=prod'" $COLOR_YELLOW
Write-ColorOutput "   terraform apply -var='environment=prod'" $COLOR_YELLOW

Write-ColorOutput "`nImportant Notes:" $COLOR_YELLOW
Write-ColorOutput "- JWT tokens are configured to NOT EXPIRE" $COLOR_YELLOW
Write-ColorOutput "- MySQL connection: 172.20.10.4:3306" $COLOR_YELLOW
Write-ColorOutput "- Ensure network connectivity from AWS to MySQL (VPN/Direct Connect)" $COLOR_YELLOW
Write-ColorOutput "- Review deployment/mysql-connection-setup.md for network setup" $COLOR_YELLOW

exit 0
