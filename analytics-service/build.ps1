# Build script for Analytics Service Lambda
# Creates deployment package with dependencies

Write-Host "Building Analytics Service Lambda..." -ForegroundColor Cyan

# Create build directory
$buildDir = "build"
if (Test-Path $buildDir) {
    Remove-Item -Recurse -Force $buildDir
}
New-Item -ItemType Directory -Path $buildDir | Out-Null

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt -t $buildDir

# Copy source code
Write-Host "Copying source code..." -ForegroundColor Yellow
Copy-Item -Recurse src/* $buildDir/

# Create ZIP file
Write-Host "Creating deployment package..." -ForegroundColor Yellow
$zipFile = "analytics-service.zip"
if (Test-Path $zipFile) {
    Remove-Item $zipFile
}

# Change to build directory and create zip
Push-Location $buildDir
Compress-Archive -Path * -DestinationPath "../$zipFile"
Pop-Location

# Clean up build directory
Remove-Item -Recurse -Force $buildDir

Write-Host "Build complete: $zipFile" -ForegroundColor Green
Write-Host "Package size: $((Get-Item $zipFile).Length / 1MB) MB" -ForegroundColor Green
