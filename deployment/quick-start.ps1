#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick start script for deploying the eCommerce AI Platform

.DESCRIPTION
    This script automates the entire deployment process:
    1. Configure MySQL connection and JWT secrets
    2. Setup Terraform backend
    3. Deploy infrastructure
    4. Verify deployment

.PARAMETER SkipMySQLConfig
    Skip MySQL and JWT configuration (if already done)

.PARAMETER SkipTerraformSetup
    Skip Terraform backend setup (if already done)

.PARAMETER AutoApprove
    Automatically approve Terraform apply (use with caution)

.EXAMPLE
    .\quick-start.ps1
    
.EXAMPLE
    .\quick-start.ps1 -SkipMySQLConfig -AutoApprove
#>

param(
    [switch]$SkipMySQLConfig,
    [switch]$SkipTerraformSetup,
    [switch]$AutoApprove
)

$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"
$COLOR_MAGENTA = "Magenta"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$StepNumber, [string]$StepName)
    Write-ColorOutput "`n╔═══════════════════════════════════════════════════════════╗" $COLOR_MAGENTA
    Write-ColorOutput "║   Step $StepNumber : $StepName" $COLOR_MAGENTA
    Write-ColorOutput "╚═══════════════════════════════════════════════════════════╝" $COLOR_MAGENTA
}

Write-ColorOutput @"

╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   eCommerce AI Platform - Quick Start Deployment         ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

"@ $COLOR_CYAN

Write-ColorOutput "This script will deploy the complete infrastructure to AWS." $COLOR_CYAN
Write-ColorOutput "Estimated time: 20-30 minutes" $COLOR_CYAN
Write-ColorOutput ""

# Check prerequisites
Write-ColorOutput "Checking prerequisites..." $COLOR_CYAN

$prerequisites = @{
    "AWS CLI" = { aws --version }
    "Terraform" = { terraform --version }
    "PowerShell 7+" = { $PSVersionTable.PSVersion.Major -ge 7 }
}

$allPrereqsMet = $true
foreach ($prereq in $prerequisites.GetEnumerator()) {
    try {
        $null = & $prereq.Value 2>&1
        if ($LASTEXITCODE -eq 0 -or $prereq.Key -eq "PowerShell 7+") {
            Write-ColorOutput "  ✓ $($prereq.Key)" $COLOR_GREEN
        } else {
            Write-ColorOutput "  ✗ $($prereq.Key)" $COLOR_RED
            $allPrereqsMet = $false
        }
    } catch {
        Write-ColorOutput "  ✗ $($prereq.Key)" $COLOR_RED
        $allPrereqsMet = $false
    }
}

if (-not $allPrereqsMet) {
    Write-ColorOutput "`n✗ Some prerequisites are missing. Please install them first." $COLOR_RED
    exit 1
}

# Check AWS credentials
try {
    $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
    Write-ColorOutput "  ✓ AWS Credentials (Account: $($identity.Account))" $COLOR_GREEN
} catch {
    Write-ColorOutput "  ✗ AWS Credentials not configured" $COLOR_RED
    Write-ColorOutput "    Run: aws configure" $COLOR_YELLOW
    exit 1
}

Write-ColorOutput "`n✓ All prerequisites met!" $COLOR_GREEN

# Confirm deployment
Write-ColorOutput "`n⚠️  WARNING: This will create AWS resources that may incur costs." $COLOR_YELLOW
Write-ColorOutput "Estimated monthly cost: $280-450 for development environment" $COLOR_YELLOW
$confirm = Read-Host "`nDo you want to proceed? (yes/no)"
if ($confirm -ne "yes") {
    Write-ColorOutput "Deployment cancelled." $COLOR_YELLOW
    exit 0
}

