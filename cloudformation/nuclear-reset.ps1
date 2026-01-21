# Nuclear Reset - Complete Environment Cleanup
# This script deletes EVERYTHING and starts completely fresh

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2",
    [switch]$Force
)

$StackName = "$ProjectName-$Environment"

Write-Host "NUCLEAR RESET - COMPLETE ENVIRONMENT CLEANUP" -ForegroundColor Red
Write-Host "=============================================" -ForegroundColor Red
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Project: $ProjectName" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""
Write-Host "WARNING: This will DELETE EVERYTHING!" -ForegroundColor Red
Write-Host "- CloudFormation stacks" -ForegroundColor Red
Write-Host "- All S3 buckets and their contents" -ForegroundColor Red
Write-Host "- DynamoDB tables" -ForegroundColor Red
Write-Host "- IAM roles" -ForegroundColor Red
Write-Host "- Secrets Manager secrets" -ForegroundColor Red
Write-Host "- Any other AWS resources" -ForegroundColor Red
Write-Host ""

if (-not $Force) {
    Write-Host "Are you absolutely sure you want to proceed?" -ForegroundColor Yellow
    $confirmation1 = Read-Host "Type 'NUCLEAR' to confirm"
    
    if ($confirmation1 -ne "NUCLEAR") {
        Write-Host "Operation cancelled" -ForegroundColor Green
        exit 0
    }
    
    Write-Host "Last chance! This action cannot be undone!" -ForegroundColor Red
    $confirmation2 = Read-Host "Type 'DELETE-EVERYTHING' to proceed"
    
    if ($confirmation2 -ne "DELETE-EVERYTHING") {
        Write-Host "Operation cancelled" -ForegroundColor Green
        exit 0
    }
}

Write-Host "Starting nuclear reset..." -ForegroundColor Red
Write-Host ""

# Function to safely run AWS commands
function Invoke-AWSCommand {
    param([string]$Command, [string]$Description)
    
    Write-Host "  $Description..." -ForegroundColor Gray
    try {
        Invoke-Expression $Command 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Success" -ForegroundColor Green
        } else {
            Write-Host "    Warning: Command failed (may not exist)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "    Warning: $_" -ForegroundColor Yellow
    }
}

# 1. Delete CloudFormation Stack
Write-Host "1. Deleting CloudFormation stack..." -ForegroundColor Blue
try {
    $stackExists = aws cloudformation describe-stacks --stack-name $StackName --region $Region 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Stack exists, deleting..." -ForegroundColor Yellow
        
        # First, empty all S3 buckets to prevent deletion failures
        Write-Host "  Emptying S3 buckets first..." -ForegroundColor Gray
        
        # Get all S3 buckets from stack outputs
        $buckets = @()
        try {
            $frontendBucket = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='FrontendBucketName'].OutputValue" --output text 2>$null
            if ($frontendBucket -and $frontendBucket -ne "None") { $buckets += $frontendBucket }
            
            $terraformBucket = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='TerraformStateBucket'].OutputValue" --output text 2>$null
            if ($terraformBucket -and $terraformBucket -ne "None") { $buckets += $terraformBucket }
        } catch {
            Write-Host "    Could not get bucket names from stack outputs" -ForegroundColor Yellow
        }
        
        # Also check for common bucket names
        $commonBuckets = @(
            "$ProjectName-frontend-$Environment",
            "$ProjectName-terraform-state"
        )
        $buckets += $commonBuckets
        
        # Empty each bucket
        foreach ($bucket in $buckets) {
            if ($bucket) {
                Write-Host "    Emptying bucket: $bucket" -ForegroundColor Gray
                
                # Delete all objects
                aws s3 rm "s3://$bucket" --recursive --region $Region 2>$null
                
                # Delete all versions if versioning is enabled
                $versions = aws s3api list-object-versions --bucket $bucket --region $Region --query "Versions[].{Key: Key, VersionId: VersionId}" --output json 2>$null
                if ($versions -and $versions -ne "null" -and $versions -ne "[]") {
                    $versions | ConvertFrom-Json | ForEach-Object {
                        aws s3api delete-object --bucket $bucket --key $_.Key --version-id $_.VersionId --region $Region 2>$null
                    }
                }
                
                # Delete delete markers
                $deleteMarkers = aws s3api list-object-versions --bucket $bucket --region $Region --query "DeleteMarkers[].{Key: Key, VersionId: VersionId}" --output json 2>$null
                if ($deleteMarkers -and $deleteMarkers -ne "null" -and $deleteMarkers -ne "[]") {
                    $deleteMarkers | ConvertFrom-Json | ForEach-Object {
                        aws s3api delete-object --bucket $bucket --key $_.Key --version-id $_.VersionId --region $Region 2>$null
                    }
                }
            }
        }
        
        # Now delete the stack
        aws cloudformation delete-stack --stack-name $StackName --region $Region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Stack deletion initiated, waiting for completion..." -ForegroundColor Blue
            
            # Wait for deletion with progress
            $timeout = 600  # 10 minutes
            $elapsed = 0
            $interval = 15
            
            do {
                Start-Sleep $interval
                $elapsed += $interval
                
                try {
                    $status = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].StackStatus" --output text 2>$null
                    if (-not $status) {
                        Write-Host "  Stack deleted successfully!" -ForegroundColor Green
                        break
                    }
                    Write-Host "    Status: $status (${elapsed}s elapsed)" -ForegroundColor Gray
                    
                    if ($status -like "*FAILED*") {
                        Write-Host "  Stack deletion failed, continuing with manual cleanup..." -ForegroundColor Yellow
                        break
                    }
                } catch {
                    Write-Host "  Stack deleted successfully!" -ForegroundColor Green
                    break
                }
                
                if ($elapsed -ge $timeout) {
                    Write-Host "  Deletion timeout, continuing with manual cleanup..." -ForegroundColor Yellow
                    break
                }
            } while ($true)
        }
    } else {
        Write-Host "  No CloudFormation stack found" -ForegroundColor Green
    }
} catch {
    Write-Host "  Error with CloudFormation: $_" -ForegroundColor Yellow
}

