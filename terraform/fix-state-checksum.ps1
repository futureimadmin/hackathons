# Quick fix for Terraform state checksum mismatch
# This script removes the corrupted digest from DynamoDB

param(
    [string]$Environment = "dev",
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2"
)

$LockTable = "$ProjectName-terraform-locks"
$StateKey = "$Environment/terraform.tfstate"

Write-Host "Fixing Terraform state checksum mismatch" -ForegroundColor Yellow
Write-Host "Lock Table: $LockTable" -ForegroundColor White
Write-Host "State Key: $StateKey" -ForegroundColor White
Write-Host ""

Write-Host "1. Checking DynamoDB lock table..." -ForegroundColor Blue

# Find the digest entry in DynamoDB
$digestKey = "$ProjectName-terraform-state/$StateKey-md5"
Write-Host "   Looking for digest key: $digestKey" -ForegroundColor Gray

try {
    # Check if the digest item exists
    $digestItem = aws dynamodb get-item --table-name $LockTable --key "{`"LockID`":{`"S`":`"$digestKey`"}}" --region $Region 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $digestItem) {
        Write-Host "   Found corrupted digest entry" -ForegroundColor Yellow
        Write-Host "   Deleting corrupted digest..." -ForegroundColor Blue
        
        # Delete the corrupted digest entry
        aws dynamodb delete-item --table-name $LockTable --key "{`"LockID`":{`"S`":`"$digestKey`"}}" --region $Region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   Corrupted digest deleted successfully" -ForegroundColor Green
        } else {
            Write-Host "   Failed to delete digest entry" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "   No digest entry found - checking for other lock entries..." -ForegroundColor Yellow
        
        # Scan for any entries related to our state
        $allItems = aws dynamodb scan --table-name $LockTable --region $Region --query "Items[?contains(LockID.S, '$StateKey')].LockID.S" --output text 2>$null
        
        if ($allItems -and $allItems -ne "None") {
            Write-Host "   Found related entries: $allItems" -ForegroundColor Yellow
            Write-Host "   Clearing all related entries..." -ForegroundColor Blue
            
            $itemList = $allItems -split "`t"
            foreach ($item in $itemList) {
                if ($item.Trim()) {
                    Write-Host "   Deleting: $item" -ForegroundColor Gray
                    aws dynamodb delete-item --table-name $LockTable --key "{`"LockID`":{`"S`":`"$item`"}}" --region $Region 2>$null
                }
            }
        } else {
            Write-Host "   No related entries found" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "   Error accessing DynamoDB: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "2. Verifying S3 state file..." -ForegroundColor Blue

$StateBucket = "$ProjectName-terraform-state"
try {
    # Check if state file exists and get its info
    $stateInfo = aws s3api head-object --bucket $StateBucket --key $StateKey --region $Region 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   State file exists in S3" -ForegroundColor Green
        
        # Get the actual file to check if it's valid
        aws s3 cp "s3://$StateBucket/$StateKey" "./temp-state.json" --region $Region --quiet 2>$null
        
        if (Test-Path "./temp-state.json") {
            $stateContent = Get-Content "./temp-state.json" -Raw
            Remove-Item "./temp-state.json" -Force
            
            if ($stateContent.Trim() -eq "" -or $stateContent.Length -lt 10) {
                Write-Host "   WARNING: State file appears to be empty or corrupted" -ForegroundColor Yellow
                Write-Host "   You may need to import existing resources or start fresh" -ForegroundColor Yellow
            } else {
                try {
                    $stateJson = $stateContent | ConvertFrom-Json
                    Write-Host "   State file appears to be valid JSON" -ForegroundColor Green
                } catch {
                    Write-Host "   WARNING: State file is not valid JSON" -ForegroundColor Yellow
                }
            }
        }
    } else {
        Write-Host "   State file does not exist in S3" -ForegroundColor Yellow
        Write-Host "   This is normal for a fresh deployment" -ForegroundColor White
    }
} catch {
    Write-Host "   Error checking S3 state: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "Fix complete!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Try: terraform init" -ForegroundColor White
Write-Host "  2. Then: terraform plan -var-file=`"terraform.dev.tfvars`"" -ForegroundColor White
Write-Host ""
Write-Host "If the issue persists:" -ForegroundColor Yellow
Write-Host "  - Wait 1-2 minutes for S3 eventual consistency" -ForegroundColor White
Write-Host "  - Or run: terraform init -reconfigure" -ForegroundColor White