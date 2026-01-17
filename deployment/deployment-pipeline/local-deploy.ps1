#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Local deployment script for dev and prod environments

.DESCRIPTION
    This script simulates the CI/CD pipeline locally, allowing developers to:
    - Build and test all components
    - Deploy to dev or prod environments
    - Run the same steps as CodeBuild

.PARAMETER Environment
    Target environment: dev or prod

.PARAMETER SkipTests
    Skip running tests

.PARAMETER SkipBuild
    Skip building artifacts

.PARAMETER DeployOnly
    Only deploy, skip build and test

.EXAMPLE
    .\local-deploy.ps1 -Environment dev
    .\local-deploy.ps1 -Environment prod -SkipTests
    .\local-deploy.ps1 -Environment dev -DeployOnly
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$DeployOnly
)

# Configuration
$PROJECT_NAME = "ecommerce-ai-platform"
$AWS_REGION = $env:AWS_DEFAULT_REGION ?? "us-east-1"
$BUILD_VERSION = (Get-Date -Format "yyyyMMdd-HHmmss")
$AWS_ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)

# Colors
$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-Prerequisites {
    Write-ColorOutput "`n=== Checking Prerequisites ===" $COLOR_CYAN
    
    $allGood = $true
    
    # Check AWS CLI
    try {
        aws --version | Out-Null
        Write-ColorOutput "✓ AWS CLI installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ AWS CLI not found" $COLOR_RED
        $allGood = $false
    }
    
    # Check Docker
    try {
        docker --version | Out-Null
        Write-ColorOutput "✓ Docker installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ Docker not found" $COLOR_RED
        $allGood = $false
    }
    
    # Check Terraform
    try {
        terraform --version | Out-Null
        Write-ColorOutput "✓ Terraform installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ Terraform not found" $COLOR_RED
        $allGood = $false
    }
    
    # Check Python
    try {
        python --version | Out-Null
        Write-ColorOutput "✓ Python installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ Python not found" $COLOR_RED
        $allGood = $false
    }
    
    # Check Java
    try {
        java -version 2>&1 | Out-Null
        Write-ColorOutput "✓ Java installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ Java not found" $COLOR_RED
        $allGood = $false
    }
    
    # Check Node.js
    try {
        node --version | Out-Null
        Write-ColorOutput "✓ Node.js installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ Node.js not found" $COLOR_RED
        $allGood = $false
    }
    
    # Check AWS credentials
    try {
        aws sts get-caller-identity | Out-Null
        Write-ColorOutput "✓ AWS credentials configured" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ AWS credentials not configured" $COLOR_RED
        $allGood = $false
    }
    
    return $allGood
}

function Run-Tests {
    Write-ColorOutput "`n=== Running Tests ===" $COLOR_CYAN
    
    # Integration tests
    Write-ColorOutput "Running integration tests..." $COLOR_CYAN
    Push-Location tests/integration
    python -m pytest -v
    $testResult = $LASTEXITCODE
    Pop-Location
    
    if ($testResult -ne 0 -and $Environment -eq "prod") {
        Write-ColorOutput "✗ Tests failed. Cannot deploy to production." $COLOR_RED
        exit 1
    }
    
    # Security tests for production
    if ($Environment -eq "prod") {
        Write-ColorOutput "Running security tests..." $COLOR_CYAN
        Push-Location tests/security
        pwsh -File run-security-tests.ps1 -TestType all
        Pop-Location
    }
    
    Write-ColorOutput "✓ Tests completed" $COLOR_GREEN
}

function Build-DataProcessing {
    Write-ColorOutput "`n=== Building Data Processing ===" $COLOR_CYAN
    
    Push-Location data-processing
    
    # Build Docker image
    docker build -t ${PROJECT_NAME}-data-processing:${BUILD_VERSION} .
    docker tag ${PROJECT_NAME}-data-processing:${BUILD_VERSION} ${PROJECT_NAME}-data-processing:${Environment}-latest
    
    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
    
    # Tag and push to ECR
    docker tag ${PROJECT_NAME}-data-processing:${BUILD_VERSION} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-data-processing:${BUILD_VERSION}
    docker tag ${PROJECT_NAME}-data-processing:${BUILD_VERSION} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-data-processing:${Environment}-latest
    
    docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-data-processing:${BUILD_VERSION}
    docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}-data-processing:${Environment}-latest
    
    Pop-Location
    Write-ColorOutput "✓ Data processing built and pushed" $COLOR_GREEN
}

