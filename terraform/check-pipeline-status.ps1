# Check CI/CD Pipeline Status and Recreate if Needed

param(
    [string]$Environment = "dev",
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2"
)

$PipelineName = "$ProjectName-pipeline-$Environment"

Write-Host "Checking CI/CD Pipeline Status" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "Pipeline Name: $PipelineName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

# Check if pipeline exists
Write-Host "1. Checking pipeline status..." -ForegroundColor Blue
try {
    $pipeline = aws codepipeline get-pipeline --name $PipelineName --region $Region 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   Pipeline exists" -ForegroundColor Green
        
        # Get pipeline status
        $pipelineStatus = aws codepipeline get-pipeline-state --name $PipelineName --region $Region --query "stageStates[0].latestExecution.status" --output text 2>$null
        Write-Host "   Status: $pipelineStatus" -ForegroundColor White
        
        # List recent executions
        Write-Host "   Recent executions:" -ForegroundColor White
        aws codepipeline list-pipeline-executions --pipeline-name $PipelineName --region $Region --query "pipelineExecutionSummaries[0:3].{Status:status,StartTime:startTime}" --output table 2>$null
        
        Write-Host ""
        Write-Host "Pipeline is available and ready!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "   Pipeline does not exist" -ForegroundColor Red
    }
} catch {
    Write-Host "   Error checking pipeline: $_" -ForegroundColor Red
}

# Check GitHub connection
Write-Host "2. Checking GitHub connection..." -ForegroundColor Blue
try {
    $connections = aws codestar-connections list-connections --region $Region --query "Connections[?ConnectionName=='github-hackathons']" --output json 2>$null
    
    if ($connections -and $connections -ne "[]") {
        $connection = $connections | ConvertFrom-Json | Select-Object -First 1
        $connectionStatus = $connection.ConnectionStatus
        
        Write-Host "   Connection found: github-hackathons" -ForegroundColor Green
        Write-Host "   Status: $connectionStatus" -ForegroundColor White
        
        if ($connectionStatus -ne "AVAILABLE") {
            Write-Host "   WARNING: Connection is not available" -ForegroundColor Yellow
            Write-Host "   You may need to authorize it in AWS Console" -ForegroundColor Yellow
        }
    } else {
        Write-Host "   GitHub connection 'github-hackathons' not found" -ForegroundColor Red
    }
} catch {
    Write-Host "   Error checking connection: $_" -ForegroundColor Red
}

# Check Terraform state
Write-Host "3. Checking Terraform state..." -ForegroundColor Blue
if (Test-Path "terraform.tfstate") {
    Write-Host "   Local state file exists" -ForegroundColor Green
} elseif (Test-Path ".terraform") {
    Write-Host "   Remote state configured" -ForegroundColor Green
} else {
    Write-Host "   No Terraform state found" -ForegroundColor Red
    Write-Host "   Run 'terraform init' first" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "4. Recommended actions:" -ForegroundColor Blue

if ($LASTEXITCODE -ne 0) {
    Write-Host "   Pipeline is missing. To recreate:" -ForegroundColor Yellow
    Write-Host "   1. Ensure create_cicd_pipeline = true in terraform.dev.tfvars" -ForegroundColor White
    Write-Host "   2. Run: terraform plan -var-file=`"terraform.dev.tfvars`"" -ForegroundColor White
    Write-Host "   3. Run: terraform apply -var-file=`"terraform.dev.tfvars`"" -ForegroundColor White
    Write-Host ""
    Write-Host "   If GitHub connection needs authorization:" -ForegroundColor Yellow
    Write-Host "   4. Run: .\activate-github-connection.ps1 -Environment $Environment" -ForegroundColor White
} else {
    Write-Host "   Pipeline exists and is ready to use!" -ForegroundColor Green
    Write-Host "   Monitor at: https://$Region.console.aws.amazon.com/codesuite/codepipeline/pipelines/$PipelineName/view" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "Pipeline status check complete!" -ForegroundColor Green