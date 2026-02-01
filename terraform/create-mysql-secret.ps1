# Create MySQL Password Secret
# Creates AWS Secrets Manager secret for MySQL password

param(
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-2",
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "dev",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    
    [Parameter(Mandatory=$true)]
    [string]$MySQLPassword
)

$ErrorActionPreference = "Stop"

Write-Host "Creating MySQL Password Secret..." -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Cyan

$SecretName = "$ProjectName-mysql-password-$Environment"

# Create secret
Write-Host "`nCreating secret: $SecretName" -ForegroundColor Yellow
try {
    $Result = aws secretsmanager create-secret `
        --name $SecretName `
        --description "MySQL password for DMS replication ($Environment)" `
        --secret-string $MySQLPassword `
        --region $Region | ConvertFrom-Json
    
    Write-Host "Secret created successfully" -ForegroundColor Green
    Write-Host "`n=== Secret Details ===" -ForegroundColor Green
    Write-Host "Secret Name: $($Result.Name)" -ForegroundColor Cyan
    Write-Host "Secret ARN: $($Result.ARN)" -ForegroundColor Cyan
    Write-Host "`nIMPORTANT: Copy the ARN above!" -ForegroundColor Yellow
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "1. Update terraform/terraform.$Environment.tfvars" -ForegroundColor White
    Write-Host "2. Set: mysql_password_secret_arn = `"$($Result.ARN)`"" -ForegroundColor White
    
    # Return ARN for scripting
    return $Result.ARN
} catch {
    Write-Host "Error creating secret: $_" -ForegroundColor Red
    Write-Host "`nIf secret already exists, retrieve ARN with:" -ForegroundColor Yellow
    Write-Host "aws secretsmanager describe-secret --secret-id $SecretName --region $Region" -ForegroundColor White
    exit 1
}
