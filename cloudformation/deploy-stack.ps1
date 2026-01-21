# Deploy eCommerce AI Platform CloudFormation Stack
# This script creates the complete infrastructure stack

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,
    
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$GitHubRepo = "futureimadmin/hackathons",
    [string]$GitHubBranch = "master",
    [string]$VpcCidr = "10.0.0.0/16",
    [string]$CreateCICDPipeline = "true",
    [string]$MySQLServerIP = "172.20.10.2",
    [string]$MySQLPassword = "SaiesaShanmukha@123",
    [string]$Region = "us-east-2"
)

$StackName = "$ProjectName-$Environment"

Write-Host "Deploying eCommerce AI Platform Stack" -ForegroundColor Green
Write-Host "Stack Name: $StackName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow

# Check if stack exists
$stackExists = $false
try {
    aws cloudformation describe-stacks --stack-name $StackName --region $Region --output table 2>$null
    $stackExists = $true
    Write-Host "Stack exists - will update" -ForegroundColor Blue
} catch {
    Write-Host "Stack does not exist - will create" -ForegroundColor Blue
}

# Deploy the stack
Write-Host "Deploying CloudFormation stack..." -ForegroundColor Blue

$deployCommand = @(
    "aws", "cloudformation", "deploy",
    "--template-file", "ecommerce-ai-platform-stack.yaml",
    "--stack-name", $StackName,
    "--region", $Region,
    "--capabilities", "CAPABILITY_NAMED_IAM",
    "--parameter-overrides",
    "Environment=$Environment",
    "ProjectName=$ProjectName",
    "GitHubRepo=$GitHubRepo",
    "GitHubBranch=$GitHubBranch",
    "GitHubToken=$GitHubToken",
    "VpcCidr=$VpcCidr",
    "CreateCICDPipeline=$CreateCICDPipeline",
    "MySQLServerIP=$MySQLServerIP",
    "MySQLPassword=$MySQLPassword",
    "--tags",
    "Environment=$Environment",
    "Project=$ProjectName",
    "ManagedBy=CloudFormation"
)

Write-Host "Executing: $($deployCommand -join ' ')" -ForegroundColor Gray

try {
    & $deployCommand[0] $deployCommand[1..($deployCommand.Length-1)]
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Stack deployment completed successfully!" -ForegroundColor Green
        
        # Get stack outputs
        Write-Host "Stack Outputs:" -ForegroundColor Blue
        aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs" --output table
        
        # Get important resource information
        Write-Host "Key Resources Created:" -ForegroundColor Blue
        
        $vpcId = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='VPCId'].OutputValue" --output text
        $frontendBucket = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='FrontendBucketName'].OutputValue" --output text
        $usersTable = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='UsersTableName'].OutputValue" --output text
        
        Write-Host "  VPC ID: $vpcId" -ForegroundColor White
        Write-Host "  Frontend Bucket: $frontendBucket" -ForegroundColor White
        Write-Host "  Users Table: $usersTable" -ForegroundColor White
        
        Write-Host "Stack '$StackName' is ready!" -ForegroundColor Green
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Run Terraform to deploy additional resources" -ForegroundColor White
        Write-Host "  2. Deploy Lambda functions" -ForegroundColor White
        Write-Host "  3. Configure CI/CD pipeline" -ForegroundColor White
        
    } else {
        Write-Host "Stack deployment failed!" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Error deploying stack: $_" -ForegroundColor Red
    exit 1
}