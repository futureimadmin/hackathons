#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup CI/CD pipeline in AWS

.DESCRIPTION
    This script deploys the CodePipeline infrastructure using CloudFormation

.PARAMETER GitHubRepo
    GitHub repository in format: username/repo-name

.PARAMETER GitHubBranch
    GitHub branch to track (default: main)

.PARAMETER GitHubToken
    GitHub personal access token

.PARAMETER DevApprovalEmail
    Email for dev deployment approvals

.PARAMETER ProdApprovalEmail
    Email for production deployment approvals

.EXAMPLE
    .\setup-pipeline.ps1 -GitHubRepo "myorg/ecommerce-ai-platform" -GitHubToken "ghp_xxx" -DevApprovalEmail "dev@example.com" -ProdApprovalEmail "prod@example.com"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubRepo,
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubBranch = "main",
    
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory=$true)]
    [string]$DevApprovalEmail,
    
    [Parameter(Mandatory=$true)]
    [string]$ProdApprovalEmail
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
║   Setting Up CI/CD Pipeline                              ║
╚═══════════════════════════════════════════════════════════╝
"@ $COLOR_CYAN

# Check prerequisites
Write-ColorOutput "`nChecking prerequisites..." $COLOR_CYAN

try {
    aws --version | Out-Null
    Write-ColorOutput "✓ AWS CLI installed" $COLOR_GREEN
} catch {
    Write-ColorOutput "✗ AWS CLI not found" $COLOR_RED
    exit 1
}

try {
    aws sts get-caller-identity | Out-Null
    Write-ColorOutput "✓ AWS credentials configured" $COLOR_GREEN
} catch {
    Write-ColorOutput "✗ AWS credentials not configured" $COLOR_RED
    exit 1
}

# Create ECR repository if it doesn't exist
Write-ColorOutput "`nCreating ECR repository..." $COLOR_CYAN
aws ecr create-repository --repository-name ${PROJECT_NAME}-data-processing --region $AWS_REGION 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "✓ ECR repository created" $COLOR_GREEN
} else {
    Write-ColorOutput "✓ ECR repository already exists" $COLOR_GREEN
}

# Create S3 buckets for artifacts
Write-ColorOutput "`nCreating S3 buckets..." $COLOR_CYAN

$buckets = @(
    "${PROJECT_NAME}-pipeline-artifacts",
    "${PROJECT_NAME}-artifacts-dev",
    "${PROJECT_NAME}-artifacts-prod"
)

foreach ($bucket in $buckets) {
    aws s3 mb s3://$bucket --region $AWS_REGION 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ Created bucket: $bucket" $COLOR_GREEN
    } else {
        Write-ColorOutput "✓ Bucket already exists: $bucket" $COLOR_GREEN
    }
    
    # Enable versioning
    aws s3api put-bucket-versioning --bucket $bucket --versioning-configuration Status=Enabled --region $AWS_REGION
}

# Store parameters in SSM Parameter Store
Write-ColorOutput "`nStoring parameters in SSM Parameter Store..." $COLOR_CYAN

Write-ColorOutput "Please enter the following parameters for DEV environment:" $COLOR_YELLOW
$devMysqlHost = Read-Host "MySQL Host (dev)"
$devMysqlUser = Read-Host "MySQL User (dev)"
$devMysqlPassword = Read-Host "MySQL Password (dev)" -AsSecureString
$devMysqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($devMysqlPassword))
$devJwtSecret = Read-Host "JWT Secret (dev)" -AsSecureString
$devJwtSecretPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($devJwtSecret))

aws ssm put-parameter --name "/${PROJECT_NAME}/dev/mysql/host" --value $devMysqlHost --type String --overwrite --region $AWS_REGION | Out-Null
aws ssm put-parameter --name "/${PROJECT_NAME}/dev/mysql/user" --value $devMysqlUser --type String --overwrite --region $AWS_REGION | Out-Null
aws ssm put-parameter --name "/${PROJECT_NAME}/dev/mysql/password" --value $devMysqlPasswordPlain --type SecureString --overwrite --region $AWS_REGION | Out-Null
aws ssm put-parameter --name "/${PROJECT_NAME}/dev/jwt/secret" --value $devJwtSecretPlain --type SecureString --overwrite --region $AWS_REGION | Out-Null

