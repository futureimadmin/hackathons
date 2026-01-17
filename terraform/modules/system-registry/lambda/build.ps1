# Build Lambda deployment packages for System Registry

Write-Host "Building System Registry Lambda functions..." -ForegroundColor Cyan

# Build System Registration Lambda
Write-Host "`nBuilding system-registration Lambda..." -ForegroundColor Yellow
Set-Location system_registration

# Create deployment package
if (Test-Path "package") {
    Remove-Item -Recurse -Force package
}
New-Item -ItemType Directory -Path package | Out-Null

# Install dependencies
pip install -r requirements.txt -t package --quiet

# Copy handler
Copy-Item handler.py package/

# Create zip
if (Test-Path "../system-registration.zip") {
    Remove-Item "../system-registration.zip"
}
Compress-Archive -Path package/* -DestinationPath ../system-registration.zip

Write-Host "Created system-registration.zip" -ForegroundColor Green

# Build Infrastructure Provisioner Lambda
Set-Location ../infrastructure_provisioner

Write-Host "`nBuilding infrastructure-provisioner Lambda..." -ForegroundColor Yellow

# Create deployment package
if (Test-Path "package") {
    Remove-Item -Recurse -Force package
}
New-Item -ItemType Directory -Path package | Out-Null

# Install dependencies
pip install -r requirements.txt -t package --quiet

# Copy handler
Copy-Item handler.py package/

# Create zip
if (Test-Path "../infrastructure-provisioner.zip") {
    Remove-Item "../infrastructure-provisioner.zip"
}
Compress-Archive -Path package/* -DestinationPath ../infrastructure-provisioner.zip

Write-Host "Created infrastructure-provisioner.zip" -ForegroundColor Green

Set-Location ..

Write-Host "`nBuild complete!" -ForegroundColor Green
Write-Host "Deployment packages created:"
Write-Host "  - system-registration.zip"
Write-Host "  - infrastructure-provisioner.zip"