# Step 1: Configure MySQL and JWT
if (-not $SkipMySQLConfig) {
    Write-Step "1" "Configure MySQL Connection and JWT Secrets"
    
    Write-ColorOutput "`nThis will configure:" $COLOR_CYAN
    Write-ColorOutput "  • MySQL connection to 172.20.10.4:3306" $COLOR_CYAN
    Write-ColorOutput "  • JWT secrets (non-expiring tokens)" $COLOR_CYAN
    Write-ColorOutput "  • Store credentials in AWS SSM Parameter Store" $COLOR_CYAN
    
    $scriptPath = Join-Path $PSScriptRoot "configure-mysql-connection.ps1"
    if (Test-Path $scriptPath) {
        & $scriptPath
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "`n✗ MySQL configuration failed" $COLOR_RED
            exit 1
        }
    } else {
        Write-ColorOutput "✗ Configuration script not found: $scriptPath" $COLOR_RED
        exit 1
    }
} else {
    Write-ColorOutput "`nSkipping MySQL configuration (already done)" $COLOR_YELLOW
}

# Step 2: Setup Terraform Backend
if (-not $SkipTerraformSetup) {
    Write-Step "2" "Setup Terraform Backend"
    
    Write-ColorOutput "`nThis will create:" $COLOR_CYAN
    Write-ColorOutput "  • S3 bucket for Terraform state" $COLOR_CYAN
    Write-ColorOutput "  • DynamoDB table for state locking" $COLOR_CYAN
    Write-ColorOutput "  • Initialize Terraform" $COLOR_CYAN
    
    $terraformDir = Join-Path $PSScriptRoot ".." "terraform"
    $setupScript = Join-Path $terraformDir "setup-terraform.ps1"
    
    if (Test-Path $setupScript) {
        Push-Location $terraformDir
        & $setupScript
        $setupResult = $LASTEXITCODE
        Pop-Location
        
        if ($setupResult -ne 0) {
            Write-ColorOutput "`n✗ Terraform setup failed" $COLOR_RED
            exit 1
        }
    } else {
        Write-ColorOutput "✗ Terraform setup script not found: $setupScript" $COLOR_RED
        exit 1
    }
} else {
    Write-ColorOutput "`nSkipping Terraform setup (already done)" $COLOR_YELLOW
}

# Step 3: Review Terraform Plan
Write-Step "3" "Review Infrastructure Plan"

$terraformDir = Join-Path $PSScriptRoot ".." "terraform"
Push-Location $terraformDir

Write-ColorOutput "`nGenerating Terraform plan..." $COLOR_CYAN
terraform plan -out=tfplan

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "`n✗ Terraform plan failed" $COLOR_RED
    Pop-Location
    exit 1
}

Write-ColorOutput "`n✓ Terraform plan generated successfully" $COLOR_GREEN

if (-not $AutoApprove) {
    Write-ColorOutput "`nReview the plan above." $COLOR_YELLOW
    $proceed = Read-Host "Proceed with deployment? (yes/no)"
    if ($proceed -ne "yes") {
        Write-ColorOutput "Deployment cancelled." $COLOR_YELLOW
        Pop-Location
        exit 0
    }
}

# Step 4: Deploy Infrastructure
Write-Step "4" "Deploy Infrastructure"

Write-ColorOutput "`nDeploying infrastructure to AWS..." $COLOR_CYAN
Write-ColorOutput "This will take approximately 15-20 minutes..." $COLOR_YELLOW

$startTime = Get-Date

if ($AutoApprove) {
    terraform apply -auto-approve tfplan
} else {
    terraform apply tfplan
}

$deployResult = $LASTEXITCODE
$endTime = Get-Date
$duration = $endTime - $startTime

Pop-Location

if ($deployResult -ne 0) {
    Write-ColorOutput "`n✗ Infrastructure deployment failed" $COLOR_RED
    Write-ColorOutput "Check the error messages above for details." $COLOR_YELLOW
    exit 1
}

Write-ColorOutput "`n✓ Infrastructure deployed successfully!" $COLOR_GREEN
Write-ColorOutput "Deployment time: $($duration.Minutes) minutes $($duration.Seconds) seconds" $COLOR_CYAN

# Step 5: Verify Deployment
Write-Step "5" "Verify Deployment"

Write-ColorOutput "`nVerifying deployed resources..." $COLOR_CYAN

# Check S3 buckets
Write-ColorOutput "`nS3 Buckets:" $COLOR_CYAN
$buckets = aws s3 ls | Select-String "ecommerce-ai-platform"
if ($buckets) {
    $buckets | ForEach-Object { Write-ColorOutput "  ✓ $_" $COLOR_GREEN }
} else {
    Write-ColorOutput "  ⚠️  No buckets found" $COLOR_YELLOW
}

