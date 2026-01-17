# Build script for Global Market Pulse Lambda deployment package
# Creates a deployment.zip with all dependencies

Write-Host "Building Global Market Pulse deployment package..." -ForegroundColor Green

# Create build directory
$buildDir = "build"
if (Test-Path $buildDir) {
    Remove-Item -Recurse -Force $buildDir
}
New-Item -ItemType Directory -Path $buildDir | Out-Null

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt -t $buildDir --quiet

# Copy source code
Write-Host "Copying source code..." -ForegroundColor Yellow
Copy-Item -Path "src/*" -Destination $buildDir -Recurse

# Create deployment package
Write-Host "Creating deployment package..." -ForegroundColor Yellow
$deploymentZip = "deployment.zip"
if (Test-Path $deploymentZip) {
    Remove-Item -Force $deploymentZip
}

# Change to build directory and create zip
Push-Location $buildDir
Compress-Archive -Path * -DestinationPath "../$deploymentZip"
Pop-Location

# Clean up build directory
Remove-Item -Recurse -Force $buildDir

Write-Host "Deployment package created: $deploymentZip" -ForegroundColor Green
Write-Host "Package size: $((Get-Item $deploymentZip).Length / 1MB) MB" -ForegroundColor Cyan
