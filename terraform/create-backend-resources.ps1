#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Create S3 bucket and DynamoDB table for Terraform backend

.DESCRIPTION
    This script creates the required AWS resources for Terraform state management:
    - S3 bucket for state storage
    - DynamoDB table for state locking
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

Write-ColorOutput "`n============================================================" $COLOR_CYAN
Write-ColorOutput "   Terraform Backend Resources Setup" $COLOR_CYAN
Write-ColorOutput "============================================================" $COLOR_CYAN

Write-ColorOutput "`nThis will create:" $COLOR_CYAN
Write-ColorOutput "  - S3 Bucket: $STATE_BUCKET" $COLOR_CYAN
Write-ColorOutput "  - DynamoDB Table: $LOCK_TABLE" $COLOR_CYAN
Write-ColorOutput "  - Region: $AWS_REGION" $COLOR_CYAN

# Check AWS CLI
Write-ColorOutput "`nChecking prerequisites..." $COLOR_CYAN
try {
    $identity = aws sts get-caller-identity --output json 2>&1 | ConvertFrom-Json
    Write-ColorOutput "[OK] AWS CLI configured" $COLOR_GREEN
    Write-ColorOutput "    Account: $($identity.Account)" $COLOR_GREEN
    Write-ColorOutput "    User: $($identity.Arn)" $COLOR_GREEN
} catch {
    Write-ColorOutput "[X] AWS CLI not configured or not authenticated" $COLOR_RED
    exit 1
}

$confirm = Read-Host "`nProceed with resource creation? (yes/no)"
if ($confirm -ne "yes") {
    Write-ColorOutput "Cancelled." $COLOR_YELLOW
    exit 0
}

# Create S3 bucket
Write-ColorOutput "`n[1/5] Creating S3 bucket..." $COLOR_CYAN
try {
    # Check if bucket already exists
    $bucketExists = aws s3api head-bucket --bucket $STATE_BUCKET --region $AWS_REGION 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[OK] S3 bucket already exists" $COLOR_YELLOW
    } else {
        # Create bucket
        if ($AWS_REGION -eq "us-east-1") {
            aws s3api create-bucket --bucket $STATE_BUCKET --region $AWS_REGION 2>&1 | Out-Null
        } else {
            aws s3api create-bucket --bucket $STATE_BUCKET --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION 2>&1 | Out-Null
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "[OK] S3 bucket created" $COLOR_GREEN
        } else {
            Write-ColorOutput "[X] Failed to create S3 bucket" $COLOR_RED
            exit 1
        }
    }
} catch {
    Write-ColorOutput "[X] Error creating S3 bucket: $_" $COLOR_RED
    exit 1
}

# Enable versioning
Write-ColorOutput "`n[2/5] Enabling bucket versioning..." $COLOR_CYAN
try {
    aws s3api put-bucket-versioning --bucket $STATE_BUCKET --region $AWS_REGION --versioning-configuration Status=Enabled 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[OK] Versioning enabled" $COLOR_GREEN
    } else {
        Write-ColorOutput "[X] Failed to enable versioning" $COLOR_RED
    }
} catch {
    Write-ColorOutput "[X] Error enabling versioning: $_" $COLOR_RED
}

# Enable encryption
Write-ColorOutput "`n[3/5] Enabling bucket encryption..." $COLOR_CYAN
try {
    $encryptionConfig = @{
        Rules = @(
            @{
                ApplyServerSideEncryptionByDefault = @{
                    SSEAlgorithm = "AES256"
                }
                BucketKeyEnabled = $true
            }
        )
    } | ConvertTo-Json -Depth 10 -Compress
    
    aws s3api put-bucket-encryption --bucket $STATE_BUCKET --region $AWS_REGION --server-side-encryption-configuration $encryptionConfig 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[OK] Encryption enabled (AES256)" $COLOR_GREEN
    } else {
        Write-ColorOutput "[X] Failed to enable encryption" $COLOR_RED
    }
} catch {
    Write-ColorOutput "[X] Error enabling encryption: $_" $COLOR_RED
}

