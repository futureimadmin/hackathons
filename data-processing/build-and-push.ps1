# PowerShell script to build and push Docker image to ECR

param(
    [string]$Region = "us-east-1",
    [string]$AccountId = "",
    [string]$ImageName = "ecommerce-data-processor",
    [string]$ImageTag = "latest"
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

Write-Info "========================================="
Write-Info "Building and Pushing Docker Image"
Write-Info "========================================="
Write-Host ""

# Get AWS account ID if not provided
if ([string]::IsNullOrEmpty($AccountId)) {
    Write-Info "Getting AWS account ID..."
    $AccountId = aws sts get-caller-identity --query Account --output text
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to get AWS account ID"
        exit 1
    }
}

Write-Info "Account ID: $AccountId"
Write-Info "Region: $Region"
Write-Info "Image Name: $ImageName"
Write-Info "Image Tag: $ImageTag"
Write-Host ""

# ECR repository URL
$EcrRepo = "$AccountId.dkr.ecr.$Region.amazonaws.com/$ImageName"

# 1. Create ECR repository if it doesn't exist
Write-Info "Checking if ECR repository exists..."
$repoExists = aws ecr describe-repositories --repository-names $ImageName --region $Region 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Info "Creating ECR repository..."
    aws ecr create-repository `
        --repository-name $ImageName `
        --image-scanning-configuration scanOnPush=true `
        --encryption-configuration encryptionType=AES256 `
        --region $Region
    
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to create ECR repository"
        exit 1
    }
    Write-Info "✓ ECR repository created"
} else {
    Write-Info "✓ ECR repository already exists"
}

Write-Host ""

# 2. Authenticate Docker to ECR
Write-Info "Authenticating Docker to ECR..."
aws ecr get-login-password --region $Region | docker login --username AWS --password-stdin $EcrRepo

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to authenticate Docker to ECR"
    exit 1
}
Write-Info "✓ Docker authenticated to ECR"

Write-Host ""

# 3. Build Docker image
Write-Info "Building Docker image..."
docker build -t $ImageName`:$ImageTag .

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to build Docker image"
    exit 1
}
Write-Info "✓ Docker image built successfully"

Write-Host ""

# 4. Tag image for ECR
Write-Info "Tagging image for ECR..."
docker tag $ImageName`:$ImageTag $EcrRepo`:$ImageTag

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to tag Docker image"
    exit 1
}
Write-Info "✓ Image tagged for ECR"

Write-Host ""

# 5. Push image to ECR
Write-Info "Pushing image to ECR..."
docker push $EcrRepo`:$ImageTag

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Failed to push Docker image to ECR"
    exit 1
}
Write-Info "✓ Image pushed to ECR successfully"

Write-Host ""

# 6. Get image details
Write-Info "Image Details:"
Write-Host "  Repository: $EcrRepo"
Write-Host "  Tag: $ImageTag"
Write-Host "  Full URI: $EcrRepo`:$ImageTag"

Write-Host ""
Write-Info "========================================="
Write-Info "Build and Push Completed Successfully!"
Write-Info "========================================="
Write-Host ""

Write-Info "Next Steps:"
Write-Info "  1. Update AWS Batch job definition with image URI:"
Write-Info "     $EcrRepo`:$ImageTag"
Write-Info ""
Write-Info "  2. Test the image locally:"
Write-Info "     docker run --rm $ImageName`:$ImageTag"
Write-Host ""
