# Deploy Lambda Functions for Data Pipeline
# Creates deployment packages and uploads to AWS

param(
    [string]$Region = "us-east-2"
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Deploying Data Pipeline Lambda Functions" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$Functions = @(
    @{
        Name = "raw-to-curated"
        DisplayName = "Raw to Curated Processor"
    },
    @{
        Name = "curated-to-prod"
        DisplayName = "Curated to Prod AI Processor"
    }
)

foreach ($Function in $Functions) {
    $FunctionName = $Function.Name
    $DisplayName = $Function.DisplayName
    
    Write-Host "[INFO] Packaging $DisplayName..." -ForegroundColor Cyan
    
    # Create deployment package directory
    $DeployDir = "$FunctionName/package"
    if (Test-Path $DeployDir) {
        Remove-Item -Recurse -Force $DeployDir
    }
    New-Item -ItemType Directory -Path $DeployDir | Out-Null
    
    # Install dependencies
    Write-Host "  Installing dependencies..." -ForegroundColor White
    pip install -r "$FunctionName/requirements.txt" -t $DeployDir --quiet
    
    # Copy Lambda function
    Copy-Item "$FunctionName/lambda_function.py" -Destination $DeployDir
    
    # Create ZIP file
    $ZipFile = "$FunctionName-deployment.zip"
    Write-Host "  Creating deployment package: $ZipFile" -ForegroundColor White
    
    if (Test-Path $ZipFile) {
        Remove-Item $ZipFile
    }
    
    Compress-Archive -Path "$DeployDir/*" -DestinationPath $ZipFile
    
    Write-Host "[OK] $DisplayName packaged successfully" -ForegroundColor Green
    Write-Host "  Package size: $((Get-Item $ZipFile).Length / 1MB) MB" -ForegroundColor White
    Write-Host ""
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "Lambda Functions Packaged Successfully!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Run Terraform to create Lambda functions:" -ForegroundColor White
Write-Host "   cd ../terraform" -ForegroundColor Cyan
Write-Host "   terraform apply" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Test the pipeline:" -ForegroundColor White
Write-Host "   Upload a file to the raw bucket and check CloudWatch Logs" -ForegroundColor Cyan
Write-Host ""
