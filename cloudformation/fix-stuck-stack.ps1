# Fix Stuck CloudFormation Stack
# This script handles stacks stuck in REVIEW_IN_PROGRESS or other problematic states

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2"
)

$StackName = "$ProjectName-$Environment"

Write-Host "Fixing stuck CloudFormation stack: $StackName" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Function to safely run AWS commands
function Invoke-AWSCommand {
    param([string]$Command)
    
    try {
        $result = Invoke-Expression $Command 2>$null
        return $result
    } catch {
        return $null
    }
}

# Check current stack status
Write-Host "1. Checking current stack status..." -ForegroundColor Blue
$stackStatus = Invoke-AWSCommand "aws cloudformation describe-stacks --stack-name $StackName --region $Region --query 'Stacks[0].StackStatus' --output text"

if ($stackStatus) {
    Write-Host "   Current status: $stackStatus" -ForegroundColor Yellow
    
    if ($stackStatus -eq "REVIEW_IN_PROGRESS") {
        Write-Host "   Stack is stuck in REVIEW_IN_PROGRESS state" -ForegroundColor Red
        Write-Host ""
        
        # List pending changesets
        Write-Host "2. Checking for pending changesets..." -ForegroundColor Blue
        $changesets = Invoke-AWSCommand "aws cloudformation list-change-sets --stack-name $StackName --region $Region --query 'Summaries[].{Name:ChangeSetName,Status:Status,CreationTime:CreationTime}' --output table"
        
        if ($changesets) {
            Write-Host "   Found pending changesets:" -ForegroundColor Yellow
            Write-Host $changesets
            
            # Delete all changesets
            Write-Host ""
            Write-Host "3. Deleting pending changesets..." -ForegroundColor Blue
            $changesetNames = Invoke-AWSCommand "aws cloudformation list-change-sets --stack-name $StackName --region $Region --query 'Summaries[].ChangeSetName' --output text"
            
            if ($changesetNames) {
                $changesetNames.Split("`t") | ForEach-Object {
                    if ($_.Trim()) {
                        Write-Host "   Deleting changeset: $_" -ForegroundColor Gray
                        Invoke-AWSCommand "aws cloudformation delete-change-set --change-set-name $_ --stack-name $StackName --region $Region"
                    }
                }
            }
        }
        
        # Try to cancel stack update
        Write-Host ""
        Write-Host "4. Attempting to cancel stack update..." -ForegroundColor Blue
        $cancelResult = Invoke-AWSCommand "aws cloudformation cancel-update-stack --stack-name $StackName --region $Region 2>&1"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   Stack update cancelled successfully" -ForegroundColor Green
            Write-Host "   Waiting for stack to return to stable state..." -ForegroundColor Blue
            
            # Wait for stack to stabilize
            Start-Sleep -Seconds 10
            $newStatus = Invoke-AWSCommand "aws cloudformation describe-stacks --stack-name $StackName --region $Region --query 'Stacks[0].StackStatus' --output text"
            Write-Host "   New status: $newStatus" -ForegroundColor Yellow
        } else {
            Write-Host "   Could not cancel stack update: $cancelResult" -ForegroundColor Yellow
        }
    }
    
    # If stack is in a failed state, recommend deletion
    if ($stackStatus -like "*FAILED*" -or $stackStatus -like "*ROLLBACK*") {
        Write-Host ""
        Write-Host "Stack is in failed state. Recommended actions:" -ForegroundColor Yellow
        Write-Host "1. Delete the failed stack:" -ForegroundColor White
        Write-Host "   .\delete-stack.ps1 -Environment $Environment -Force" -ForegroundColor Gray
        Write-Host "2. Clean up any remaining resources manually if needed" -ForegroundColor White
        Write-Host "3. Retry deployment:" -ForegroundColor White
        Write-Host "   .\deploy-stack.ps1 -Environment $Environment -GitHubToken 'your_token'" -ForegroundColor Gray
    }
} else {
    Write-Host "   Stack does not exist" -ForegroundColor Green
}

Write-Host ""
Write-Host "5. Resource cleanup recommendations:" -ForegroundColor Blue

# Check for resources that might prevent stack operations
Write-Host "   Checking S3 buckets that might need cleanup..." -ForegroundColor Gray
$buckets = @(
    "$ProjectName-frontend-$Environment",
    "$ProjectName-terraform-state"
)

foreach ($bucket in $buckets) {
    $bucketExists = Invoke-AWSCommand "aws s3api head-bucket --bucket $bucket --region $Region 2>$null"
    if ($LASTEXITCODE -eq 0) {
        # Check if bucket has objects
        $objectCount = Invoke-AWSCommand "aws s3api list-objects-v2 --bucket $bucket --region $Region --query 'KeyCount' --output text 2>$null"
        if ($objectCount -and $objectCount -gt 0) {
            Write-Host "   Bucket '$bucket' has $objectCount objects - may need emptying" -ForegroundColor Yellow
            Write-Host "   To empty: aws s3 rm s3://$bucket --recursive --region $Region" -ForegroundColor Gray
        }
        
        # Check for object versions
        $versionCount = Invoke-AWSCommand "aws s3api list-object-versions --bucket $bucket --region $Region --query 'length(Versions)' --output text 2>$null"
        if ($versionCount -and $versionCount -gt 0) {
            Write-Host "   Bucket '$bucket' has $versionCount versions - may need version cleanup" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "Fix attempt complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Blue
Write-Host "1. If stack is now stable, try deployment again:" -ForegroundColor White
Write-Host "   .\deploy-stack.ps1 -Environment $Environment -GitHubToken 'your_token'" -ForegroundColor Gray
Write-Host "2. If issues persist, delete and recreate:" -ForegroundColor White
Write-Host "   .\delete-stack.ps1 -Environment $Environment -Force" -ForegroundColor Gray
Write-Host "   .\deploy-stack.ps1 -Environment $Environment -GitHubToken 'your_token'" -ForegroundColor Gray