# Delete eCommerce AI Platform CloudFormation Stack
# This script safely deletes the complete infrastructure stack

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2",
    [switch]$Force
)

$StackName = "$ProjectName-$Environment"

Write-Host "Deleting eCommerce AI Platform Stack" -ForegroundColor Red
Write-Host "Stack Name: $StackName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow

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

# Show what will be deleted
Write-Host "Resources that will be deleted:" -ForegroundColor Yellow
aws cloudformation list-stack-resources --stack-name $StackName --region $Region --query "StackResourceSummaries[].{Type:ResourceType,LogicalId:LogicalResourceId,Status:ResourceStatus}" --output table

# Confirmation prompt
if (-not $Force) {
    Write-Host "WARNING: This will permanently delete all resources in the stack!" -ForegroundColor Red
    $confirmation = Read-Host "Are you sure you want to delete stack '$StackName'? Type 'DELETE' to confirm"
    
    if ($confirmation -ne "DELETE") {
        Write-Host "Deletion cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Pre-deletion cleanup for resources that need special handling
Write-Host "Performing pre-deletion cleanup..." -ForegroundColor Blue

# Empty S3 buckets before deletion
try {
    $frontendBucket = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='FrontendBucketName'].OutputValue" --output text 2>$null
    if ($frontendBucket -and $frontendBucket -ne "None") {
        Write-Host "  Emptying S3 bucket: $frontendBucket" -ForegroundColor Gray
        aws s3 rm "s3://$frontendBucket" --recursive 2>$null
        
        # Delete all versions if versioning is enabled
        $versions = aws s3api list-object-versions --bucket $frontendBucket --query "Versions[].{Key: Key, VersionId: VersionId}" --output json 2>$null
        if ($versions -and $versions -ne "null" -and $versions -ne "[]") {
            $versions | aws s3api delete-objects --bucket $frontendBucket --delete file:///dev/stdin 2>$null
        }
        
        # Delete delete markers
        $deleteMarkers = aws s3api list-object-versions --bucket $frontendBucket --query "DeleteMarkers[].{Key: Key, VersionId: VersionId}" --output json 2>$null
        if ($deleteMarkers -and $deleteMarkers -ne "null" -and $deleteMarkers -ne "[]") {
            $deleteMarkers | aws s3api delete-objects --bucket $frontendBucket --delete file:///dev/stdin 2>$null
        }
    }
    
    $terraformBucket = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='TerraformStateBucket'].OutputValue" --output text 2>$null
    if ($terraformBucket -and $terraformBucket -ne "None") {
        Write-Host "  Emptying Terraform state bucket: $terraformBucket" -ForegroundColor Gray
        aws s3 rm "s3://$terraformBucket" --recursive 2>$null
        
        # Delete all versions
        $versions = aws s3api list-object-versions --bucket $terraformBucket --query "Versions[].{Key: Key, VersionId: VersionId}" --output json 2>$null
        if ($versions -and $versions -ne "null" -and $versions -ne "[]") {
            $versions | aws s3api delete-objects --bucket $terraformBucket --delete file:///dev/stdin 2>$null
        }
    }
} catch {
    Write-Host "  Warning: Could not empty S3 buckets: $_" -ForegroundColor Yellow
}

# Delete the stack
Write-Host "Deleting CloudFormation stack..." -ForegroundColor Blue

try {
    aws cloudformation delete-stack --stack-name $StackName --region $Region
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Stack deletion initiated" -ForegroundColor Green
        Write-Host "Waiting for stack deletion to complete..." -ForegroundColor Blue
        
        # Wait for deletion to complete
        aws cloudformation wait stack-delete-complete --stack-name $StackName --region $Region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Stack '$StackName' deleted successfully!" -ForegroundColor Green
        } else {
            Write-Host "Stack deletion failed or timed out" -ForegroundColor Red
            Write-Host "Check AWS Console for details" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "Failed to initiate stack deletion!" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error deleting stack: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Environment '$Environment' has been completely removed!" -ForegroundColor Green