# Build script for Retail Copilot Lambda deployment package
# Creates a deployment.zip with all dependencies

Write-Host "Building Retail Copilot Lambda deployment package..." -ForegroundColor Green

# Clean previous build
if (Test-Path "deployment.zip") {
    Remove-Item "deployment.zip"
    Write-Host "Removed previous deployment.zip" -ForegroundColor Yellow
}

if (Test-Path "package") {
    Remove-Item -Recurse -Force "package"
    Write-Host "Removed previous package directory" -ForegroundColor Yellow
}

# Create package directory
New-Item -ItemType Directory -Path "package" | Out-Null
Write-Host "Created package directory" -ForegroundColor Cyan

# Install dependencies
Write-Host "Installing Python dependencies..." -ForegroundColor Cyan
pip install -r requirements.txt -t package --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error installing dependencies" -ForegroundColor Red
    exit 1
}

# Copy source code
Write-Host "Copying source code..." -ForegroundColor Cyan
Copy-Item -Path "src\*" -Destination "package\" -Recurse

# Create deployment package
Write-Host "Creating deployment.zip..." -ForegroundColor Cyan
Push-Location package
Compress-Archive -Path * -DestinationPath ..\deployment.zip
Pop-Location

# Clean up
Remove-Item -Recurse -Force "package"

# Get file size
$fileSize = (Get-Item "deployment.zip").Length / 1MB
Write-Host "Deployment package created: deployment.zip ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green

Write-Host "`nBuild complete! Deploy with:" -ForegroundColor Green
Write-Host "  cd ../../terraform" -ForegroundColor White
Write-Host "  terraform apply" -ForegroundColor White
