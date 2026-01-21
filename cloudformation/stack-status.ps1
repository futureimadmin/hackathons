# Check eCommerce AI Platform CloudFormation Stack Status
# This script shows the current status and resources of the stack

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2",
    [switch]$Detailed
)

$StackName = "$ProjectName-$Environment"

Write-Host "eCommerce AI Platform Stack Status" -ForegroundColor Green
Write-Host "Stack Name: $StackName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Check if stack exists
try {
    $stackInfo = aws cloudformation describe-stacks --stack-name $StackName --region $Region --output json 2>$null | ConvertFrom-Json
    if (-not $stackInfo) {
        Write-Host "Stack '$StackName' does not exist" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Stack '$StackName' does not exist" -ForegroundColor Red
    exit 1
}

# Show stack status
Write-Host "Stack Information:" -ForegroundColor Blue
aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].{StackName:StackName,Status:StackStatus,CreationTime:CreationTime,LastUpdatedTime:LastUpdatedTime}" --output table

Write-Host ""
Write-Host "Stack Outputs:" -ForegroundColor Blue
aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs" --output table

if ($Detailed) {
    Write-Host ""
    Write-Host "Stack Resources:" -ForegroundColor Blue
    aws cloudformation list-stack-resources --stack-name $StackName --region $Region --query "StackResourceSummaries[].{Type:ResourceType,LogicalId:LogicalResourceId,PhysicalId:PhysicalResourceId,Status:ResourceStatus}" --output table
    
    Write-Host ""
    Write-Host "Stack Tags:" -ForegroundColor Blue
    aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Tags" --output table
    
    Write-Host ""
    Write-Host "Stack Events (Last 10):" -ForegroundColor Blue
    aws cloudformation describe-stack-events --stack-name $StackName --region $Region --query "StackEvents[:10].{Time:Timestamp,Status:ResourceStatus,Type:ResourceType,Reason:ResourceStatusReason}" --output table
}

# Show key resource information
Write-Host ""
Write-Host "Key Resources:" -ForegroundColor Blue

try {
    $vpcId = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='VPCId'].OutputValue" --output text
    $frontendBucket = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='FrontendBucketName'].OutputValue" --output text
    $usersTable = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='UsersTableName'].OutputValue" --output text
    $kmsKey = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='KMSKeyId'].OutputValue" --output text
    $websiteUrl = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='FrontendWebsiteURL'].OutputValue" --output text
    
    Write-Host "  VPC ID: $vpcId" -ForegroundColor White
    Write-Host "  Frontend Bucket: $frontendBucket" -ForegroundColor White
    Write-Host "  Users Table: $usersTable" -ForegroundColor White
    Write-Host "  KMS Key: $kmsKey" -ForegroundColor White
    Write-Host "  Website URL: $websiteUrl" -ForegroundColor White
} catch {
    Write-Host "  Could not retrieve resource information" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Available Commands:" -ForegroundColor Yellow
Write-Host "  Deploy: .\cloudformation\deploy-stack.ps1 -Environment $Environment -GitHubToken <token>" -ForegroundColor White
Write-Host "  Delete: .\cloudformation\delete-stack.ps1 -Environment $Environment" -ForegroundColor White
Write-Host "  Status: .\cloudformation\stack-status.ps1 -Environment $Environment [-Detailed]" -ForegroundColor White