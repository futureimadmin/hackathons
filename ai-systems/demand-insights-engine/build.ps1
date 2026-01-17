# Build script for Demand Insights Engine Lambda deployment package
# Creates a deployment.zip file with all dependencies

Write-Host "Building Demand Insights Engine Lambda deployment package..." -ForegroundColor Green

# Create temporary build directory
$buildDir = "build"
if (Test-Path $buildDir) {
    Remove-Item -Recurse -Force $buildDir
}
New-Item -ItemType Directory -Path $buildDir | Out-Null

# Copy source code
Write-Host "Copying source code..." -ForegroundColor Yellow
Copy-Item -Recurse -Path "src/*" -Destination $buildDir

# Install dependencies
Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt -t $buildDir --upgrade

# Create deployment package
Write-Host "Creating deployment.zip..." -ForegroundColor Yellow
$zipPath = "deployment.zip"
if (Test-Path $zipPath) {
    Remove-Item -Force $zipPath
}

# Change to build directory and create zip
Push-Location $buildDir
Compress-Archive -Path * -DestinationPath "../$zipPath"
Pop-Location

# Clean up build directory
Write-Host "Cleaning up..." -ForegroundColor Yellow
Remove-Item -Recurse -Force $buildDir

# Display package size
$size = (Get-Item $zipPath).Length / 1MB
Write-Host "Deployment package created: $zipPath ($([math]::Round($size, 2)) MB)" -ForegroundColor Green

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Deploy using Terraform:" -ForegroundColor White
Write-Host "   cd ../../terraform" -ForegroundColor Gray
Write-Host "   terraform init" -ForegroundColor Gray
Write-Host "   terraform plan" -ForegroundColor Gray
Write-Host "   terraform apply" -ForegroundColor Gray
Write-Host "`n2. Or upload directly to AWS Lambda:" -ForegroundColor White
Write-Host "   aws lambda update-function-code --function-name demand-insights-engine --zip-file fileb://deployment.zip" -ForegroundColor Gray

Write-Host "`nBuild complete!" -ForegroundColor Green
