# Troubleshoot CloudFormation Deployment Issues
# This script checks for existing resources that might cause conflicts

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2"
)

$StackName = "$ProjectName-$Environment"

Write-Host "Troubleshooting CloudFormation deployment for: $StackName" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Function to check if AWS CLI is available
function Test-AWSCli {
    try {
        aws --version | Out-Null
        return $true
    } catch {
        Write-Host "ERROR: AWS CLI is not installed or not in PATH" -ForegroundColor Red
        Write-Host "Please install AWS CLI and configure it before running this script" -ForegroundColor Red
        return $false
    }
}

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

if (-not (Test-AWSCli)) {
    exit 1
}

Write-Host "1. Checking Stack Status..." -ForegroundColor Blue
$stackStatus = Invoke-AWSCommand "aws cloudformation describe-stacks --stack-name $StackName --region $Region --query 'Stacks[0].StackStatus' --output text"
if ($stackStatus) {
    Write-Host "   Stack exists with status: $stackStatus" -ForegroundColor Yellow
    
    # Get stack events for failed stacks
    if ($stackStatus -like "*FAILED*" -or $stackStatus -like "*ROLLBACK*") {
        Write-Host "   Getting recent stack events..." -ForegroundColor Blue
        Invoke-AWSCommand "aws cloudformation describe-stack-events --stack-name $StackName --region $Region --query 'StackEvents[?ResourceStatusReason != null] | [0:5].{Time:Timestamp,Status:ResourceStatus,Reason:ResourceStatusReason,Resource:LogicalResourceId}' --output table"
    }
} else {
    Write-Host "   Stack does not exist" -ForegroundColor Green
}

Write-Host ""
Write-Host "2. Checking for Resource Conflicts..." -ForegroundColor Blue

# Check for existing IAM roles
Write-Host "   Checking IAM roles..." -ForegroundColor Gray
$dmsRole = Invoke-AWSCommand "aws iam get-role --role-name dms-vpc-role --region $Region 2>$null"
if ($dmsRole) {
    Write-Host "   WARNING: dms-vpc-role already exists" -ForegroundColor Yellow
}

$lambdaRole = Invoke-AWSCommand "aws iam get-role --role-name $ProjectName-lambda-execution-$Environment --region $Region 2>$null"
if ($lambdaRole) {
    Write-Host "   WARNING: $ProjectName-lambda-execution-$Environment already exists" -ForegroundColor Yellow
}

# Check for existing S3 buckets
Write-Host "   Checking S3 buckets..." -ForegroundColor Gray
$buckets = @(
    "$ProjectName-frontend-$Environment",
    "$ProjectName-terraform-state"
)

foreach ($bucket in $buckets) {
    $bucketExists = Invoke-AWSCommand "aws s3api head-bucket --bucket $bucket --region $Region 2>$null"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   WARNING: S3 bucket '$bucket' already exists" -ForegroundColor Yellow
        
        # Check if bucket is empty
        $objects = Invoke-AWSCommand "aws s3api list-objects-v2 --bucket $bucket --region $Region --query 'Contents[0].Key' --output text 2>$null"
        if ($objects -and $objects -ne "None") {
            Write-Host "   ERROR: Bucket '$bucket' is not empty - this will cause deployment failure" -ForegroundColor Red
        }
    }
}

# Check for existing DynamoDB tables
Write-Host "   Checking DynamoDB tables..." -ForegroundColor Gray
$tables = @(
    "$ProjectName-users-$Environment",
    "$ProjectName-terraform-locks"
)

foreach ($table in $tables) {
    $tableExists = Invoke-AWSCommand "aws dynamodb describe-table --table-name $table --region $Region 2>$null"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   WARNING: DynamoDB table '$table' already exists" -ForegroundColor Yellow
    }
}

# Check for existing Secrets
Write-Host "   Checking Secrets Manager..." -ForegroundColor Gray
$secret = Invoke-AWSCommand "aws secretsmanager describe-secret --secret-id $ProjectName-mysql-password-$Environment --region $Region 2>$null"
if ($LASTEXITCODE -eq 0) {
    Write-Host "   WARNING: Secret '$ProjectName-mysql-password-$Environment' already exists" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "3. Recommendations:" -ForegroundColor Blue

if ($stackStatus -like "*FAILED*" -or $stackStatus -like "*ROLLBACK*") {
    Write-Host "   Stack is in failed state. Options:" -ForegroundColor Yellow
    Write-Host "   1. Delete the failed stack: .\delete-stack.ps1 -Environment $Environment -Force" -ForegroundColor White
    Write-Host "   2. Then retry deployment: .\deploy-stack.ps1 -Environment $Environment -GitHubToken 'your_token'" -ForegroundColor White
} elseif ($stackStatus) {
    Write-Host "   Stack exists. To update: .\deploy-stack.ps1 -Environment $Environment -GitHubToken 'your_token'" -ForegroundColor White
    Write-Host "   To recreate: .\delete-stack.ps1 -Environment $Environment -Force && .\deploy-stack.ps1 -Environment $Environment -GitHubToken 'your_token'" -ForegroundColor White
} else {
    Write-Host "   No conflicts detected. Try deployment: .\deploy-stack.ps1 -Environment $Environment -GitHubToken 'your_token'" -ForegroundColor Green
}

Write-Host ""
Write-Host "4. Common Solutions:" -ForegroundColor Blue
Write-Host "   - If buckets exist and are not empty, empty them first:" -ForegroundColor White
Write-Host "     aws s3 rm s3://bucket-name --recursive --region $Region" -ForegroundColor Gray
Write-Host "   - If IAM roles exist from previous deployments, delete them:" -ForegroundColor White
Write-Host "     aws iam delete-role --role-name role-name --region $Region" -ForegroundColor Gray
Write-Host "   - Use --force flag with delete-stack.ps1 to skip confirmations" -ForegroundColor White

Write-Host ""
Write-Host "Troubleshooting complete!" -ForegroundColor Green