function Build-AuthService {
    Write-ColorOutput "`n=== Building Auth Service ===" $COLOR_CYAN
    
    Push-Location auth-service
    
    if ($Environment -eq "prod") {
        mvn clean package
    } else {
        mvn clean package -DskipTests
    }
    
    # Upload to S3
    aws s3 cp target/auth-service-1.0.0.jar s3://${PROJECT_NAME}-artifacts-${Environment}/lambda/auth-service-${BUILD_VERSION}.jar
    
    Pop-Location
    Write-ColorOutput "✓ Auth service built and uploaded" $COLOR_GREEN
}

function Build-AnalyticsService {
    Write-ColorOutput "`n=== Building Analytics Service ===" $COLOR_CYAN
    
    Push-Location analytics-service
    
    # Create package directory
    New-Item -ItemType Directory -Force -Path package | Out-Null
    
    # Install dependencies
    pip install -r requirements.txt -t package/
    
    # Create zip
    Push-Location package
    Compress-Archive -Path * -DestinationPath ../analytics-lambda-${BUILD_VERSION}.zip -Force
    Pop-Location
    
    # Add source code
    Compress-Archive -Path src/* -DestinationPath analytics-lambda-${BUILD_VERSION}.zip -Update
    
    # Upload to S3
    aws s3 cp analytics-lambda-${BUILD_VERSION}.zip s3://${PROJECT_NAME}-artifacts-${Environment}/lambda/
    
    # Cleanup
    Remove-Item -Recurse -Force package
    Remove-Item analytics-lambda-${BUILD_VERSION}.zip
    
    Pop-Location
    Write-ColorOutput "✓ Analytics service built and uploaded" $COLOR_GREEN
}

function Build-AISystem {
    param([string]$SystemName, [string]$SystemPath)
    
    Write-ColorOutput "`nBuilding $SystemName..." $COLOR_CYAN
    
    Push-Location $SystemPath
    
    # Create package directory
    New-Item -ItemType Directory -Force -Path package | Out-Null
    
    # Install dependencies
    pip install -r requirements.txt -t package/
    
    # Create zip
    Push-Location package
    Compress-Archive -Path * -DestinationPath ../${SystemName}-${BUILD_VERSION}.zip -Force
    Pop-Location
    
    # Add source code
    Compress-Archive -Path src/* -DestinationPath ${SystemName}-${BUILD_VERSION}.zip -Update
    
    # Upload to S3
    aws s3 cp ${SystemName}-${BUILD_VERSION}.zip s3://${PROJECT_NAME}-artifacts-${Environment}/lambda/
    
    # Cleanup
    Remove-Item -Recurse -Force package
    Remove-Item ${SystemName}-${BUILD_VERSION}.zip
    
    Pop-Location
    Write-ColorOutput "✓ $SystemName built and uploaded" $COLOR_GREEN
}

function Build-Frontend {
    Write-ColorOutput "`n=== Building Frontend ===" $COLOR_CYAN
    
    Push-Location frontend
    
    # Install dependencies
    npm ci
    
    # Build
    npm run build
    
    # Upload to S3
    aws s3 sync dist/ s3://${PROJECT_NAME}-frontend-${Environment}/ --delete
    
    # Invalidate CloudFront cache
    $distributionId = aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='${PROJECT_NAME}-${Environment}'].Id" --output text
    if ($distributionId) {
        aws cloudfront create-invalidation --distribution-id $distributionId --paths "/*"
        Write-ColorOutput "✓ CloudFront cache invalidated" $COLOR_GREEN
    }
    
    Pop-Location
    Write-ColorOutput "✓ Frontend built and deployed" $COLOR_GREEN
}

function Deploy-Infrastructure {
    Write-ColorOutput "`n=== Deploying Infrastructure ===" $COLOR_CYAN
    
    Push-Location terraform
    
    # Initialize Terraform
    terraform init -backend-config="key=${Environment}/terraform.tfstate"
    
    # Plan
    terraform plan -var="environment=${Environment}" -var="build_version=${BUILD_VERSION}" -out=tfplan
    
    # Apply
    if ($Environment -eq "prod") {
        Write-ColorOutput "Review the Terraform plan above." $COLOR_YELLOW
        $confirmation = Read-Host "Do you want to apply these changes to PRODUCTION? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-ColorOutput "Deployment cancelled" $COLOR_YELLOW
            Pop-Location
            exit 0
        }
    }
    
    terraform apply -auto-approve tfplan
    
    Pop-Location
    Write-ColorOutput "✓ Infrastructure deployed" $COLOR_GREEN
}

function Run-SmokeTests {
    Write-ColorOutput "`n=== Running Smoke Tests ===" $COLOR_CYAN
    
    $apiUrl = "https://api.${PROJECT_NAME}-${Environment}.com"
    
    # Test health endpoint
    try {
        $response = Invoke-WebRequest -Uri "$apiUrl/health" -Method GET -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-ColorOutput "✓ Health check passed" $COLOR_GREEN
        } else {
            Write-ColorOutput "⚠ Health check returned status $($response.StatusCode)" $COLOR_YELLOW
        }
    } catch {
        Write-ColorOutput "✗ Health check failed: $_" $COLOR_RED
    }
    
    # Test authentication endpoint
    try {
        $response = Invoke-WebRequest -Uri "$apiUrl/auth/health" -Method GET -TimeoutSec 10
        Write-ColorOutput "✓ Auth service responding" $COLOR_GREEN
    } catch {
        Write-ColorOutput "⚠ Auth service check failed" $COLOR_YELLOW
    }
}

# ============================================
# Main Execution
# ============================================

Write-ColorOutput @"
╔═══════════════════════════════════════════════════════════╗
║   eCommerce AI Platform - Local Deployment               ║
║   Environment: $Environment                                      ║
║   Build Version: $BUILD_VERSION                    ║
╚═══════════════════════════════════════════════════════════╝
"@ $COLOR_CYAN

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "`n✗ Prerequisites check failed" $COLOR_RED
    exit 1
}

$startTime = Get-Date

# Run tests
if (-not $SkipTests -and -not $DeployOnly) {
    Run-Tests
}

# Build artifacts
if (-not $SkipBuild -and -not $DeployOnly) {
    Build-DataProcessing
    Build-AuthService
    Build-AnalyticsService
    
    # Build AI Systems
    Build-AISystem -SystemName "market-intelligence" -SystemPath "ai-systems/market-intelligence-hub"
    Build-AISystem -SystemName "demand-insights" -SystemPath "ai-systems/demand-insights-engine"
    Build-AISystem -SystemName "compliance-guardian" -SystemPath "ai-systems/compliance-guardian"
    Build-AISystem -SystemName "retail-copilot" -SystemPath "ai-systems/retail-copilot"
    Build-AISystem -SystemName "global-market-pulse" -SystemPath "ai-systems/global-market-pulse"
    
    Build-Frontend
}

# Deploy infrastructure
Deploy-Infrastructure

# Run smoke tests
if ($Environment -eq "prod") {
    Run-SmokeTests
}

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalMinutes

Write-ColorOutput "`n╔═══════════════════════════════════════════════════════════╗" $COLOR_GREEN
Write-ColorOutput "║   Deployment Completed Successfully!                     ║" $COLOR_GREEN
Write-ColorOutput "║   Environment: $Environment                                      ║" $COLOR_GREEN
Write-ColorOutput "║   Duration: $([math]::Round($duration, 2)) minutes                              ║" $COLOR_GREEN
Write-ColorOutput "╚═══════════════════════════════════════════════════════════╝" $COLOR_GREEN

exit 0
