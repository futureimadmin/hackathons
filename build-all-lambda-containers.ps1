# Master Build Script - Build and Push All Lambda Container Images
# Builds both data pipeline and AI systems Lambda functions

param(
    [string]$Region = "us-east-2",
    [string]$AccountId = "450133579764"
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Master Lambda Container Build Script" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will build and push ALL Lambda container images:" -ForegroundColor White
Write-Host "  - Data Pipeline Lambdas (2)" -ForegroundColor White
Write-Host "  - AI Systems Lambdas (5)" -ForegroundColor White
Write-Host ""
Write-Host "Total: 7 Lambda functions" -ForegroundColor Yellow
Write-Host ""

$StartTime = Get-Date

# Build Data Pipeline Lambdas
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "PART 1: Building Data Pipeline Lambda Functions" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Push-Location lambda-functions
& .\build-and-push-containers.ps1 -Region $Region -AccountId $AccountId
$DataPipelineResult = $LASTEXITCODE
Pop-Location

if ($DataPipelineResult -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] Data Pipeline Lambda build failed!" -ForegroundColor Red
    Write-Host "Stopping execution. Please fix errors and try again." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host ""

# Build AI Systems Lambdas
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "PART 2: Building AI Systems Lambda Functions" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

Push-Location ai-systems
& .\build-and-push-all-containers.ps1 -Region $Region -AccountId $AccountId
$AISystemsResult = $LASTEXITCODE
Pop-Location

if ($AISystemsResult -ne 0) {
    Write-Host ""
    Write-Host "[ERROR] AI Systems Lambda build failed!" -ForegroundColor Red
    exit 1
}

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Host ""
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "ALL LAMBDA CONTAINERS BUILT AND PUSHED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Build Duration: $($Duration.Minutes):$($Duration.Seconds)" -ForegroundColor White
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Data Pipeline Lambdas: 2/2" -ForegroundColor Green
Write-Host "  AI Systems Lambdas: 5/5" -ForegroundColor Green
Write-Host "  Total: 7/7" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Deploy Lambda functions with Terraform:" -ForegroundColor White
Write-Host "   cd terraform" -ForegroundColor Cyan
Write-Host "   terraform apply" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Test the data pipeline:" -ForegroundColor White
Write-Host "   cd database" -ForegroundColor Cyan
Write-Host "   .\quick-data-pipeline.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Monitor Lambda execution in CloudWatch Logs" -ForegroundColor White
Write-Host ""