# Block public access
Write-ColorOutput "`n[4/5] Blocking public access..." $COLOR_CYAN
try {
    aws s3api put-public-access-block --bucket $STATE_BUCKET --region $AWS_REGION --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[OK] Public access blocked" $COLOR_GREEN
    } else {
        Write-ColorOutput "[X] Failed to block public access" $COLOR_RED
    }
} catch {
    Write-ColorOutput "[X] Error blocking public access: $_" $COLOR_RED
}

# Create DynamoDB table
Write-ColorOutput "`n[5/5] Creating DynamoDB table..." $COLOR_CYAN
try {
    # Check if table already exists
    $tableExists = aws dynamodb describe-table --table-name $LOCK_TABLE --region $AWS_REGION 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[OK] DynamoDB table already exists" $COLOR_YELLOW
    } else {
        # Create table
        aws dynamodb create-table `
            --table-name $LOCK_TABLE `
            --attribute-definitions AttributeName=LockID,AttributeType=S `
            --key-schema AttributeName=LockID,KeyType=HASH `
            --billing-mode PAY_PER_REQUEST `
            --region $AWS_REGION 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "[OK] DynamoDB table created" $COLOR_GREEN
            Write-ColorOutput "    Waiting for table to become active..." $COLOR_CYAN
            
            # Wait for table to be active
            $maxWait = 30
            $waited = 0
            while ($waited -lt $maxWait) {
                Start-Sleep -Seconds 2
                $waited += 2
                $tableStatus = aws dynamodb describe-table --table-name $LOCK_TABLE --region $AWS_REGION --query "Table.TableStatus" --output text 2>&1
                if ($tableStatus -eq "ACTIVE") {
                    Write-ColorOutput "[OK] Table is active" $COLOR_GREEN
                    break
                }
            }
        } else {
            Write-ColorOutput "[X] Failed to create DynamoDB table" $COLOR_RED
            exit 1
        }
    }
} catch {
    Write-ColorOutput "[X] Error creating DynamoDB table: $_" $COLOR_RED
    exit 1
}

# Summary
Write-ColorOutput "`n============================================================" $COLOR_GREEN
Write-ColorOutput "   Setup Complete!" $COLOR_GREEN
Write-ColorOutput "============================================================" $COLOR_GREEN

Write-ColorOutput "`nCreated Resources:" $COLOR_CYAN
Write-ColorOutput "  S3 Bucket: $STATE_BUCKET" $COLOR_GREEN
Write-ColorOutput "    - Region: $AWS_REGION" $COLOR_GREEN
Write-ColorOutput "    - Versioning: Enabled" $COLOR_GREEN
Write-ColorOutput "    - Encryption: AES256" $COLOR_GREEN
Write-ColorOutput "    - Public Access: Blocked" $COLOR_GREEN

Write-ColorOutput "`n  DynamoDB Table: $LOCK_TABLE" $COLOR_GREEN
Write-ColorOutput "    - Region: $AWS_REGION" $COLOR_GREEN
Write-ColorOutput "    - Billing: Pay-per-request" $COLOR_GREEN

Write-ColorOutput "`nNext Steps:" $COLOR_YELLOW
Write-ColorOutput "1. Run: terraform init" $COLOR_CYAN
Write-ColorOutput "2. Run: terraform plan" $COLOR_CYAN
Write-ColorOutput "3. Run: terraform apply" $COLOR_CYAN

Write-ColorOutput "`nBackend Configuration:" $COLOR_CYAN
Write-ColorOutput "  The backend is already configured in terraform/main.tf" $COLOR_GREEN
Write-ColorOutput "  Bucket: $STATE_BUCKET" $COLOR_GREEN
Write-ColorOutput "  Key: dev/terraform.tfstate" $COLOR_GREEN
Write-ColorOutput "  Region: $AWS_REGION" $COLOR_GREEN
Write-ColorOutput "  DynamoDB Table: $LOCK_TABLE" $COLOR_GREEN

exit 0
