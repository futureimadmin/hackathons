# Rebuild Lambda Authorizer Package
# This script rebuilds the Lambda deployment package from scratch

# Get the script directory and ensure we're working there
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $scriptDir

Write-Host "Rebuilding Lambda authorizer package..." -ForegroundColor Cyan
Write-Host "Script directory: $scriptDir" -ForegroundColor Gray
Write-Host "Working directory: $(Get-Location)" -ForegroundColor Gray

# Clean up existing files
Write-Host "Cleaning up existing files..." -ForegroundColor Yellow
if (Test-Path "authorizer.zip") {
    Remove-Item "authorizer.zip" -Force
    Write-Host "  Removed existing authorizer.zip" -ForegroundColor Gray
}

if (Test-Path "node_modules") {
    Remove-Item "node_modules" -Recurse -Force
    Write-Host "  Removed node_modules directory" -ForegroundColor Gray
}

if (Test-Path "package-lock.json") {
    Remove-Item "package-lock.json" -Force
    Write-Host "  Removed package-lock.json" -ForegroundColor Gray
}

# Check if Node.js is installed
Write-Host "Checking Node.js installation..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    Write-Host "  Node.js version: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Node.js is not installed or not in PATH" -ForegroundColor Red
    Write-Host "  Please install Node.js from https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

# Check if npm is available
try {
    $npmVersion = npm --version
    Write-Host "  npm version: $npmVersion" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: npm is not available" -ForegroundColor Red
    exit 1
}

# Install dependencies
Write-Host "Installing dependencies..." -ForegroundColor Yellow
npm install --production --no-optional

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to install dependencies" -ForegroundColor Red
    exit 1
}

Write-Host "  Dependencies installed successfully" -ForegroundColor Green

# Verify required files exist
$requiredFiles = @("index.js", "package.json", "node_modules")
foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "  ERROR: Required file/directory missing: $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host "  All required files present" -ForegroundColor Green

# Create deployment package
Write-Host "Creating deployment package..." -ForegroundColor Yellow

# Use PowerShell Compress-Archive (available on all Windows systems)
try {
    # Create a temporary directory to organize files
    $tempDir = "temp_package"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    # Copy files to temp directory
    Copy-Item "index.js" -Destination $tempDir
    Copy-Item "package.json" -Destination $tempDir
    Copy-Item "node_modules" -Destination $tempDir -Recurse

    # Create zip from temp directory
    Compress-Archive -Path "$tempDir\*" -DestinationPath "authorizer.zip" -Force

    # Clean up temp directory
    Remove-Item $tempDir -Recurse -Force

    if (Test-Path "authorizer.zip") {
        $size = (Get-Item "authorizer.zip").Length / 1MB
        $sizeRounded = [math]::Round($size, 2)
        Write-Host "  Package created: authorizer.zip ($sizeRounded MB)" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: Failed to create zip file" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ERROR: Failed to create deployment package: $_" -ForegroundColor Red
    exit 1
}

# Verify zip file integrity
Write-Host "Verifying package integrity..." -ForegroundColor Yellow
try {
    # Use current directory (should be lambda directory)
    $zipFile = "authorizer.zip"
    
    if (-not (Test-Path $zipFile)) {
        Write-Host "  ERROR: Zip file not found: $zipFile" -ForegroundColor Red
        Write-Host "  Current directory: $(Get-Location)" -ForegroundColor Red
        exit 1
    }
    
    # Get file size as basic verification
    $zipSize = (Get-Item $zipFile).Length
    if ($zipSize -lt 1000) {
        Write-Host "  ERROR: Zip file is too small ($zipSize bytes) - likely corrupted" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "  Package size: $([math]::Round($zipSize/1KB, 2)) KB" -ForegroundColor Green
    Write-Host "  Package created successfully" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Package verification failed: $_" -ForegroundColor Red
    exit 1
}

# Return to original directory
Pop-Location

Write-Host ""
Write-Host "Lambda package rebuilt successfully!" -ForegroundColor Green
Write-Host "You can now run 'terraform apply' to deploy the updated function." -ForegroundColor White