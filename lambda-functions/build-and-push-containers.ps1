# Build and Push Lambda Container Images to ECR
# This script builds Docker images for Lambda functions and pushes them to AWS ECR

param(
    [string]$Region = "us-east-2",
    [string]$AccountId = "450133579764"
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Building and Pushing Lambda Container Images" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Disable Docker BuildKit to ensure Docker v2 manifest format
$env:DOCKER_BUILDKIT = "0"
Write-Host "[INFO] Docker BuildKit disabled for Lambda compatibility" -ForegroundColor Yellow
Write-Host ""

# Login to ECR (using CMD to avoid PowerShell pipe issues)
Write-Host "[Step 1/5] Logging into AWS ECR..." -ForegroundColor Cyan

$LoginCommand = 'aws ecr get-login-password --region ' + $Region + ' | docker login --username AWS --password-stdin ' + $AccountId + '.dkr.ecr.' + $Region + '.amazonaws.com'
$LoginResult = cmd /c $LoginCommand 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to login to ECR" -ForegroundColor Red
    Write-Host "Error details: $LoginResult" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Logged into ECR successfully" -ForegroundColor Green
Write-Host ""

# Define Lambda functions
$Functions = @(
    @{
        Name = "raw-to-curated"
        DisplayName = "Raw to Curated Processor"
        RepoName = "futureim-ecommerce-ai-platform-raw-to-curated"
    },
    @{
        Name = "curated-to-prod"
        DisplayName = "Curated to Prod AI Processor"
        RepoName = "futureim-ecommerce-ai-platform-curated-to-prod"
    }
)

foreach ($Function in $Functions) {
    $FunctionName = $Function.Name
    $DisplayName = $Function.DisplayName
    $RepoName = $Function.RepoName
    $ImageUri = "$AccountId.dkr.ecr.$Region.amazonaws.com/${RepoName}:latest"
    
    Write-Host "[Step 2/5] Creating ECR repository for $DisplayName..." -ForegroundColor Cyan
    
    # Create ECR repository if it doesn't exist
    aws ecr describe-repositories --repository-names $RepoName --region $Region 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Repository doesn't exist, creating..." -ForegroundColor Yellow
        aws ecr create-repository --repository-name $RepoName --region $Region --image-scanning-configuration scanOnPush=true | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Repository created: $RepoName" -ForegroundColor Green
        } else {
            Write-Host "  [ERROR] Failed to create repository" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  [OK] Repository already exists: $RepoName" -ForegroundColor Green
    }
    Write-Host ""
    
    Write-Host "[Step 3/5] Building Docker image for $DisplayName..." -ForegroundColor Cyan
    docker build --platform linux/amd64 -t $RepoName "$FunctionName/"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to build Docker image for $DisplayName" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Docker image built successfully" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "[Step 4/5] Tagging Docker image..." -ForegroundColor Cyan
    docker tag "${RepoName}:latest" $ImageUri
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to tag Docker image" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Image tagged: $ImageUri" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "[Step 5/5] Pushing Docker image to ECR..." -ForegroundColor Cyan
    docker push $ImageUri
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Failed to push Docker image to ECR" -ForegroundColor Red
        exit 1
    }
    Write-Host "[OK] Image pushed successfully: $ImageUri" -ForegroundColor Green
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "All Lambda Container Images Built and Pushed Successfully!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Update Terraform to use container images:" -ForegroundColor White
Write-Host "   cd ../terraform" -ForegroundColor Cyan
Write-Host "   terraform apply" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Test the pipeline:" -ForegroundColor White
Write-Host "   Upload a file to the raw bucket and check CloudWatch Logs" -ForegroundColor Cyan
Write-Host ""
