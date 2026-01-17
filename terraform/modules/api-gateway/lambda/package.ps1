# Package Lambda authorizer function
# Creates a deployment package with dependencies

Write-Host "Packaging Lambda authorizer..." -ForegroundColor Cyan

# Check if Node.js is installed
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Node.js is not installed" -ForegroundColor Red
    exit 1
}

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
npm install --production

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Create deployment package
Write-Host "Creating deployment package..." -ForegroundColor Yellow

# Remove existing zip if it exists
if (Test-Path "authorizer.zip") {
    Remove-Item "authorizer.zip" -Force
}

# Create zip file
if (Get-Command 7z -ErrorAction SilentlyContinue) {
    # Use 7-Zip if available
    7z a -tzip authorizer.zip index.js package.json node_modules
} elseif (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
    # Use PowerShell Compress-Archive
    Compress-Archive -Path index.js,package.json,node_modules -DestinationPath authorizer.zip -Force
} else {
    Write-Host "Error: No zip utility found (7z or Compress-Archive)" -ForegroundColor Red
    exit 1
}

if ($LASTEXITCODE -eq 0 -or (Test-Path "authorizer.zip")) {
    $size = (Get-Item "authorizer.zip").Length / 1MB
    Write-Host "✓ Package created: authorizer.zip ($([math]::Round($size, 2)) MB)" -ForegroundColor Green
} else {
    Write-Host "Error: Failed to create deployment package" -ForegroundColor Red
    exit 1
}

Write-Host "`nPackaging complete!" -ForegroundColor Green
