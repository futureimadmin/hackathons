# Deploy Infrastructure with Automatic Cleanup
# This script handles common deployment issues automatically

param(
    [string]$Environment = "dev",
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2"
)

Write-Host "Deploying Infrastructure with Automatic Cleanup" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Project: $ProjectName" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Step 1: Fix any secrets issues
Write-Host "Step 1: Checking and fixing secrets issues..." -ForegroundColor Blue
& ".\fix-secrets-deletion.ps1" -Environment $Environment -ProjectName $ProjectName -Region $Region

if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to fix secrets issues" -ForegroundColor Red
    exit 1
}

# Step 2: Import existing resources
Write-Host ""
Write-Host "Step 2: Importing existing resources..." -ForegroundColor Blue
& ".\import-existing-resources.ps1" -Environment $Environment -ProjectName $ProjectName -Region $Region

# Step 3: Initialize Terraform
Write-Host ""
Write-Host "Step 3: Initializing Terraform..." -ForegroundColor Blue
terraform init

if ($LASTEXITCODE -ne 0) {
    Write-Host "Terraform init failed" -ForegroundColor Red
    exit 1
}

# Step 4: Plan deployment
Write-Host ""
Write-Host "Step 4: Planning deployment..." -ForegroundColor Blue
terraform plan -var-file="terraform.dev.tfvars" -out=tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "Terraform plan failed" -ForegroundColor Red
    exit 1
}

# Step 5: Apply deployment
Write-Host ""
Write-Host "Step 5: Applying deployment..." -ForegroundColor Blue
terraform apply tfplan

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Blue
    Write-Host "1. Complete GitHub connection authorization in AWS Console" -ForegroundColor White
    Write-Host "2. Pipeline will automatically trigger on GitHub commits" -ForegroundColor White
    Write-Host "3. Monitor pipeline execution in AWS CodePipeline console" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "Deployment failed!" -ForegroundColor Red
    Write-Host "Check the error messages above for details" -ForegroundColor Yellow
    exit 1
}