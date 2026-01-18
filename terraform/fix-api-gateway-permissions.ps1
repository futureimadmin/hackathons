# Fix API Gateway Lambda Permissions
# This script comments out Lambda permission resources that reference non-existent Lambda functions

Write-Host "Fixing API Gateway Lambda permissions..." -ForegroundColor Cyan

$apiGatewayMainFile = Join-Path $PSScriptRoot "modules\api-gateway\main.tf"

if (-not (Test-Path $apiGatewayMainFile)) {
    Write-Host "[X] File not found: $apiGatewayMainFile" -ForegroundColor Red
    exit 1
}

Write-Host "Reading file..." -ForegroundColor Yellow
$content = Get-Content $apiGatewayMainFile -Raw

# Backup original file
$backupFile = "$apiGatewayMainFile.backup"
Copy-Item $apiGatewayMainFile $backupFile -Force
Write-Host "[OK] Backup created: $backupFile" -ForegroundColor Green

# Comment out Lambda permission for auth (lines 369-376)
$content = $content -replace '(?m)^(# Lambda permission for API Gateway to invoke auth function\r?\nresource "aws_lambda_permission" "api_gateway_auth" \{[\s\S]*?\r?\n\})', '# COMMENTED OUT - Lambda function not deployed yet
# Uncomment after deploying auth Lambda function
# $1'

# The other permissions already have count parameters, so they won't fail
# But we need to fix the CloudWatch Logs issue

Write-Host "Writing fixed file..." -ForegroundColor Yellow
Set-Content -Path $apiGatewayMainFile -Value $content -NoNewline

Write-Host "[OK] File fixed successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Changes made:" -ForegroundColor Yellow
Write-Host "  - Commented out aws_lambda_permission.api_gateway_auth" -ForegroundColor White
Write-Host "  - Other Lambda permissions already have count parameters" -ForegroundColor White
Write-Host ""
Write-Host "To restore original file:" -ForegroundColor Yellow
Write-Host "  Copy-Item $backupFile $apiGatewayMainFile -Force" -ForegroundColor White
