#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Fix S3 bucket permissions for Terraform state

.DESCRIPTION
    This script checks and fixes permissions for the Terraform state S3 bucket
#>

$BUCKET_NAME = "futureim-ecommerce-ai-platform-terraform-state"
$REGION = "us-east-2"

$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "`n============================================================" $COLOR_CYAN
Write-ColorOutput "   S3 Bucket Permission Check" $COLOR_CYAN
Write-ColorOutput "============================================================" $COLOR_CYAN

# Get current AWS identity
Write-ColorOutput "`nChecking AWS identity..." $COLOR_CYAN
try {
    $identity = aws sts get-caller-identity --output json | ConvertFrom-Json
    $accountId = $identity.Account
    $userId = $identity.UserId
    $arn = $identity.Arn
    
    Write-ColorOutput "[OK] AWS Account: $accountId" $COLOR_GREEN
    Write-ColorOutput "[OK] User ARN: $arn" $COLOR_GREEN
} catch {
    Write-ColorOutput "[X] Failed to get AWS identity. Are you logged in?" $COLOR_RED
    exit 1
}

# Check if bucket exists
Write-ColorOutput "`nChecking if bucket exists..." $COLOR_CYAN
try {
    $bucketCheck = aws s3api head-bucket --bucket $BUCKET_NAME --region $REGION 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[OK] Bucket '$BUCKET_NAME' exists" $COLOR_GREEN
    } else {
        Write-ColorOutput "[X] Bucket '$BUCKET_NAME' does not exist or you don't have access" $COLOR_RED
        Write-ColorOutput "`nWould you like to create it? (yes/no)" $COLOR_YELLOW
        $create = Read-Host
        if ($create -eq "yes") {
            Write-ColorOutput "`nCreating bucket..." $COLOR_CYAN
            aws s3 mb "s3://$BUCKET_NAME" --region $REGION
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "[OK] Bucket created" $COLOR_GREEN
            } else {
                Write-ColorOutput "[X] Failed to create bucket" $COLOR_RED
                exit 1
            }
        } else {
            exit 1
        }
    }
} catch {
    Write-ColorOutput "[X] Error checking bucket: $_" $COLOR_RED
    exit 1
}

# Check bucket location
Write-ColorOutput "`nChecking bucket location..." $COLOR_CYAN
try {
    $location = aws s3api get-bucket-location --bucket $BUCKET_NAME --output json | ConvertFrom-Json
    $bucketRegion = if ($location.LocationConstraint) { $location.LocationConstraint } else { "us-east-1" }
    
    if ($bucketRegion -eq $REGION) {
        Write-ColorOutput "[OK] Bucket is in correct region: $bucketRegion" $COLOR_GREEN
    } else {
        Write-ColorOutput "[!] WARNING: Bucket is in region '$bucketRegion' but Terraform is configured for '$REGION'" $COLOR_YELLOW
        Write-ColorOutput "    You should update terraform/main.tf to use region '$bucketRegion'" $COLOR_YELLOW
    }
} catch {
    Write-ColorOutput "[!] Could not determine bucket location" $COLOR_YELLOW
}

# Try to list objects (test read permission)
Write-ColorOutput "`nTesting read permissions..." $COLOR_CYAN
try {
    $objects = aws s3api list-objects-v2 --bucket $BUCKET_NAME --region $REGION --max-items 1 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[OK] Read permission verified" $COLOR_GREEN
    } else {
        Write-ColorOutput "[X] No read permission" $COLOR_RED
        Write-ColorOutput "Error: $objects" $COLOR_RED
    }
} catch {
    Write-ColorOutput "[X] Read permission test failed: $_" $COLOR_RED
}

# Try to write a test object (test write permission)
Write-ColorOutput "`nTesting write permissions..." $COLOR_CYAN
try {
    $testContent = "test-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $testFile = [System.IO.Path]::GetTempFileName()
    $testContent | Out-File -FilePath $testFile -Encoding UTF8
    
    aws s3 cp $testFile "s3://$BUCKET_NAME/.terraform-permission-test" --region $REGION 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[OK] Write permission verified" $COLOR_GREEN
        
        # Clean up test file
        aws s3 rm "s3://$BUCKET_NAME/.terraform-permission-test" --region $REGION 2>&1 | Out-Null
    } else {
        Write-ColorOutput "[X] No write permission" $COLOR_RED
    }
    
    Remove-Item $testFile -ErrorAction SilentlyContinue
} catch {
    Write-ColorOutput "[X] Write permission test failed: $_" $COLOR_RED
}

# Check bucket policy
Write-ColorOutput "`nChecking bucket policy..." $COLOR_CYAN
try {
    $policy = aws s3api get-bucket-policy --bucket $BUCKET_NAME --region $REGION 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[OK] Bucket has a policy" $COLOR_GREEN
        Write-ColorOutput "`nCurrent policy:" $COLOR_CYAN
        $policy | ConvertFrom-Json | Select-Object -ExpandProperty Policy | ConvertFrom-Json | ConvertTo-Json -Depth 10
    } else {
        Write-ColorOutput "[!] No bucket policy found (this is OK if using IAM user permissions)" $COLOR_YELLOW
    }
} catch {
    Write-ColorOutput "[!] Could not retrieve bucket policy" $COLOR_YELLOW
}

# Recommendations
Write-ColorOutput "`n============================================================" $COLOR_CYAN
Write-ColorOutput "   Recommendations" $COLOR_CYAN
Write-ColorOutput "============================================================" $COLOR_CYAN

Write-ColorOutput "`nIf you're getting 403 Forbidden errors:" $COLOR_YELLOW
Write-ColorOutput "1. Ensure your IAM user/role has these permissions:" $COLOR_CYAN
Write-ColorOutput "   - s3:ListBucket on arn:aws:s3:::$BUCKET_NAME" $COLOR_CYAN
Write-ColorOutput "   - s3:GetObject on arn:aws:s3:::$BUCKET_NAME/*" $COLOR_CYAN
Write-ColorOutput "   - s3:PutObject on arn:aws:s3:::$BUCKET_NAME/*" $COLOR_CYAN
Write-ColorOutput "   - s3:DeleteObject on arn:aws:s3:::$BUCKET_NAME/*" $COLOR_CYAN

Write-ColorOutput "`n2. Check if bucket has a policy that denies access" $COLOR_CYAN

Write-ColorOutput "`n3. Verify you're using the correct AWS profile:" $COLOR_CYAN
Write-ColorOutput "   aws configure list" $COLOR_CYAN

Write-ColorOutput "`n4. If bucket is owned by another account, you need cross-account access" $COLOR_CYAN

Write-ColorOutput "`n============================================================" $COLOR_GREEN
Write-ColorOutput "   Check Complete" $COLOR_GREEN
Write-ColorOutput "============================================================" $COLOR_GREEN
