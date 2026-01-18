# Script to fix syntax errors caused by removing count parameters
# The issue: opening brace { is on the same line as the first parameter

$filePath = "$PSScriptRoot\modules\api-gateway\main.tf"

Write-Host "Reading file: $filePath" -ForegroundColor Cyan

$content = Get-Content $filePath -Raw

# Fix the syntax error: {  rest_api_id should be {\n  rest_api_id
# Pattern: opening brace followed by two spaces and rest_api_id on same line
$pattern = '\{\s\s(rest_api_id)'
$replacement = "{`n  `$1"

$content = $content -replace $pattern, $replacement

Write-Host "Fixed brace syntax errors" -ForegroundColor Green

# Write back to file
Set-Content -Path $filePath -Value $content -NoNewline

Write-Host "File updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the changes in: $filePath"
Write-Host "2. Run: terraform plan"
Write-Host "3. Run: terraform apply"
