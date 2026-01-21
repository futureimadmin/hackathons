# Fix Terraform State Corruption Issues
# This script resolves S3/DynamoDB checksum mismatches

param(
    [string]$Environment = "dev",
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2",
    [switch]$Force
)

$StateBucket = "$ProjectName-terraform-state"
$StateKey = "$Environment/terraform.tfstate"
$LockTable = "$ProjectName-terraform-locks"

Write-Host "Fixing Terraform State Corruption" -ForegroundColor Yellow
Write-Host "Bucket: $StateBucket" -ForegroundColor White
Write-Host "Key: $StateKey" -ForegroundColor White
Write-Host "Lock Table: $LockTable" -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host ""

# Function to check if AWS CLI is available
function Test-AWSCli {
    try {
        aws --version | Out-Null
        return $true
    } catch {
        Write-Host "ERROR: AWS CLI is not installed or not in PATH" -ForegroundColor Red
        return $false
    }
}

if (-not (Test-AWSCli)) {
    exit 1
}

Write-Host "1. Checking current state..." -ForegroundColor Blue

# Check if S3 bucket exists
try {
    $bucketExists = aws s3api head-bucket --bucket $StateBucket --region $Region 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   S3 bucket '$StateBucket' does not exist" -ForegroundColor Red
        Write-Host "   Run CloudFormation deployment first to create backend resources" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "   S3 bucket exists" -ForegroundColor Green
} catch {
    Write-Host "   Error checking S3 bucket: $_" -ForegroundColor Red
    exit 1
}

# Check if DynamoDB table exists
try {
    $tableExists = aws dynamodb describe-table --table-name $LockTable --region $Region 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   DynamoDB table '$LockTable' does not exist" -ForegroundColor Red
        Write-Host "   Run CloudFormation deployment first to create backend resources" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "   DynamoDB table exists" -ForegroundColor Green
} catch {
    Write-Host "   Error checking DynamoDB table: $_" -ForegroundColor Red
    exit 1
}

# Check if state file exists in S3
Write-Host "2. Checking state file..." -ForegroundColor Blue
try {
    $stateExists = aws s3api head-object --bucket $StateBucket --key $StateKey --region $Region 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   State file exists in S3" -ForegroundColor Green
        
        # Get state file size
        $stateSize = aws s3api head-object --bucket $StateBucket --key $StateKey --region $Region --query "ContentLength" --output text 2>$null
        Write-Host "   State file size: $stateSize bytes" -ForegroundColor White
        
        if ($stateSize -eq "0") {
            Write-Host "   WARNING: State file is empty!" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   State file does not exist in S3" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   State file does not exist in S3" -ForegroundColor Yellow
}

# Check DynamoDB lock entries
Write-Host "3. Checking DynamoDB lock entries..." -ForegroundColor Blue
try {
    $lockEntries = aws dynamodb scan --table-name $LockTable --region $Region --query "Items[].LockID.S" --output text 2>$null
    if ($lockEntries -and $lockEntries -ne "None") {
        Write-Host "   Found lock entries: $lockEntries" -ForegroundColor Yellow
        Write-Host "   These may need to be cleared" -ForegroundColor Yellow
    } else {
        Write-Host "   No lock entries found" -ForegroundColor Green
    }
} catch {
    Write-Host "   Error checking lock entries: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. Recommended fixes:" -ForegroundColor Blue

# Option 1: Clear DynamoDB locks
Write-Host "   Option 1: Clear DynamoDB lock entries" -ForegroundColor Yellow
if ($lockEntries -and $lockEntries -ne "None") {
    if (-not $Force) {
        $clearLocks = Read-Host "   Clear DynamoDB lock entries? (y/N)"
    } else {
        $clearLocks = "y"
    }
    
    if ($clearLocks -eq "y" -or $clearLocks -eq "Y") {
        Write-Host "   Clearing lock entries..." -ForegroundColor Blue
        $lockList = $lockEntries -split "`t"
        foreach ($lockId in $lockList) {
            if ($lockId.Trim()) {
                Write-Host "   Deleting lock: $lockId" -ForegroundColor Gray
                aws dynamodb delete-item --table-name $LockTable --key "{`"LockID`":{`"S`":`"$lockId`"}}" --region $Region 2>$null
            }
        }
        Write-Host "   Lock entries cleared" -ForegroundColor Green
    }
}

# Option 2: Reset state file
Write-Host ""
Write-Host "   Option 2: Reset state file (DESTRUCTIVE)" -ForegroundColor Yellow
Write-Host "   This will delete the current state and start fresh" -ForegroundColor Red

if (-not $Force) {
    $resetState = Read-Host "   Reset state file? This will lose all Terraform state! (y/N)"
} else {
    $resetState = "N"  # Don't auto-reset state as it's destructive
}

if ($resetState -eq "y" -or $resetState -eq "Y") {
    Write-Host "   Backing up current state..." -ForegroundColor Blue
    $backupKey = "$StateKey.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    aws s3 cp "s3://$StateBucket/$StateKey" "s3://$StateBucket/$backupKey" --region $Region 2>$null
    
    Write-Host "   Deleting current state..." -ForegroundColor Blue
    aws s3 rm "s3://$StateBucket/$StateKey" --region $Region 2>$null
    
    Write-Host "   State file reset complete" -ForegroundColor Green
    Write-Host "   Backup saved as: $backupKey" -ForegroundColor White
}

# Option 3: Manual verification
Write-Host ""
Write-Host "   Option 3: Manual verification steps" -ForegroundColor Yellow
Write-Host "   1. Download state file: aws s3 cp s3://$StateBucket/$StateKey ./terraform.tfstate.backup --region $Region" -ForegroundColor White
Write-Host "   2. Verify state file is valid JSON" -ForegroundColor White
Write-Host "   3. Clear DynamoDB locks manually if needed" -ForegroundColor White
Write-Host "   4. Try terraform init again" -ForegroundColor White

Write-Host ""
Write-Host "5. Next steps:" -ForegroundColor Blue
Write-Host "   After fixing the issue, try:" -ForegroundColor White
Write-Host "   terraform init" -ForegroundColor Gray
Write-Host "   terraform plan -var-file=`"terraform.dev.tfvars`"" -ForegroundColor Gray

Write-Host ""
Write-Host "State fix attempt complete!" -ForegroundColor Green