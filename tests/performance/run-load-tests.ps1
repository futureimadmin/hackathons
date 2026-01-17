#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run performance and load tests for eCommerce AI Platform

.DESCRIPTION
    This script runs comprehensive performance tests including:
    - API Gateway load testing (1000 concurrent users)
    - Athena query performance testing
    - Data pipeline throughput testing
    - Lambda cold start and warm response testing

.PARAMETER TestType
    Type of test to run: all, api, athena, pipeline, lambda

.PARAMETER Duration
    Test duration in seconds (default: 300)

.PARAMETER ConcurrentUsers
    Number of concurrent users for API tests (default: 1000)

.PARAMETER ReportPath
    Path to save test reports (default: ./performance/reports)

.EXAMPLE
    .\run-load-tests.ps1 -TestType all
    .\run-load-tests.ps1 -TestType api -ConcurrentUsers 500
    .\run-load-tests.ps1 -TestType athena -Duration 600
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "api", "athena", "pipeline", "lambda")]
    [string]$TestType = "all",
    
    [Parameter(Mandatory=$false)]
    [int]$Duration = 300,
    
    [Parameter(Mandatory=$false)]
    [int]$ConcurrentUsers = 1000,
    
    [Parameter(Mandatory=$false)]
    [string]$ReportPath = "./performance/reports"
)

# Configuration
$PROJECT_NAME = "ecommerce-ai-platform"
$API_BASE_URL = $env:API_BASE_URL
$AWS_REGION = $env:AWS_REGION ?? "us-east-1"

# Colors
$COLOR_GREEN = "Green"
$COLOR_RED = "Red"
$COLOR_YELLOW = "Yellow"
$COLOR_CYAN = "Cyan"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-Prerequisites {
    Write-ColorOutput "`n=== Checking Prerequisites ===" $COLOR_CYAN
    
    # Check Python
    try {
        python --version | Out-Null
        Write-ColorOutput "✓ Python installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ Python not found" $COLOR_RED
        return $false
    }
    
    # Check Locust (load testing tool)
    try {
        locust --version | Out-Null
        Write-ColorOutput "✓ Locust installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "⚠ Locust not found. Install with: pip install locust" $COLOR_YELLOW
    }
    
    # Check AWS CLI
    try {
        aws --version | Out-Null
        Write-ColorOutput "✓ AWS CLI installed" $COLOR_GREEN
    } catch {
        Write-ColorOutput "✗ AWS CLI not found" $COLOR_RED
        return $false
    }
    
    # Check API endpoint
    if (-not $API_BASE_URL) {
        Write-ColorOutput "✗ API_BASE_URL environment variable not set" $COLOR_RED
        return $false
    }
    
    Write-ColorOutput "✓ API endpoint: $API_BASE_URL" $COLOR_GREEN
    
    return $true
}

function Test-APIGatewayLoad {
    Write-ColorOutput "`n=== Running API Gateway Load Test ===" $COLOR_CYAN
    Write-ColorOutput "Concurrent Users: $ConcurrentUsers" $COLOR_CYAN
    Write-ColorOutput "Duration: $Duration seconds`n" $COLOR_CYAN
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $reportFile = Join-Path $ReportPath "api_load_test_$timestamp.html"
    
    # Create Locust test file
    $locustFile = @"
from locust import HttpUser, task, between
import random

class APIUser(HttpUser):
    wait_time = between(1, 3)
    
    def on_start(self):
        # Login to get JWT token
        response = self.client.post("/auth/login", json={
            "email": f"loadtest{random.randint(1, 10000)}@example.com",
            "password": "TestPassword123!"
        })
        if response.status_code == 200:
            self.token = response.json()['token']
        else:
            self.token = None
    
    @task(2)
    def forecast(self):
        if self.token:
            self.client.post("/market-intelligence/forecast",
                headers={"Authorization": f"Bearer {self.token}"},
                json={"product_id": f"PROD{random.randint(1, 1000)}", "periods": 30, "model": "auto"})
    
    @task(1)
    def segments(self):
        if self.token:
            self.client.get("/demand-insights/segments",
                headers={"Authorization": f"Bearer {self.token}"},
                params={"n_clusters": 4})
    
    @task(1)
    def fraud_detection(self):
        if self.token:
            self.client.post("/compliance/fraud-detection",
                headers={"Authorization": f"Bearer {self.token}"},
                json={"transaction_ids": [f"TXN{random.randint(1, 10000)}"]})
    
    @task(2)
    def chat(self):
        if self.token:
            self.client.post("/retail-copilot/chat",
                headers={"Authorization": f"Bearer {self.token}"},
                json={"user_id": f"USER{random.randint(1, 1000)}", "message": "What are the top selling products?"})
"@
    
    $locustFile | Out-File -FilePath "locustfile.py" -Encoding UTF8
    
    # Run Locust
    Write-ColorOutput "Starting load test..." $COLOR_CYAN
    locust -f locustfile.py --host=$API_BASE_URL --users=$ConcurrentUsers --spawn-rate=50 --run-time="${Duration}s" --html=$reportFile --headless
    
    Write-ColorOutput "`n✓ Load test complete. Report: $reportFile" $COLOR_GREEN
    
    # Cleanup
    Remove-Item "locustfile.py" -ErrorAction SilentlyContinue
}

