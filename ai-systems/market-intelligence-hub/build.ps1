# Build script for Market Intelligence Hub Lambda
# Creates deployment package with all dependencies

param(
    [string]$Region = "us-east-1",
    [string]$AccountId = ""
)

Write-Host "Building Market Intelligence Hub Lambda deployment package..." -ForegroundColor Green

# Get AWS account ID if not provided
if ([string]::IsNullOrEmpty($AccountId)) {
    Write-Host "Getting AWS account ID..."
    $AccountId = (aws sts get-caller-identity --query Account --output text)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to get AWS account ID. Make sure AWS CLI is configured." -ForegroundColor Red
        exit 1
    }
}

Write-Host "Account ID: $AccountId"
Write-Host "Region: $Region"

# Create build directory
$BuildDir = "build"
if (Test-Path $BuildDir) {
    Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Path $BuildDir | Out-Null

# Install dependencies
Write-Host "`nInstalling Python dependencies..." -ForegroundColor Yellow
pip install -r requirements.txt -t $BuildDir --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: Failed to install dependencies" -ForegroundColor Red
    exit 1
}

# Copy source code
Write-Host "Copying source code..." -ForegroundColor Yellow
Copy-Item -Path "src/*" -Destination $BuildDir -Recurse

# Create deployment package
Write-Host "`nCreating deployment package..." -ForegroundColor Yellow
$ZipFile = "market-intelligence-hub-lambda.zip"
if (Test-Path $ZipFile) {
    Remove-Item $ZipFile
}

# Change to build directory and create zip
Push-Location $BuildDir
Compress-Archive -Path * -DestinationPath "../$ZipFile"
Pop-Location

Write-Host "Deployment package created: $ZipFile" -ForegroundColor Green

# Get package size
$Size = (Get-Item $ZipFile).Length / 1MB
Write-Host "Package size: $([math]::Round($Size, 2)) MB"

# Upload to S3 (optional)
$UploadToS3 = Read-Host "`nUpload to S3? (y/n)"
if ($UploadToS3 -eq 'y') {
    $BucketName = "lambda-deployments-$AccountId"
    $S3Key = "market-intelligence-hub/$ZipFile"
    
    Write-Host "`nUploading to S3..." -ForegroundColor Yellow
    
    # Create bucket if it doesn't exist
    aws s3 mb "s3://$BucketName" --region $Region 2>$null
    
    # Upload zip file
    aws s3 cp $ZipFile "s3://$BucketName/$S3Key" --region $Region
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Uploaded to s3://$BucketName/$S3Key" -ForegroundColor Green
        Write-Host "`nUse this S3 location in Terraform:"
        Write-Host "  s3_bucket = `"$BucketName`""
        Write-Host "  s3_key    = `"$S3Key`""
    } else {
        Write-Host "Error: Failed to upload to S3" -ForegroundColor Red
    }
}

Write-Host "`nBuild complete!" -ForegroundColor Green
Write-Host "Deployment package: $ZipFile"