# 2. Manual cleanup of remaining resources
Write-Host ""
Write-Host "2. Manual cleanup of remaining resources..." -ForegroundColor Blue

# Delete S3 buckets
Write-Host "  Cleaning up S3 buckets..." -ForegroundColor Gray
$allBuckets = @(
    "$ProjectName-frontend-$Environment",
    "$ProjectName-terraform-state",
    "$ProjectName-pipeline-artifacts-$Environment"
)

foreach ($bucket in $allBuckets) {
    try {
        $bucketExists = aws s3api head-bucket --bucket $bucket --region $Region 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Deleting bucket: $bucket" -ForegroundColor Gray
            aws s3 rb "s3://$bucket" --force --region $Region 2>$null
        }
    } catch {
        # Bucket doesn't exist, which is fine
    }
}

# Delete DynamoDB tables
Write-Host "  Cleaning up DynamoDB tables..." -ForegroundColor Gray
$tables = @(
    "$ProjectName-users-$Environment",
    "$ProjectName-terraform-locks"
)

foreach ($table in $tables) {
    Invoke-AWSCommand "aws dynamodb delete-table --table-name $table --region $Region" "Deleting table $table"
}

# Delete IAM roles
Write-Host "  Cleaning up IAM roles..." -ForegroundColor Gray
$roles = @(
    "dms-vpc-role",
    "$ProjectName-lambda-execution-$Environment",
    "$ProjectName-codebuild-role-$Environment",
    "$ProjectName-codepipeline-role-$Environment"
)

foreach ($role in $roles) {
    try {
        # Detach policies first
        $policies = aws iam list-attached-role-policies --role-name $role --query "AttachedPolicies[].PolicyArn" --output text 2>$null
        if ($policies -and $policies -ne "None") {
            $policyList = $policies -split "`t"
            foreach ($policy in $policyList) {
                if ($policy.Trim()) {
                    aws iam detach-role-policy --role-name $role --policy-arn $policy 2>$null
                }
            }
        }
        
        # Delete inline policies
        $inlinePolicies = aws iam list-role-policies --role-name $role --query "PolicyNames" --output text 2>$null
        if ($inlinePolicies -and $inlinePolicies -ne "None") {
            $inlinePolicyList = $inlinePolicies -split "`t"
            foreach ($inlinePolicy in $inlinePolicyList) {
                if ($inlinePolicy.Trim()) {
                    aws iam delete-role-policy --role-name $role --policy-name $inlinePolicy 2>$null
                }
            }
        }
        
        # Delete the role
        aws iam delete-role --role-name $role 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Deleted role: $role" -ForegroundColor Green
        }
    } catch {
        Write-Host "    Could not delete role: $role" -ForegroundColor Yellow
    }
}

# Delete Secrets
Write-Host "  Cleaning up Secrets Manager..." -ForegroundColor Gray
$secrets = @(
    "$ProjectName-mysql-password-$Environment",
    "$ProjectName-github-token-$Environment"
)

foreach ($secret in $secrets) {
    Invoke-AWSCommand "aws secretsmanager delete-secret --secret-id $secret --force-delete-without-recovery --region $Region" "Deleting secret $secret"
}

# Clean up local Terraform state
Write-Host ""
Write-Host "3. Cleaning up local Terraform state..." -ForegroundColor Blue
$terraformFiles = @(
    ".terraform",
    ".terraform.lock.hcl",
    "terraform.tfstate",
    "terraform.tfstate.backup",
    "tfplan"
)

foreach ($file in $terraformFiles) {
    if (Test-Path $file) {
        Write-Host "  Removing: $file" -ForegroundColor Gray
        if (Test-Path $file -PathType Container) {
            Remove-Item $file -Recurse -Force
        } else {
            Remove-Item $file -Force
        }
    }
}

Write-Host ""
Write-Host "NUCLEAR RESET COMPLETE!" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host ""
Write-Host "Environment '$Environment' has been completely wiped!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps to start fresh:" -ForegroundColor Yellow
Write-Host "  1. Deploy CloudFormation stack:" -ForegroundColor White
Write-Host "     .\deploy-stack.ps1 -Environment $Environment -GitHubToken 'your_token'" -ForegroundColor Gray
Write-Host "  2. Or use Terraform directly:" -ForegroundColor White
Write-Host "     .\create-backend-resources.ps1" -ForegroundColor Gray
Write-Host "     .\create-dms-vpc-role.ps1" -ForegroundColor Gray
Write-Host "     .\create-mysql-secret.ps1" -ForegroundColor Gray
Write-Host "     terraform init" -ForegroundColor Gray
Write-Host "     terraform apply -var-file=`"terraform.dev.tfvars`"" -ForegroundColor Gray
Write-Host ""
Write-Host "The environment is now completely clean!" -ForegroundColor Green