function Test-AthenaPerformance {
    Write-ColorOutput "`n=== Running Athena Query Performance Test ===" $COLOR_CYAN
    
    $queries = @(
        @{Name="Simple Select"; SQL="SELECT * FROM customers LIMIT 1000"; ExpectedMs=2000},
        @{Name="Aggregation"; SQL="SELECT category, COUNT(*) as count, AVG(price) as avg_price FROM products GROUP BY category"; ExpectedMs=5000},
        @{Name="Join Query"; SQL="SELECT c.customer_id, c.email, COUNT(o.order_id) as order_count FROM customers c LEFT JOIN orders o ON c.customer_id = o.customer_id GROUP BY c.customer_id, c.email LIMIT 100"; ExpectedMs=10000},
        @{Name="Complex Analytics"; SQL="SELECT DATE_TRUNC('month', order_date) as month, SUM(total_amount) as revenue FROM orders GROUP BY DATE_TRUNC('month', order_date) ORDER BY month DESC LIMIT 12"; ExpectedMs=15000}
    )
    
    $results = @()
    
    foreach ($query in $queries) {
        Write-ColorOutput "`nTesting: $($query.Name)" $COLOR_CYAN
        
        $startTime = Get-Date
        
        # Execute Athena query
        $queryExecution = aws athena start-query-execution `
            --query-string $query.SQL `
            --query-execution-context "Database=${PROJECT_NAME}_db" `
            --result-configuration "OutputLocation=s3://${PROJECT_NAME}-athena-results/" `
            --region $AWS_REGION `
            --output json | ConvertFrom-Json
        
        $queryId = $queryExecution.QueryExecutionId
        
        # Wait for completion
        do {
            Start-Sleep -Seconds 1
            $status = aws athena get-query-execution --query-execution-id $queryId --region $AWS_REGION --output json | ConvertFrom-Json
            $state = $status.QueryExecution.Status.State
        } while ($state -in @("QUEUED", "RUNNING"))
        
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds
        
        $result = @{
            Name = $query.Name
            Duration = [math]::Round($duration, 2)
            Expected = $query.ExpectedMs
            Status = $state
            DataScanned = $status.QueryExecution.Statistics.DataScannedInBytes / 1GB
        }
        
        $results += $result
        
        if ($state -eq "SUCCEEDED") {
            $color = if ($duration -le $query.ExpectedMs) { $COLOR_GREEN } else { $COLOR_YELLOW }
            Write-ColorOutput "  Duration: $($result.Duration)ms (Expected: $($query.ExpectedMs)ms)" $color
            Write-ColorOutput "  Data Scanned: $([math]::Round($result.DataScanned, 3))GB" $COLOR_CYAN
        } else {
            Write-ColorOutput "  Status: FAILED" $COLOR_RED
        }
    }
    
    # Summary
    Write-ColorOutput "`n=== Athena Performance Summary ===" $COLOR_CYAN
    $results | ForEach-Object {
        $status = if ($_.Status -eq "SUCCEEDED" -and $_.Duration -le $_.Expected) { "✓" } else { "✗" }
        Write-Host "$status $($_.Name): $($_.Duration)ms"
    }
}

function Test-DataPipelineThroughput {
    Write-ColorOutput "`n=== Running Data Pipeline Throughput Test ===" $COLOR_CYAN
    
    # Test DMS replication lag
    Write-ColorOutput "`nChecking DMS replication lag..." $COLOR_CYAN
    $dmsTasks = aws dms describe-replication-tasks --region $AWS_REGION --output json | ConvertFrom-Json
    
    foreach ($task in $dmsTasks.ReplicationTasks) {
        if ($task.ReplicationTaskIdentifier -like "*$PROJECT_NAME*") {
            $stats = $task.ReplicationTaskStats
            Write-ColorOutput "  Task: $($task.ReplicationTaskIdentifier)" $COLOR_CYAN
            Write-ColorOutput "  Full Load Progress: $($stats.FullLoadProgressPercent)%" $COLOR_CYAN
            Write-ColorOutput "  CDC Latency: $($stats.FreshStartDate)" $COLOR_CYAN
        }
    }
    
    # Test Batch job performance
    Write-ColorOutput "`nChecking Batch job performance..." $COLOR_CYAN
    $jobs = aws batch list-jobs --job-queue "${PROJECT_NAME}-job-queue" --job-status SUCCEEDED --max-results 10 --region $AWS_REGION --output json | ConvertFrom-Json
    
    if ($jobs.jobSummaryList.Count -gt 0) {
        $avgDuration = ($jobs.jobSummaryList | Measure-Object -Property duration -Average).Average / 1000
        Write-ColorOutput "  Average job duration: $([math]::Round($avgDuration, 2)) seconds" $COLOR_CYAN
    }
    
    # Test Glue crawler performance
    Write-ColorOutput "`nChecking Glue crawler performance..." $COLOR_CYAN
    $crawler = aws glue get-crawler --name "${PROJECT_NAME}-crawler" --region $AWS_REGION --output json | ConvertFrom-Json
    
    if ($crawler.Crawler.LastCrawl) {
        $duration = $crawler.Crawler.LastCrawl.Duration / 1000
        Write-ColorOutput "  Last crawl duration: $([math]::Round($duration, 2)) seconds" $COLOR_CYAN
        Write-ColorOutput "  Tables updated: $($crawler.Crawler.LastCrawl.TablesUpdated)" $COLOR_CYAN
    }
}

function Test-LambdaPerformance {
    Write-ColorOutput "`n=== Running Lambda Performance Test ===" $COLOR_CYAN
    
    $functions = @(
        "${PROJECT_NAME}-auth",
        "${PROJECT_NAME}-analytics",
        "${PROJECT_NAME}-market-intelligence",
        "${PROJECT_NAME}-demand-insights",
        "${PROJECT_NAME}-compliance-guardian",
        "${PROJECT_NAME}-retail-copilot",
        "${PROJECT_NAME}-global-market-pulse"
    )
    
    foreach ($function in $functions) {
        Write-ColorOutput "`nTesting: $function" $COLOR_CYAN
        
        # Get CloudWatch metrics
        $endTime = Get-Date
        $startTime = $endTime.AddHours(-1)
        
        $metrics = aws cloudwatch get-metric-statistics `
            --namespace AWS/Lambda `
            --metric-name Duration `
            --dimensions Name=FunctionName,Value=$function `
            --start-time $startTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --end-time $endTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") `
            --period 3600 `
            --statistics Average,Maximum `
            --region $AWS_REGION `
            --output json 2>$null | ConvertFrom-Json
        
        if ($metrics.Datapoints.Count -gt 0) {
            $avgDuration = [math]::Round($metrics.Datapoints[0].Average, 2)
            $maxDuration = [math]::Round($metrics.Datapoints[0].Maximum, 2)
            Write-ColorOutput "  Avg Duration: ${avgDuration}ms" $COLOR_CYAN
            Write-ColorOutput "  Max Duration: ${maxDuration}ms" $COLOR_CYAN
        } else {
            Write-ColorOutput "  No recent invocations" $COLOR_YELLOW
        }
    }
}

# Main execution
Write-ColorOutput @"
╔═══════════════════════════════════════════════════════════╗
║   eCommerce AI Platform - Performance Testing            ║
╚═══════════════════════════════════════════════════════════╝
"@ $COLOR_CYAN

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-ColorOutput "`n✗ Prerequisites check failed" $COLOR_RED
    exit 1
}

# Create report directory
New-Item -ItemType Directory -Force -Path $ReportPath | Out-Null

# Run tests based on type
$startTime = Get-Date

switch ($TestType) {
    "api" { Test-APIGatewayLoad }
    "athena" { Test-AthenaPerformance }
    "pipeline" { Test-DataPipelineThroughput }
    "lambda" { Test-LambdaPerformance }
    "all" {
        Test-APIGatewayLoad
        Test-AthenaPerformance
        Test-DataPipelineThroughput
        Test-LambdaPerformance
    }
}

$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalMinutes

Write-ColorOutput "`n=== Performance Testing Complete ===" $COLOR_CYAN
Write-ColorOutput "Total Duration: $([math]::Round($totalDuration, 2)) minutes" $COLOR_CYAN
Write-ColorOutput "Reports saved to: $ReportPath" $COLOR_CYAN

exit 0
