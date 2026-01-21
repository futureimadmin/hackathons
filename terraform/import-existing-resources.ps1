# Import Existing AWS Resources into Terraform State
# This script imports resources that exist but aren't in Terraform state

param(
    [string]$Environment = "dev",
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2"
)

Write-Host "Importing Existing AWS Resources into Terraform State" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Project: $ProjectName" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Check if terraform is initialized
if (-not (Test-Path ".terraform")) {
    Write-Host "ERROR: Terraform not initialized. Run 'terraform init' first." -ForegroundColor Red
    exit 1
}

# 1. Import GitHub Token Secret
$secretName = "$ProjectName-github-token-$Environment"
Write-Host "1. Checking GitHub token secret: $secretName" -ForegroundColor Blue

try {
    # Check if secret exists in AWS
    $secret = aws secretsmanager describe-secret --secret-id $secretName --region $Region --output json 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        $secretInfo = $secret | ConvertFrom-Json
        $secretArn = $secretInfo.ARN
        
        Write-Host "   Secret exists in AWS: $secretArn" -ForegroundColor Green
        
        # Check if it's in Terraform state
        $stateCheck = terraform state show "module.cicd_pipeline[0].aws_secretsmanager_secret.github_token" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "   Secret not in Terraform state, importing..." -ForegroundColor Yellow
            
            # Import the secret
            terraform import "module.cicd_pipeline[0].aws_secretsmanager_secret.github_token" $secretArn
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   Successfully imported secret!" -ForegroundColor Green
            } else {
                Write-Host "   Failed to import secret" -ForegroundColor Red
            }
        } else {
            Write-Host "   Secret already in Terraform state" -ForegroundColor Green
        }
    } else {
        Write-Host "   Secret does not exist in AWS" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Error checking secret: $_" -ForegroundColor Red
}

# 2. Import GitHub Connection (if it exists)
$connectionName = "github-hackathons"
Write-Host ""
Write-Host "2. Checking GitHub connection: $connectionName" -ForegroundColor Blue

try {
    # Check if connection exists
    $connections = aws codestar-connections list-connections --region $Region --query "Connections[?ConnectionName=='$connectionName']" --output json 2>$null
    
    if ($connections -and $connections -ne "[]") {
        $connection = $connections | ConvertFrom-Json | Select-Object -First 1
        $connectionArn = $connection.ConnectionArn
        
        Write-Host "   Connection exists in AWS: $connectionArn" -ForegroundColor Green
        
        # Check if it's in Terraform state
        $stateCheck = terraform state show "module.cicd_pipeline[0].aws_codestarconnections_connection.github" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "   Connection not in Terraform state, importing..." -ForegroundColor Yellow
            
            # Import the connection
            terraform import "module.cicd_pipeline[0].aws_codestarconnections_connection.github" $connectionArn
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   Successfully imported connection!" -ForegroundColor Green
            } else {
                Write-Host "   Failed to import connection" -ForegroundColor Red
            }
        } else {
            Write-Host "   Connection already in Terraform state" -ForegroundColor Green
        }
    } else {
        Write-Host "   Connection does not exist in AWS" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Error checking connection: $_" -ForegroundColor Red
}

# 3. Import S3 Pipeline Artifacts Bucket (if it exists)
$bucketName = "$ProjectName-pipeline-artifacts-$Environment"
Write-Host ""
Write-Host "3. Checking S3 pipeline artifacts bucket: $bucketName" -ForegroundColor Blue

try {
    # Check if bucket exists
    $bucketExists = aws s3api head-bucket --bucket $bucketName --region $Region 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Bucket exists in AWS: $bucketName" -ForegroundColor Green
        
        # Check if it's in Terraform state
        $stateCheck = terraform state show "module.cicd_pipeline[0].aws_s3_bucket.pipeline_artifacts" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "   Bucket not in Terraform state, importing..." -ForegroundColor Yellow
            
            # Import the bucket
            terraform import "module.cicd_pipeline[0].aws_s3_bucket.pipeline_artifacts" $bucketName
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   Successfully imported bucket!" -ForegroundColor Green
            } else {
                Write-Host "   Failed to import bucket" -ForegroundColor Red
            }
        } else {
            Write-Host "   Bucket already in Terraform state" -ForegroundColor Green
        }
    } else {
        Write-Host "   Bucket does not exist in AWS" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Error checking bucket: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "4. Next steps:" -ForegroundColor Blue
Write-Host "   After importing, run:" -ForegroundColor White
Write-Host "   terraform plan -var-file=`"terraform.dev.tfvars`"" -ForegroundColor Gray
Write-Host "   terraform apply -var-file=`"terraform.dev.tfvars`"" -ForegroundColor Gray
Write-Host ""
Write-Host "   Terraform should now recognize existing resources and avoid recreation." -ForegroundColor White

Write-Host ""
Write-Host "Resource import complete!" -ForegroundColor Green