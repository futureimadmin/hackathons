# Script to remove count parameters from Lambda integrations
# This fixes the "Invalid integration URI specified" error

$filePath = "$PSScriptRoot\modules\api-gateway\main.tf"

Write-Host "Reading file: $filePath" -ForegroundColor Cyan

$content = Get-Content $filePath -Raw

# Remove count parameters from all Lambda integrations
# Pattern: count = var.SOMETHING_lambda_invoke_arn != "" ? 1 : 0
$pattern = '\s*count\s*=\s*var\.\w+_lambda_invoke_arn\s*!=\s*""\s*\?\s*1\s*:\s*0\s*\n'
$content = $content -replace $pattern, ''

Write-Host "Removed count parameters from Lambda integrations" -ForegroundColor Green

# Write back to file
Set-Content -Path $filePath -Value $content -NoNewline

Write-Host "File updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the changes in: $filePath"
Write-Host "2. Run: terraform plan"
Write-Host "3. Run: terraform apply"
