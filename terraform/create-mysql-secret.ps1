# Create MySQL Password Secret for DMS
# This script creates an AWS Secrets Manager secret for the MySQL password

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$Password = "SaiesaShanmukha@123",
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-2"
)

$SecretName = "futureim-ecommerce-ai-platform-mysql-password-$Environment"

Write-Host "Creating MySQL password secret..." -ForegroundColor Cyan
Write-Host "Secret Name: $SecretName" -ForegroundColor Gray
Write-Host "Region: $Region" -ForegroundColor Gray

# Create the secret
$result = aws secretsmanager create-secret `
    --name $SecretName `
    --description "MySQL password for DMS replication ($Environment)" `
    --secret-string $Password `
    --region $Region `
    2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Secret created successfully!" -ForegroundColor Green
    
    # Get the secret ARN
    $secretInfo = aws secretsmanager describe-secret `
        --secret-id $SecretName `
        --region $Region `
        --query 'ARN' `
        --output text
    
    Write-Host "`nSecret ARN:" -ForegroundColor Cyan
    Write-Host $secretInfo -ForegroundColor White
    
    Write-Host "`nAdd this to your terraform.dev.tfvars:" -ForegroundColor Yellow
    Write-Host "mysql_password_secret_arn = `"$secretInfo`"" -ForegroundColor White
    
} elseif ($result -like "*ResourceExistsException*") {
    Write-Host "✓ Secret already exists!" -ForegroundColor Yellow
    
    # Get the existing secret ARN
    $secretInfo = aws secretsmanager describe-secret `
        --secret-id $SecretName `
        --region $Region `
        --query 'ARN' `
        --output text
    
    Write-Host "`nSecret ARN:" -ForegroundColor Cyan
    Write-Host $secretInfo -ForegroundColor White
    
    Write-Host "`nAdd this to your terraform.dev.tfvars:" -ForegroundColor Yellow
    Write-Host "mysql_password_secret_arn = `"$secretInfo`"" -ForegroundColor White
    
} else {
    Write-Host "✗ Failed to create secret" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    exit 1
}