Write-ColorOutput "✓ Dev parameters stored" $COLOR_GREEN

Write-ColorOutput "`nPlease enter the following parameters for PROD environment:" $COLOR_YELLOW
$prodMysqlHost = Read-Host "MySQL Host (prod)"
$prodMysqlUser = Read-Host "MySQL User (prod)"
$prodMysqlPassword = Read-Host "MySQL Password (prod)" -AsSecureString
$prodMysqlPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($prodMysqlPassword))
$prodJwtSecret = Read-Host "JWT Secret (prod)" -AsSecureString
$prodJwtSecretPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($prodJwtSecret))

aws ssm put-parameter --name "/${PROJECT_NAME}/prod/mysql/host" --value $prodMysqlHost --type String --overwrite --region $AWS_REGION | Out-Null
aws ssm put-parameter --name "/${PROJECT_NAME}/prod/mysql/user" --value $prodMysqlUser --type String --overwrite --region $AWS_REGION | Out-Null
aws ssm put-parameter --name "/${PROJECT_NAME}/prod/mysql/password" --value $prodMysqlPasswordPlain --type SecureString --overwrite --region $AWS_REGION | Out-Null
aws ssm put-parameter --name "/${PROJECT_NAME}/prod/jwt/secret" --value $prodJwtSecretPlain --type SecureString --overwrite --region $AWS_REGION | Out-Null

Write-ColorOutput "✓ Prod parameters stored" $COLOR_GREEN

# Deploy CloudFormation stack
Write-ColorOutput "`nDeploying CloudFormation stack..." $COLOR_CYAN

$templatePath = "deployment/deployment-pipeline/pipeline-template.yml"

aws cloudformation deploy `
    --template-file $templatePath `
    --stack-name $STACK_NAME `
    --parameter-overrides `
        ProjectName=$PROJECT_NAME `
        GitHubRepo=$GitHubRepo `
        GitHubBranch=$GitHubBranch `
        GitHubToken=$GitHubToken `
        DevApprovalEmail=$DevApprovalEmail `
        ProdApprovalEmail=$ProdApprovalEmail `
    --capabilities CAPABILITY_NAMED_IAM `
    --region $AWS_REGION

if ($LASTEXITCODE -eq 0) {
    Write-ColorOutput "`n✓ Pipeline deployed successfully!" $COLOR_GREEN
    
    # Get outputs
    $outputs = aws cloudformation describe-stacks --stack-name $STACK_NAME --region $AWS_REGION --query "Stacks[0].Outputs" --output json | ConvertFrom-Json
    
    Write-ColorOutput "`n╔═══════════════════════════════════════════════════════════╗" $COLOR_GREEN
    Write-ColorOutput "║   Pipeline Setup Complete!                               ║" $COLOR_GREEN
    Write-ColorOutput "╚═══════════════════════════════════════════════════════════╝" $COLOR_GREEN
    
    Write-ColorOutput "`nPipeline Details:" $COLOR_CYAN
    foreach ($output in $outputs) {
        Write-ColorOutput "  $($output.OutputKey): $($output.OutputValue)" $COLOR_CYAN
    }
    
    Write-ColorOutput "`nNext Steps:" $COLOR_YELLOW
    Write-ColorOutput "1. Confirm SNS subscription emails for dev and prod approvals" $COLOR_YELLOW
    Write-ColorOutput "2. Push code to GitHub to trigger the pipeline" $COLOR_YELLOW
    Write-ColorOutput "3. Monitor pipeline execution in AWS Console" $COLOR_YELLOW
    
} else {
    Write-ColorOutput "`n✗ Pipeline deployment failed" $COLOR_RED
    exit 1
}

exit 0