# Check Lambda functions
Write-ColorOutput "`nLambda Functions:" $COLOR_CYAN
$functions = aws lambda list-functions --query "Functions[?contains(FunctionName, 'ecommerce')].FunctionName" --output text
if ($functions) {
    $functions -split "`t" | ForEach-Object { Write-ColorOutput "  ✓ $_" $COLOR_GREEN }
} else {
    Write-ColorOutput "  ⚠️  No Lambda functions found (may not be deployed yet)" $COLOR_YELLOW
}

# Get Terraform outputs
Write-ColorOutput "`nTerraform Outputs:" $COLOR_CYAN
Push-Location $terraformDir
terraform output
Pop-Location

# Summary
Write-ColorOutput "`n╔═══════════════════════════════════════════════════════════╗" $COLOR_GREEN
Write-ColorOutput "║   Deployment Complete!                                   ║" $COLOR_GREEN
Write-ColorOutput "╚═══════════════════════════════════════════════════════════╝" $COLOR_GREEN

Write-ColorOutput "`nWhat was deployed:" $COLOR_CYAN
Write-ColorOutput "  ✓ VPC and networking infrastructure" $COLOR_GREEN
Write-ColorOutput "  ✓ S3 data lake buckets (15 buckets for 5 AI systems)" $COLOR_GREEN
Write-ColorOutput "  ✓ IAM roles and policies" $COLOR_GREEN
Write-ColorOutput "  ✓ KMS encryption keys" $COLOR_GREEN
Write-ColorOutput "  ✓ CloudWatch monitoring" $COLOR_GREEN

Write-ColorOutput "`nConfiguration:" $COLOR_CYAN
Write-ColorOutput "  • MySQL: 172.20.10.4:3306" $COLOR_CYAN
Write-ColorOutput "  • JWT: Non-expiring tokens" $COLOR_CYAN
Write-ColorOutput "  • Environment: dev" $COLOR_CYAN
Write-ColorOutput "  • Region: us-east-1" $COLOR_CYAN

Write-ColorOutput "`nNext Steps:" $COLOR_YELLOW
Write-ColorOutput "1. Setup network connectivity (VPN/Direct Connect) to MySQL server" $COLOR_YELLOW
Write-ColorOutput "   See: deployment/mysql-connection-setup.md" $COLOR_YELLOW
Write-ColorOutput "" $COLOR_YELLOW
Write-ColorOutput "2. Deploy Lambda functions and AI systems:" $COLOR_YELLOW
Write-ColorOutput "   cd auth-service && mvn clean package" $COLOR_YELLOW
Write-ColorOutput "   cd ai-systems/market-intelligence-hub && .\build.ps1" $COLOR_YELLOW
Write-ColorOutput "" $COLOR_YELLOW
Write-ColorOutput "3. Setup database schema:" $COLOR_YELLOW
Write-ColorOutput "   cd database && .\setup-database.ps1 -Environment dev" $COLOR_YELLOW
Write-ColorOutput "" $COLOR_YELLOW
Write-ColorOutput "4. Deploy CI/CD pipeline:" $COLOR_YELLOW
Write-ColorOutput "   cd deployment/deployment-pipeline && .\setup-pipeline.ps1" $COLOR_YELLOW
Write-ColorOutput "" $COLOR_YELLOW
Write-ColorOutput "5. Run integration tests:" $COLOR_YELLOW
Write-ColorOutput "   cd tests/integration && .\run_integration_tests.ps1" $COLOR_YELLOW

Write-ColorOutput "`nDocumentation:" $COLOR_CYAN
Write-ColorOutput "  • Full deployment guide: deployment/INFRASTRUCTURE_DEPLOYMENT_GUIDE.md" $COLOR_CYAN
Write-ColorOutput "  • MySQL setup: deployment/mysql-connection-setup.md" $COLOR_CYAN
Write-ColorOutput "  • CI/CD pipeline: deployment/deployment-pipeline/README.md" $COLOR_CYAN
Write-ColorOutput "  • Troubleshooting: docs/TROUBLESHOOTING_GUIDE.md" $COLOR_CYAN

Write-ColorOutput "`n🎉 Happy deploying!" $COLOR_GREEN

exit 0
