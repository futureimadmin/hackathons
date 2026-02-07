# Build and Push All AI Systems Lambda Container Images to ECR
# This script builds Docker images for all AI system Lambda functions and pushes them to AWS ECR

param(
    [string]$Region = "us-east-2",
    [string]$AccountId = "450133579764",
    [string]$ProjectName = "futureim-ecommerce-ai-platform"
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Building and Pushing All AI Systems Lambda Container Images" -ForegroundColor Cyan
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

# Define AI Systems
$AISystems = @(
    @{
        Name = "compliance-guardian"
        DisplayName = "Compliance Guardian"
        RepoName = "$ProjectName-compliance-guardian-dev"
        Path = "compliance-guardian"
    },
    @{
        Name = "demand-insights-engine"
        DisplayName = "Demand Insights Engine"
        RepoName = "$ProjectName-demand-insights-dev"
        Path = "demand-insights-engine"
    },
    @{
        Name = "market-intelligence-hub"
        DisplayName = "Market Intelligence Hub"
        RepoName = "$ProjectName-market-intelligence-dev"
        Path = "market-intelligence-hub"
    },
    @{
        Name = "retail-copilot"
        DisplayName = "Retail Copilot"
        RepoName = "$ProjectName-retail-copilot-dev"
        Path = "retail-copilot"
    },
    @{
        Name = "global-market-pulse"
        DisplayName = "Global Market Pulse"
        RepoName = "$ProjectName-global-market-pulse-dev"
        Path = "global-market-pulse"
    }
)

$SuccessCount = 0
$FailureCount = 0
$FailedSystems = @()

foreach ($System in $AISystems) {
    $SystemName = $System.Name
    $DisplayName = $System.DisplayName
    $RepoName = $System.RepoName
    $SystemPath = $System.Path
    $ImageUri = "$AccountId.dkr.ecr.$Region.amazonaws.com/${RepoName}:latest"
    
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "Processing: $DisplayName" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    try {
        Write-Host "[Step 2/5] Creating ECR repository for $DisplayName..." -ForegroundColor Cyan
        
        # Create ECR repository if it doesn't exist
        aws ecr describe-repositories --repository-names $RepoName --region $Region 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Repository doesn't exist, creating..." -ForegroundColor Yellow
            aws ecr create-repository --repository-name $RepoName --region $Region --image-scanning-configuration scanOnPush=true | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK] Repository created: $RepoName" -ForegroundColor Green
            } else {
                throw "Failed to create repository"
            }
        } else {
            Write-Host "  [OK] Repository already exists: $RepoName" -ForegroundColor Green
        }
        Write-Host ""
        
        Write-Host "[Step 3/5] Building Docker image for $DisplayName..." -ForegroundColor Cyan
        docker build --platform linux/amd64 -t $RepoName "$SystemPath/"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build Docker image"
        }
        Write-Host "[OK] Docker image built successfully" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "[Step 4/5] Tagging Docker image..." -ForegroundColor Cyan
        docker tag "${RepoName}:latest" $ImageUri
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to tag Docker image"
        }
        Write-Host "[OK] Image tagged: $ImageUri" -ForegroundColor Green
        Write-Host ""
        
        Write-Host "[Step 5/5] Pushing Docker image to ECR..." -ForegroundColor Cyan
        docker push $ImageUri
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to push Docker image to ECR"
        }
        Write-Host "[OK] Image pushed successfully: $ImageUri" -ForegroundColor Green
        Write-Host ""
        
        $SuccessCount++
        Write-Host "[SUCCESS] $DisplayName completed successfully!" -ForegroundColor Green
        
    } catch {
        $FailureCount++
        $FailedSystems += $DisplayName
        Write-Host "[ERROR] Failed to process $DisplayName : $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Build Summary" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Total Systems: $($AISystems.Count)" -ForegroundColor White
Write-Host "Successful: $SuccessCount" -ForegroundColor Green
Write-Host "Failed: $FailureCount" -ForegroundColor $(if ($FailureCount -gt 0) { "Red" } else { "Green" })

if ($FailureCount -gt 0) {
    Write-Host ""
    Write-Host "Failed Systems:" -ForegroundColor Red
    foreach ($Failed in $FailedSystems) {
        Write-Host "  - $Failed" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan

if ($FailureCount -eq 0) {
    Write-Host "All AI Systems Container Images Built and Pushed Successfully!" -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "1. Update Terraform Lambda modules to use container images" -ForegroundColor White
    Write-Host "2. Run terraform apply to deploy the Lambda functions" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Some Systems Failed - Please Review Errors Above" -ForegroundColor Red
    Write-Host "================================================================" -ForegroundColor Cyan
    exit 1
}
