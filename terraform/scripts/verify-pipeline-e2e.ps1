# End-to-End Data Pipeline Verification Script
# This script verifies the complete data pipeline from MySQL to Athena

param(
    [Parameter(Mandatory=$true)]
    [string]$AccountId,
    
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$false)]
    [string]$SystemName = "market-intelligence-hub"
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Data Pipeline E2E Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Account ID: $AccountId" -ForegroundColor Yellow
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "System: $SystemName" -ForegroundColor Yellow
Write-Host ""

$results = @{
    DMS = $false
    S3Raw = $false
    EventBridge = $false
    Batch = $false
    S3Curated = $false
    S3Prod = $false
    GlueCrawler = $false
    Athena = $false
}

# Step 1: Verify DMS Replication
Write-Host "Step 1: Verifying DMS Replication..." -ForegroundColor Cyan
try {
    $dmsTasks = aws dms describe-replication-tasks --region $Region --output json | ConvertFrom-Json
    
    if ($dmsTasks.ReplicationTasks.Count -gt 0) {
        $runningTasks = $dmsTasks.ReplicationTasks | Where-Object { $_.Status -eq "running" }
        
        if ($runningTasks.Count -gt 0) {
            Write-Host "  ✓ DMS replication tasks running: $($runningTasks.Count)" -ForegroundColor Green
            
            foreach ($task in $runningTasks) {
                Write-Host "    - Task: $($task.ReplicationTaskIdentifier)" -ForegroundColor Gray
                Write-Host "      Status: $($task.Status)" -ForegroundColor Gray
            }
            
            $results.DMS = $true
        } else {
            Write-Host "  ✗ No DMS replication tasks in running state" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ No DMS replication tasks found" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error checking DMS: $_" -ForegroundColor Red
}
Write-Host ""

# Step 2: Verify S3 Raw Bucket
Write-Host "Step 2: Verifying S3 Raw Bucket..." -ForegroundColor Cyan
try {
    $rawBucket = "$SystemName-raw-$AccountId"
    $rawObjects = aws s3 ls "s3://$rawBucket/ecommerce/" --recursive --region $Region
    
    if ($rawObjects) {
        $objectCount = ($rawObjects -split "`n").Count
        Write-Host "  ✓ Raw bucket contains data: $objectCount objects" -ForegroundColor Green
        
        # Check for Parquet files
        $parquetFiles = $rawObjects | Select-String -Pattern "\.parquet"
        if ($parquetFiles) {
            Write-Host "  ✓ Parquet files found in raw bucket" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ No Parquet files found in raw bucket" -ForegroundColor Yellow
        }
        
        $results.S3Raw = $true
    } else {
        Write-Host "  ✗ Raw bucket is empty or does not exist" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error checking S3 raw bucket: $_" -ForegroundColor Red
}
Write-Host ""

# Step 3: Verify EventBridge Rules
Write-Host "Step 3: Verifying EventBridge Rules..." -ForegroundColor Cyan
try {
    $rules = aws events list-rules --region $Region --output json | ConvertFrom-Json
    $dataRules = $rules.Rules | Where-Object { $_.Name -like "*raw-to-curated*" -or $_.Name -like "*curated-to-prod*" }
    
    if ($dataRules.Count -gt 0) {
        $enabledRules = $dataRules | Where-Object { $_.State -eq "ENABLED" }
        
        if ($enabledRules.Count -gt 0) {
            Write-Host "  ✓ EventBridge rules enabled: $($enabledRules.Count)" -ForegroundColor Green
            
            foreach ($rule in $enabledRules) {
                Write-Host "    - Rule: $($rule.Name)" -ForegroundColor Gray
                Write-Host "      State: $($rule.State)" -ForegroundColor Gray
            }
            
            $results.EventBridge = $true
        } else {
            Write-Host "  ✗ No enabled EventBridge rules found" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✗ No data pipeline EventBridge rules found" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error checking EventBridge: $_" -ForegroundColor Red
}
Write-Host ""

# Step 4: Verify AWS Batch Jobs
Write-Host "Step 4: Verifying AWS Batch Jobs..." -ForegroundColor Cyan
try {
    # Check for job queue
    $queues = aws batch describe-job-queues --region $Region --output json | ConvertFrom-Json
    
    if ($queues.jobQueues.Count -gt 0) {
        Write-Host "  ✓ Batch job queues found: $($queues.jobQueues.Count)" -ForegroundColor Green
        
        # Check for recent successful jobs
        $jobQueue = $queues.jobQueues[0].jobQueueName
        $succeededJobs = aws batch list-jobs --job-queue $jobQueue --job-status SUCCEEDED --region $Region --output json | ConvertFrom-Json
        
        if ($succeededJobs.jobSummaryList.Count -gt 0) {
            Write-Host "  ✓ Recent successful jobs: $($succeededJobs.jobSummaryList.Count)" -ForegroundColor Green
            $results.Batch = $true
        } else {
            Write-Host "  ⚠ No successful jobs found yet" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✗ No Batch job queues found" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error checking Batch jobs: $_" -ForegroundColor Red
}
Write-Host ""

# Step 5: Verify S3 Curated Bucket
Write-Host "Step 5: Verifying S3 Curated Bucket..." -ForegroundColor Cyan
try {
    $curatedBucket = "$SystemName-curated-$AccountId"
    $curatedObjects = aws s3 ls "s3://$curatedBucket/ecommerce/" --recursive --region $Region
    
    if ($curatedObjects) {
        $objectCount = ($curatedObjects -split "`n").Count
        Write-Host "  ✓ Curated bucket contains data: $objectCount objects" -ForegroundColor Green
        $results.S3Curated = $true
    } else {
        Write-Host "  ⚠ Curated bucket is empty (may be processing)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✗ Error checking S3 curated bucket: $_" -ForegroundColor Red
}
Write-Host ""

# Step 6: Verify S3 Prod Bucket
Write-Host "Step 6: Verifying S3 Prod Bucket..." -ForegroundColor Cyan
try {
    $prodBucket = "$SystemName-prod-$AccountId"
    $prodObjects = aws s3 ls "s3://$prodBucket/ecommerce/" --recursive --region $Region
    
    if ($prodObjects) {
        $objectCount = ($prodObjects -split "`n").Count
        Write-Host "  ✓ Prod bucket contains data: $objectCount objects" -ForegroundColor Green
        
        # Check for partitioned structure
        if ($prodObjects -match "year=") {
            Write-Host "  ✓ Data is partitioned by date" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Data partitioning not detected" -ForegroundColor Yellow
        }
        
        $results.S3Prod = $true
    } else {
        Write-Host "  ⚠ Prod bucket is empty (may be processing)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ✗ Error checking S3 prod bucket: $_" -ForegroundColor Red
}
Write-Host ""

# Step 7: Verify Glue Crawler
Write-Host "Step 7: Verifying Glue Crawler..." -ForegroundColor Cyan
try {
    $crawlerName = "$SystemName-crawler"
    $crawler = aws glue get-crawler --name $crawlerName --region $Region --output json 2>$null | ConvertFrom-Json
    
    if ($crawler.Crawler) {
        Write-Host "  ✓ Glue Crawler exists: $crawlerName" -ForegroundColor Green
        Write-Host "    State: $($crawler.Crawler.State)" -ForegroundColor Gray
        
        if ($crawler.Crawler.LastCrawl) {
            Write-Host "    Last Crawl Status: $($crawler.Crawler.LastCrawl.Status)" -ForegroundColor Gray
        }
        
        # Check for tables in database
        $databaseName = $SystemName.Replace("-", "_")
        $tables = aws glue get-tables --database-name $databaseName --region $Region --output json 2>$null | ConvertFrom-Json
        
        if ($tables.TableList.Count -gt 0) {
            Write-Host "  ✓ Tables registered in Glue Catalog: $($tables.TableList.Count)" -ForegroundColor Green
            
            foreach ($table in $tables.TableList) {
                Write-Host "    - Table: $($table.Name)" -ForegroundColor Gray
            }
            
            $results.GlueCrawler = $true
        } else {
            Write-Host "  ⚠ No tables registered yet (crawler may not have run)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✗ Glue Crawler not found: $crawlerName" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error checking Glue Crawler: $_" -ForegroundColor Red
}
Write-Host ""

# Step 8: Verify Athena Query Capability
Write-Host "Step 8: Verifying Athena Query Capability..." -ForegroundColor Cyan
try {
    $databaseName = $SystemName.Replace("-", "_")
    $queryString = "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = '$databaseName'"
    $outputLocation = "s3://athena-query-results-$AccountId/"
    
    # Start query execution
    $queryExecution = aws athena start-query-execution `
        --query-string $queryString `
        --result-configuration "OutputLocation=$outputLocation" `
        --region $Region `
        --output json 2>$null | ConvertFrom-Json
    
    if ($queryExecution.QueryExecutionId) {
        Write-Host "  ✓ Athena query started: $($queryExecution.QueryExecutionId)" -ForegroundColor Green
        
        # Wait for query to complete (max 30 seconds)
        $maxWait = 30
        $waited = 0
        $queryStatus = "RUNNING"
        
        while ($queryStatus -eq "RUNNING" -and $waited -lt $maxWait) {
            Start-Sleep -Seconds 2
            $waited += 2
            
            $status = aws athena get-query-execution `
                --query-execution-id $queryExecution.QueryExecutionId `
                --region $Region `
                --output json | ConvertFrom-Json
            
            $queryStatus = $status.QueryExecution.Status.State
        }
        
        if ($queryStatus -eq "SUCCEEDED") {
            Write-Host "  ✓ Athena query completed successfully" -ForegroundColor Green
            $results.Athena = $true
        } else {
            Write-Host "  ⚠ Athena query status: $queryStatus" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ✗ Failed to start Athena query" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error testing Athena: $_" -ForegroundColor Red
}
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$passedCount = ($results.Values | Where-Object { $_ -eq $true }).Count
$totalCount = $results.Count
$passPercentage = [math]::Round(($passedCount / $totalCount) * 100, 0)

foreach ($key in $results.Keys) {
    $status = if ($results[$key]) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($results[$key]) { "Green" } else { "Red" }
    Write-Host "$status - $key" -ForegroundColor $color
}

Write-Host ""
Write-Host "Overall: $passedCount/$totalCount checks passed ($passPercentage%)" -ForegroundColor $(if ($passPercentage -ge 80) { "Green" } elseif ($passPercentage -ge 50) { "Yellow" } else { "Red" })
Write-Host ""

if ($passPercentage -eq 100) {
    Write-Host "✓ All verification checks passed! Pipeline is working correctly." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "  1. Mark Task 8 as complete" -ForegroundColor White
    Write-Host "  2. Proceed to Task 9: Set up AWS Glue and Athena" -ForegroundColor White
    Write-Host "  3. Continue with authentication service implementation" -ForegroundColor White
    exit 0
} elseif ($passPercentage -ge 50) {
    Write-Host "⚠ Some verification checks failed. Review the results above." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Cyan
    Write-Host "  - Check CloudWatch Logs for errors" -ForegroundColor White
    Write-Host "  - Verify IAM roles and permissions" -ForegroundColor White
    Write-Host "  - Review PIPELINE_VERIFICATION.md for detailed troubleshooting" -ForegroundColor White
    exit 1
} else {
    Write-Host "✗ Multiple verification checks failed. Pipeline may not be configured correctly." -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Cyan
    Write-Host "  - Verify Terraform deployment completed successfully" -ForegroundColor White
    Write-Host "  - Check that all AWS resources are created" -ForegroundColor White
    Write-Host "  - Review PIPELINE_VERIFICATION.md for detailed troubleshooting" -ForegroundColor White
    exit 1
}
