# Activate GitHub Connection for CodePipeline
# This script helps you complete the GitHub connection authorization

param(
    [string]$Environment = "dev",
    [string]$ProjectName = "futureim-ecommerce-ai-platform",
    [string]$Region = "us-east-2"
)

$ConnectionName = "github-hackathons"

Write-Host "GitHub Connection Activation Helper" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Connection Name: $ConnectionName" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. Checking connection status..." -ForegroundColor Blue
try {
    $connections = aws codestar-connections list-connections --region $Region --query "Connections[?ConnectionName=='$ConnectionName']" --output json 2>$null
    
    if ($connections -and $connections -ne "[]") {
        $connection = $connections | ConvertFrom-Json | Select-Object -First 1
        $connectionArn = $connection.ConnectionArn
        $connectionStatus = $connection.ConnectionStatus
        
        Write-Host "   Connection found:" -ForegroundColor Green
        Write-Host "   ARN: $connectionArn" -ForegroundColor White
        Write-Host "   Status: $connectionStatus" -ForegroundColor White
        
        if ($connectionStatus -eq "AVAILABLE") {
            Write-Host "   Connection is already active!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Your GitHub connection is ready to use." -ForegroundColor Green
            exit 0
        } elseif ($connectionStatus -eq "PENDING") {
            Write-Host "   Connection needs authorization" -ForegroundColor Yellow
        } else {
            Write-Host "   Connection status: $connectionStatus" -ForegroundColor Red
        }
    } else {
        Write-Host "   No connection found with name: $ConnectionName" -ForegroundColor Red
        Write-Host "   Please deploy the infrastructure first" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "   Error checking connection: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "2. Authorization Required" -ForegroundColor Blue
Write-Host "   The GitHub connection needs to be authorized manually in AWS Console" -ForegroundColor Yellow
Write-Host ""

Write-Host "3. Steps to authorize:" -ForegroundColor Blue
Write-Host "   Step 1: Open AWS Console" -ForegroundColor White
Write-Host "   Step 2: Navigate to CodePipeline service" -ForegroundColor White
Write-Host "   Step 3: Go to Settings > Connections" -ForegroundColor White
Write-Host "   Step 4: Find connection: $ConnectionName" -ForegroundColor White
Write-Host "   Step 5: Click 'Update pending connection'" -ForegroundColor White
Write-Host "   Step 6: Authorize with GitHub" -ForegroundColor White
Write-Host "   Step 7: Grant access to repository: futureimadmin/hackathons" -ForegroundColor White
Write-Host ""

Write-Host "4. Direct Links:" -ForegroundColor Blue
$consoleUrl = "https://$Region.console.aws.amazon.com/codesuite/settings/connections"
Write-Host "   AWS Console Connections: $consoleUrl" -ForegroundColor Cyan
Write-Host ""

Write-Host "5. Alternative via CLI:" -ForegroundColor Blue
Write-Host "   You can also check status with:" -ForegroundColor White
Write-Host "   aws codestar-connections get-connection --connection-arn $connectionArn --region $Region" -ForegroundColor Gray
Write-Host ""

# Wait for user to complete authorization
Write-Host "6. Waiting for authorization..." -ForegroundColor Blue
Write-Host "   Press Enter after you've completed the authorization in AWS Console" -ForegroundColor Yellow
Read-Host

# Check status again
Write-Host "7. Verifying authorization..." -ForegroundColor Blue
try {
    $updatedConnection = aws codestar-connections get-connection --connection-arn $connectionArn --region $Region --output json 2>$null | ConvertFrom-Json
    $newStatus = $updatedConnection.Connection.ConnectionStatus
    
    Write-Host "   Updated status: $newStatus" -ForegroundColor White
    
    if ($newStatus -eq "AVAILABLE") {
        Write-Host "   SUCCESS: GitHub connection is now active!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "   - Your CI/CD pipeline is now ready" -ForegroundColor White
        Write-Host "   - Push changes to GitHub to trigger deployments" -ForegroundColor White
        Write-Host "   - Monitor pipeline: https://$Region.console.aws.amazon.com/codesuite/codepipeline/pipelines" -ForegroundColor Cyan
    } else {
        Write-Host "   WARNING: Connection status is still: $newStatus" -ForegroundColor Yellow
        Write-Host "   Please try the authorization process again" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Error checking updated status: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "GitHub connection setup complete!" -ForegroundColor Green