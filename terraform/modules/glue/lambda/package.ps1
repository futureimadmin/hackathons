# Package Lambda function for Glue Crawler trigger
# This script creates a ZIP file for deployment

$ErrorActionPreference = "Stop"

Write-Host "Packaging Lambda function for Glue Crawler trigger..." -ForegroundColor Cyan

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Create temporary directory
$tempDir = Join-Path $scriptDir "temp"
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir | Out-Null

# Copy Python file to temp directory and rename to index.py
Copy-Item (Join-Path $scriptDir "trigger_crawler.py") (Join-Path $tempDir "index.py")

# Create ZIP file
$zipPath = Join-Path $scriptDir "trigger_crawler.zip"
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

# Compress files
Compress-Archive -Path (Join-Path $tempDir "*") -DestinationPath $zipPath

# Clean up temp directory
Remove-Item $tempDir -Recurse -Force

Write-Host "✓ Lambda function packaged successfully: $zipPath" -ForegroundColor Green
Write-Host ""
Write-Host "File size: $([math]::Round((Get-Item $zipPath).Length / 1KB, 2)) KB" -ForegroundColor Gray
