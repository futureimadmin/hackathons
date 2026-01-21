# Validate CloudFormation Prerequisites
# This script checks if the CloudFormation stack includes all required prerequisites

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,
    
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2"
)

$StackName = "$ProjectName-$Environment"

Write-Host "Validating CloudFormation Prerequisites" -ForegroundColor Green
Write-Host "Stack Name: $StackName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Check if stack exists
try {
    $stackInfo = aws cloudformation describe-stacks --stack-name $StackName --region $Region --output json 2>$null | ConvertFrom-Json
    if (-not $stackInfo) {
        Write-Host "Stack '$StackName' does not exist" -ForegroundColor Red
        Write-Host "Run: .\cloudformation\deploy-stack.ps1 -Environment $Environment -GitHubToken <token>" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "Stack exists" -ForegroundColor Green
} catch {
    Write-Host "Stack '$StackName' does not exist" -ForegroundColor Red
    Write-Host "Run: .\cloudformation\deploy-stack.ps1 -Environment $Environment -GitHubToken <token>" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Checking Prerequisites..." -ForegroundColor Blue

# 1. Check Terraform State S3 Bucket
Write-Host ""
Write-Host "1. Terraform State S3 Bucket" -ForegroundColor Cyan
try {
    $terraformBucket = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='TerraformStateBucket'].OutputValue" --output text 2>$null
    if ($terraformBucket -and $terraformBucket -ne "None") {
        $bucketExists = aws s3api head-bucket --bucket $terraformBucket --region $Region 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ S3 Bucket: $terraformBucket" -ForegroundColor Green
            
            # Check versioning
            $versioning = aws s3api get-bucket-versioning --bucket $terraformBucket --region $Region --query "Status" --output text 2>$null
            if ($versioning -eq "Enabled") {
                Write-Host "   ✅ Versioning: Enabled" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  Versioning: $versioning" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ❌ S3 Bucket not accessible: $terraformBucket" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ Terraform State Bucket not found in stack outputs" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Error checking S3 bucket: $_" -ForegroundColor Red
}

# 2. Check Terraform Locks DynamoDB Table
Write-Host ""
Write-Host "2️⃣  Terraform Locks DynamoDB Table" -ForegroundColor Cyan
try {
    $locksTable = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='TerraformLocksTable'].OutputValue" --output text 2>$null
    if ($locksTable -and $locksTable -ne "None") {
        $tableStatus = aws dynamodb describe-table --table-name $locksTable --region $Region --query "Table.TableStatus" --output text 2>$null
        if ($tableStatus -eq "ACTIVE") {
            Write-Host "   ✅ DynamoDB Table: $locksTable" -ForegroundColor Green
            Write-Host "   ✅ Status: $tableStatus" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  DynamoDB Table: $locksTable (Status: $tableStatus)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   ❌ Terraform Locks Table not found in stack outputs" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Error checking DynamoDB table: $_" -ForegroundColor Red
}

# 3. Check DMS VPC Role
Write-Host ""
Write-Host "3️⃣  DMS VPC Role" -ForegroundColor Cyan
try {
    $dmsRoleArn = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='DMSVPCRoleArn'].OutputValue" --output text 2>$null
    if ($dmsRoleArn -and $dmsRoleArn -ne "None") {
        $roleExists = aws iam get-role --role-name dms-vpc-role 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ DMS VPC Role: dms-vpc-role" -ForegroundColor Green
            Write-Host "   ✅ ARN: $dmsRoleArn" -ForegroundColor Green
            
            # Check attached policies
            $attachedPolicies = aws iam list-attached-role-policies --role-name dms-vpc-role --query "AttachedPolicies[?PolicyName=='AmazonDMSVPCManagementRole'].PolicyName" --output text 2>$null
            if ($attachedPolicies -eq "AmazonDMSVPCManagementRole") {
                Write-Host "   ✅ Policy: AmazonDMSVPCManagementRole attached" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  Policy: AmazonDMSVPCManagementRole not attached" -ForegroundColor Yellow
            }
        } else {
            Write-Host "   ❌ DMS VPC Role not accessible" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ DMS VPC Role not found in stack outputs" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Error checking DMS VPC Role: $_" -ForegroundColor Red
}

# 4. Check MySQL Password Secret
Write-Host ""
Write-Host "4️⃣  MySQL Password Secret" -ForegroundColor Cyan
try {
    $secretArn = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs[?OutputKey=='MySQLPasswordSecretArn'].OutputValue" --output text 2>$null
    if ($secretArn -and $secretArn -ne "None") {
        $secretInfo = aws secretsmanager describe-secret --secret-id $secretArn --region $Region --query "Name" --output text 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Secret: $secretInfo" -ForegroundColor Green
            Write-Host "   ✅ ARN: $secretArn" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Secret not accessible: $secretArn" -ForegroundColor Red
        }
    } else {
        Write-Host "   ❌ MySQL Password Secret not found in stack outputs" -ForegroundColor Red
    }
} catch {
    Write-Host "   ❌ Error checking MySQL Password Secret: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "📊 Summary" -ForegroundColor Blue
Write-Host "============================================" -ForegroundColor Blue

# Get all outputs for summary
try {
    $outputs = aws cloudformation describe-stacks --stack-name $StackName --region $Region --query "Stacks[0].Outputs" --output json 2>$null | ConvertFrom-Json
    
    $hasS3 = $outputs | Where-Object { $_.OutputKey -eq "TerraformStateBucket" }
    $hasDynamoDB = $outputs | Where-Object { $_.OutputKey -eq "TerraformLocksTable" }
    $hasDMSRole = $outputs | Where-Object { $_.OutputKey -eq "DMSVPCRoleArn" }
    $hasSecret = $outputs | Where-Object { $_.OutputKey -eq "MySQLPasswordSecretArn" }
    
    $allPrerequisites = $hasS3 -and $hasDynamoDB -and $hasDMSRole -and $hasSecret
    
    if ($allPrerequisites) {
        Write-Host "🎉 All Prerequisites Available in CloudFormation Stack!" -ForegroundColor Green
        Write-Host ""
        Write-Host "✅ You DO NOT need to run the prerequisite scripts:" -ForegroundColor Green
        Write-Host "   • create-backend-resources.ps1 ❌ (Not needed)" -ForegroundColor Gray
        Write-Host "   • create-dms-vpc-role.ps1 ❌ (Not needed)" -ForegroundColor Gray
        Write-Host "   • create-mysql-secret.ps1 ❌ (Not needed)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "🚀 You can directly run Terraform:" -ForegroundColor Green
        Write-Host "   cd terraform" -ForegroundColor Cyan
        Write-Host "   terraform init" -ForegroundColor Cyan
        Write-Host "   terraform plan -var-file=terraform.$Environment.tfvars" -ForegroundColor Cyan
        Write-Host "   terraform apply -var-file=terraform.$Environment.tfvars" -ForegroundColor Cyan
    } else {
        Write-Host "⚠️  Some Prerequisites Missing from CloudFormation Stack" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Missing components:" -ForegroundColor Red
        if (-not $hasS3) { Write-Host "   ❌ Terraform State S3 Bucket" -ForegroundColor Red }
        if (-not $hasDynamoDB) { Write-Host "   ❌ Terraform Locks DynamoDB Table" -ForegroundColor Red }
        if (-not $hasDMSRole) { Write-Host "   ❌ DMS VPC Role" -ForegroundColor Red }
        if (-not $hasSecret) { Write-Host "   ❌ MySQL Password Secret" -ForegroundColor Red }
        Write-Host ""
        Write-Host "💡 You may need to run prerequisite scripts manually" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error getting stack outputs: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "💡 Next Steps:" -ForegroundColor Yellow
Write-Host "1. If all prerequisites are available, proceed with Terraform" -ForegroundColor White
Write-Host "2. If any are missing, update CloudFormation template or run prerequisite scripts" -ForegroundColor White
Write-Host "3. Use: .\cloudformation\stack-status.ps1 -Environment $Environment -Detailed for more info" -ForegroundColor White