# Fix Secrets Manager Deletion Issues
# This script handles secrets that are scheduled for deletion

param(
    [string]$Environment = "dev",
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2"
)

$SecretName = "$ProjectName-github-token-$Environment"

Write-Host "Fixing Secrets Manager Deletion Issues" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Secret Name: $SecretName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Check secret status
Write-Host "1. Checking secret status..." -ForegroundColor Blue
try {
    $secret = aws secretsmanager describe-secret --secret-id $SecretName --region $Region --output json 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        $secretInfo = $secret | ConvertFrom-Json
        $deletionDate = $secretInfo.DeletedDate
        
        if ($deletionDate) {
            Write-Host "   Secret is scheduled for deletion on: $deletionDate" -ForegroundColor Yellow
            Write-Host "   Attempting to restore secret..." -ForegroundColor Blue
            
            # Restore the secret
            aws secretsmanager restore-secret --secret-id $SecretName --region $Region
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   Secret restored successfully!" -ForegroundColor Green
                Write-Host "   You can now run terraform apply again" -ForegroundColor White
            } else {
                Write-Host "   Failed to restore secret" -ForegroundColor Red
                Write-Host "   Trying alternative approach..." -ForegroundColor Yellow
                
                # Force delete and recreate approach
                Write-Host "   Force deleting secret immediately..." -ForegroundColor Blue
                aws secretsmanager delete-secret --secret-id $SecretName --force-delete-without-recovery --region $Region
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   Secret force deleted successfully!" -ForegroundColor Green
                    Write-Host "   You can now run terraform apply again" -ForegroundColor White
                } else {
                    Write-Host "   Failed to force delete secret" -ForegroundColor Red
                    Write-Host "   Manual intervention required" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "   Secret exists and is not scheduled for deletion" -ForegroundColor Green
        }
    } else {
        Write-Host "   Secret does not exist" -ForegroundColor Green
        Write-Host "   You can proceed with terraform apply" -ForegroundColor White
    }
} catch {
    Write-Host "   Error checking secret: $_" -ForegroundColor Red
}

# Check for other related secrets that might have the same issue
Write-Host ""
Write-Host "2. Checking for other related secrets..." -ForegroundColor Blue

$relatedSecrets = @(
    "$ProjectName-mysql-password-$Environment"
)

foreach ($relatedSecret in $relatedSecrets) {
    try {
        $secret = aws secretsmanager describe-secret --secret-id $relatedSecret --region $Region --output json 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            $secretInfo = $secret | ConvertFrom-Json
            $deletionDate = $secretInfo.DeletedDate
            
            if ($deletionDate) {
                Write-Host "   Secret '$relatedSecret' is also scheduled for deletion" -ForegroundColor Yellow
                Write-Host "   Restoring..." -ForegroundColor Blue
                
                aws secretsmanager restore-secret --secret-id $relatedSecret --region $Region
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "   Restored successfully!" -ForegroundColor Green
                } else {
                    Write-Host "   Failed to restore" -ForegroundColor Red
                }
            } else {
                Write-Host "   Secret '$relatedSecret' is OK" -ForegroundColor Green
            }
        }
    } catch {
        # Secret doesn't exist, which is fine
    }
}

Write-Host ""
Write-Host "3. Next steps:" -ForegroundColor Blue
Write-Host "   1. Wait 1-2 minutes for AWS to process the changes" -ForegroundColor White
Write-Host "   2. Run: terraform plan -var-file=`"terraform.dev.tfvars`"" -ForegroundColor White
Write-Host "   3. Run: terraform apply -var-file=`"terraform.dev.tfvars`"" -ForegroundColor White
Write-Host ""
Write-Host "If the issue persists:" -ForegroundColor Yellow
Write-Host "   - The secret may need more time to be fully deleted" -ForegroundColor White
Write-Host "   - Try again in 5-10 minutes" -ForegroundColor White
Write-Host "   - Or use a different secret name temporarily" -ForegroundColor White

Write-Host ""
Write-Host "Secrets cleanup complete!" -ForegroundColor Green