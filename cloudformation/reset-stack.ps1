# Reset CloudFormation Stack from REVIEW_IN_PROGRESS state
# This script handles stacks stuck in review state

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2",
    [switch]$Force
)

$StackName = "$ProjectName-$Environment"

Write-Host "Resetting CloudFormation stack from REVIEW_IN_PROGRESS state" -ForegroundColor Yellow
Write-Host "Stack Name: $StackName" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Check current stack status
Write-Host "1. Checking current stack status..." -ForegroundColor Blue
try {
    $stackStatus = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].StackStatus" --output text 2>$null
    Write-Host "   Current status: $stackStatus" -ForegroundColor White
    
    if ($stackStatus -ne "REVIEW_IN_PROGRESS") {
        Write-Host "   Stack is not in REVIEW_IN_PROGRESS state. Current state: $stackStatus" -ForegroundColor Yellow
        Write-Host "   Use appropriate script for this state:" -ForegroundColor Yellow
        Write-Host "   - For failed states: .\delete-stack.ps1 -Environment $Environment -Force" -ForegroundColor White
        Write-Host "   - For normal states: .\deploy-stack.ps1 -Environment $Environment -GitHubToken 'your_token'" -ForegroundColor White
        exit 0
    }
} catch {
    Write-Host "   Stack does not exist" -ForegroundColor Red
    exit 1
}

# Check for any remaining changesets
Write-Host "2. Checking for remaining changesets..." -ForegroundColor Blue
$changesets = aws cloudformation list-change-sets --stack-name $StackName --region $Region --query "Summaries[].ChangeSetName" --output text 2>$null
if ($changesets -and $changesets -ne "None") {
    Write-Host "   Found remaining changesets: $changesets" -ForegroundColor Yellow
    Write-Host "   Deleting remaining changesets..." -ForegroundColor Blue
    
    $changesetList = $changesets -split "`t"
    foreach ($changeset in $changesetList) {
        if ($changeset.Trim()) {
            Write-Host "   Deleting changeset: $changeset" -ForegroundColor Gray
            aws cloudformation delete-change-set --change-set-name $changeset --stack-name $StackName --region $Region 2>$null
        }
    }
} else {
    Write-Host "   No remaining changesets found" -ForegroundColor Green
}

# For REVIEW_IN_PROGRESS state, we need to delete the stack
Write-Host "3. Stack is in REVIEW_IN_PROGRESS state - deletion required" -ForegroundColor Yellow

if (-not $Force) {
    Write-Host ""
    Write-Host "The stack is stuck in REVIEW_IN_PROGRESS state and must be deleted." -ForegroundColor Yellow
    Write-Host "This will remove all resources created by the stack." -ForegroundColor Yellow
    Write-Host ""
    $confirmation = Read-Host "Do you want to delete the stack and start fresh? (y/N)"
    
    if ($confirmation -ne "y" -and $confirmation -ne "Y") {
        Write-Host "Operation cancelled" -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "4. Deleting stack..." -ForegroundColor Blue
try {
    aws cloudformation delete-stack --stack-name $StackName --region $Region
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Stack deletion initiated" -ForegroundColor Green
        Write-Host "   Waiting for deletion to complete..." -ForegroundColor Blue
        
        # Wait for deletion with timeout
        $timeout = 300  # 5 minutes
        $elapsed = 0
        $interval = 10
        
        do {
            Start-Sleep $interval
            $elapsed += $interval
            
            try {
                $status = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].StackStatus" --output text 2>$null
                if (-not $status) {
                    Write-Host "   Stack deleted successfully!" -ForegroundColor Green
                    break
                }
                Write-Host "   Current status: $status (${elapsed}s elapsed)" -ForegroundColor Gray
            } catch {
                Write-Host "   Stack deleted successfully!" -ForegroundColor Green
                break
            }
            
            if ($elapsed -ge $timeout) {
                Write-Host "   Deletion is taking longer than expected. Check AWS Console for progress." -ForegroundColor Yellow
                break
            }
        } while ($true)
        
    } else {
        Write-Host "   Failed to initiate stack deletion" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "   Error deleting stack: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Stack reset complete!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Deploy fresh stack: .\deploy-stack.ps1 -Environment $Environment -GitHubToken 'your_token'" -ForegroundColor White
Write-Host "  2. Or troubleshoot first: .\troubleshoot-deployment.ps1 -Environment $Environment" -ForegroundColor White