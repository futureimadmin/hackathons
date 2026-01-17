#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Teardown CI/CD pipeline infrastructure

.DESCRIPTION
    This script removes all pipeline resources from AWS including:
    - CloudFormation stack
    - S3 buckets (optional)
    - ECR repositories (optional)
    - SSM parameters (optional)

.PARAMETER KeepArtifacts
    Keep S3 buckets with artifacts

.PARAMETER KeepECR
    Keep ECR repositories

.PARAMETER KeepParameters
    Keep SSM parameters

.EXAMPLE
    .\teardown-pipeline.ps1
    .\teardown-pipeline.ps1 -KeepArtifacts -KeepECR
#>

param(
    [Parameter(Mandatory=$false)]
    [switch]$KeepArtifacts,
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepECR,
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepParameters
)

$PROJECT_NAME = "ecommerce-ai-platform"
$STACK_NAME = "${PROJECT_NAME}-pipeline"
$AWS_REGION = $env:AWS_DEFAULT_REGION ?? "us-east-1"

$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput @"
╔═══════════════════════════════════════════════════════════╗
║   Tearing Down CI/CD Pipeline                            ║
╚═══════════════════════════════════════════════════════════╝
"@ $COLOR_CYAN

Write-ColorOutput "`nWARNING: This will delete pipeline resources!" $COLOR_YELLOW
$confirmation = Read-Host "Are you sure you want to continue? (yes/no)"

if ($confirmation -ne "yes") {
    Write-ColorOutput "Teardown cancelled" $COLOR_YELLOW
    exit 0
}

# Delete CloudFormation stack
Write-ColorOutput "`nDeleting CloudFormation stack..." $COLOR_CYAN
aws cloudformation delete-stack --stack-name $STACK_NAME --region $AWS_REGION

Write-ColorOutput "Waiting for stack deletion..." $COLOR_CYAN
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $AWS_REGION

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✓ CloudFormation stack deleted" $COLOR_GREEN
} else {
    Write-ColorOutput "⚠ Stack deletion may have failed or is still in progress" $COLOR_YELLOW
}

# Delete S3 buckets
if (-not $KeepArtifacts) {
    Write-ColorOutput "`nDeleting S3 buckets..." $COLOR_CYAN
    
    $buckets = @(
        "${PROJECT_NAME}-pipeline-artifacts",
        "${PROJECT_NAME}-artifacts-dev",
        "${PROJECT_NAME}-artifacts-prod"
    )
    
    foreach ($bucket in $buckets) {
        Write-ColorOutput "Emptying bucket: $bucket" $COLOR_CYAN
        aws s3 rm s3://$bucket --recursive --region $AWS_REGION 2>$null
        
        Write-ColorOutput "Deleting bucket: $bucket" $COLOR_CYAN
        aws s3 rb s3://$bucket --region $AWS_REGION 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✓ Deleted bucket: $bucket" $COLOR_GREEN
        } else {
            Write-ColorOutput "⚠ Could not delete bucket: $bucket" $COLOR_YELLOW
        }
    }
} else {
    Write-ColorOutput "`nKeeping S3 buckets (--KeepArtifacts specified)" $COLOR_YELLOW
}

# Delete ECR repositories
if (-not $KeepECR) {
    Write-ColorOutput "`nDeleting ECR repositories..." $COLOR_CYAN
    
    aws ecr delete-repository --repository-name ${PROJECT_NAME}-data-processing --force --region $AWS_REGION 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Deleted ECR repository" $COLOR_GREEN
    } else {
        Write-ColorOutput "⚠ Could not delete ECR repository" $COLOR_YELLOW
    }
} else {
    Write-ColorOutput "`nKeeping ECR repositories (--KeepECR specified)" $COLOR_YELLOW
}

# Delete SSM parameters
if (-not $KeepParameters) {
    Write-ColorOutput "`nDeleting SSM parameters..." $COLOR_CYAN
    
    $parameters = @(
        "/${PROJECT_NAME}/dev/mysql/host",
        "/${PROJECT_NAME}/dev/mysql/user",
        "/${PROJECT_NAME}/dev/mysql/password",
        "/${PROJECT_NAME}/dev/jwt/secret",
        "/${PROJECT_NAME}/prod/mysql/host",
        "/${PROJECT_NAME}/prod/mysql/user",
        "/${PROJECT_NAME}/prod/mysql/password",
        "/${PROJECT_NAME}/prod/jwt/secret"
    )
    
    foreach ($param in $parameters) {
        aws ssm delete-parameter --name $param --region $AWS_REGION 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✓ Deleted parameter: $param" $COLOR_GREEN
        }
    }
} else {
    Write-ColorOutput "`nKeeping SSM parameters (--KeepParameters specified)" $COLOR_YELLOW
}

Write-ColorOutput "`n╔═══════════════════════════════════════════════════════════╗" $COLOR_GREEN
Write-ColorOutput "║   Teardown Complete!                                     ║" $COLOR_GREEN
Write-ColorOutput "╚═══════════════════════════════════════════════════════════╝" $COLOR_GREEN

Write-ColorOutput "`nRemaining resources:" $COLOR_CYAN
if ($KeepArtifacts) {
    Write-ColorOutput "  - S3 buckets (kept)" $COLOR_YELLOW
}
if ($KeepECR) {
    Write-ColorOutput "  - ECR repositories (kept)" $COLOR_YELLOW
}
if ($KeepParameters) {
    Write-ColorOutput "  - SSM parameters (kept)" $COLOR_YELLOW
}

exit 0
