# Deploy API Gateway Infrastructure
# This script deploys the API Gateway with placeholder Lambda integrations

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "API Gateway Deployment Script" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Check if Terraform is installed
Write-Host "Step 1: Checking Terraform installation..." -ForegroundColor Yellow
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "[X] Terraform is not installed or not in PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Terraform:" -ForegroundColor Yellow
    Write-Host "1. Download from: https://www.terraform.io/downloads" -ForegroundColor White
    Write-Host "2. Extract to a folder (e.g., C:\terraform)" -ForegroundColor White
    Write-Host "3. Add to PATH or run from that folder" -ForegroundColor White
    Write-Host ""
    exit 1
}

$terraformVersion = terraform version
Write-Host "[OK] Terraform is installed: $($terraformVersion.Split("`n")[0])" -ForegroundColor Green
Write-Host ""

# Check if Lambda authorizer is packaged
Write-Host "Step 2: Checking Lambda authorizer package..." -ForegroundColor Yellow
$authorizerZip = Join-Path $PSScriptRoot "modules\api-gateway\lambda\authorizer.zip"
if (-not (Test-Path $authorizerZip)) {
    Write-Host "[X] Lambda authorizer package not found" -ForegroundColor Red
    Write-Host "Running package script..." -ForegroundColor Yellow
    Set-Location (Join-Path $PSScriptRoot "modules\api-gateway\lambda")
    .\package.ps1
    Set-Location $PSScriptRoot
    
    if (-not (Test-Path $authorizerZip)) {
        Write-Host "[X] Failed to create Lambda authorizer package" -ForegroundColor Red
        exit 1
    }
}
Write-Host "[OK] Lambda authorizer package exists" -ForegroundColor Green
Write-Host ""

# Initialize Terraform
Write-Host "Step 3: Initializing Terraform..." -ForegroundColor Yellow
terraform init
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Terraform init failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Terraform initialized" -ForegroundColor Green
Write-Host ""

# Plan Terraform changes
Write-Host "Step 4: Planning Terraform changes..." -ForegroundColor Yellow
terraform plan -out=tfplan
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Terraform plan failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Terraform plan complete" -ForegroundColor Green
Write-Host ""

# Ask for confirmation
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Ready to deploy API Gateway infrastructure" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will create:" -ForegroundColor Yellow
Write-Host "  - API Gateway REST API" -ForegroundColor White
Write-Host "  - Lambda authorizer function" -ForegroundColor White
Write-Host "  - API Gateway resources and methods" -ForegroundColor White
Write-Host "  - CloudWatch log groups" -ForegroundColor White
Write-Host "  - IAM roles and policies" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Lambda integrations use placeholder ARNs" -ForegroundColor Yellow
Write-Host "      Lambda functions must be deployed separately" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Do you want to proceed? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "[!] Deployment cancelled" -ForegroundColor Yellow
    exit 0
}

# Apply Terraform changes
Write-Host ""
Write-Host "Step 5: Applying Terraform changes..." -ForegroundColor Yellow
terraform apply tfplan
if ($LASTEXITCODE -ne 0) {
    Write-Host "[X] Terraform apply failed" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Terraform apply complete" -ForegroundColor Green
Write-Host ""

# Get API Gateway URL
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$apiUrl = terraform output -raw api_gateway_url
Write-Host "API Gateway URL: $apiUrl" -ForegroundColor Green
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Update frontend .env.production with API Gateway URL" -ForegroundColor White
Write-Host "2. Deploy Lambda functions (auth-service, analytics-service, etc.)" -ForegroundColor White
Write-Host "3. Update API Gateway integrations with actual Lambda ARNs" -ForegroundColor White
Write-Host "4. Test API endpoints" -ForegroundColor White
Write-Host ""

# Save API URL to file for frontend update
$envFile = Join-Path $PSScriptRoot "..\frontend\.env.production"
if (Test-Path $envFile) {
    Write-Host "Updating frontend .env.production..." -ForegroundColor Yellow
    $content = "VITE_API_URL=$apiUrl"
    Set-Content -Path $envFile -Value $content -Encoding UTF8
    Write-Host "[OK] Frontend .env.production updated" -ForegroundColor Green
} else {
    Write-Host "[!] Frontend .env.production not found at: $envFile" -ForegroundColor Yellow
    Write-Host "    Please create it manually with: VITE_API_URL=$apiUrl" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Deployment script complete!" -ForegroundColor Green
