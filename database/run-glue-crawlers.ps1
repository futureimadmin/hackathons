# Run Glue Crawlers to Create Athena Tables
# This script starts all Glue crawlers to scan prod buckets and create Athena tables

param(
    [string]$Region = "us-east-2"
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Starting Glue Crawlers" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$Crawlers = @(
    "market-intelligence-hub-crawler",
    "demand-insights-engine-crawler",
    "compliance-guardian-crawler",
    "retail-copilot-crawler",
    "global-market-pulse-crawler"
)

Write-Host "[Step 1/2] Starting crawlers..." -ForegroundColor Green

foreach ($Crawler in $Crawlers) {
    Write-Host "  Starting: $Crawler" -ForegroundColor Cyan
    
    aws glue start-crawler --name $Crawler --region $Region 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [OK] $Crawler started" -ForegroundColor Green
    } else {
        Write-Host "    [WARN] $Crawler may already be running" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[Step 2/2] Waiting for crawlers to complete..." -ForegroundColor Green
Write-Host "  This may take 2-3 minutes..." -ForegroundColor Cyan
Write-Host ""

Start-Sleep -Seconds 30

# Check crawler status
foreach ($Crawler in $Crawlers) {
    $Status = aws glue get-crawler --name $Crawler --region $Region --query 'Crawler.State' --output text
    Write-Host "  $Crawler : $Status" -ForegroundColor $(if ($Status -eq "READY") { "Green" } else { "Yellow" })
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Crawlers Started!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "What's happening:" -ForegroundColor Yellow
Write-Host "  1. Crawlers are scanning Parquet files in prod buckets" -ForegroundColor White
Write-Host "  2. Inferring schema from the data" -ForegroundColor White
Write-Host "  3. Creating/updating Athena tables automatically" -ForegroundColor White
Write-Host ""
Write-Host "Check progress:" -ForegroundColor Yellow
Write-Host "  AWS Console -> Glue -> Crawlers" -ForegroundColor Cyan
Write-Host ""
Write-Host "Once complete, AI Lambda functions can query the data!" -ForegroundColor Green
Write-Host ""
