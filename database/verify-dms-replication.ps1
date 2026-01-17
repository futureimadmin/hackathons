# DMS Replication Verification Script
# Verifies that data from MySQL is being replicated to S3 via DMS
# Requirements: 6.6, 6.7

param(
    [string]$Region = "us-east-1",
    [string]$ReplicationTaskArn = "",
    [switch]$Help
)

if ($Help) {
    Write-Host "DMS Replication Verification Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\verify-dms-replication.ps1 -ReplicationTaskArn <arn> [-Region <region>]"
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Yellow
    Write-Host "  -ReplicationTaskArn  : ARN of the DMS replication task (required)"
    Write-Host "  -Region              : AWS region (default: us-east-1)"
    Write-Host "  -Help                : Show this help message"
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Yellow
    Write-Host "  .\verify-dms-replication.ps1 -ReplicationTaskArn arn:aws:dms:us-east-1:123456789012:task:ABCDEFG"
    exit 0
}

Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host ("=" * 59) -ForegroundColor Cyan
Write-Host "DMS Replication Verification" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

# Check if AWS CLI is installed
Write-Host "Checking AWS CLI installation..." -ForegroundColor Yellow
$awsPath = Get-Command aws -ErrorAction SilentlyContinue

if (-not $awsPath) {
    Write-Host "✗ AWS CLI not found" -ForegroundColor Red
    Write-Host "Please install AWS CLI: https://aws.amazon.com/cli/" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ AWS CLI found: $($awsPath.Source)" -ForegroundColor Green
Write-Host ""

# Check AWS credentials
Write-Host "Checking AWS credentials..." -ForegroundColor Yellow
$identity = aws sts get-caller-identity 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ AWS credentials not configured" -ForegroundColor Red
    Write-Host "Please run: aws configure" -ForegroundColor Yellow
    exit 1
}

$identityJson = $identity | ConvertFrom-Json
Write-Host "✓ Authenticated as: $($identityJson.Arn)" -ForegroundColor Green
Write-Host ""

# Get replication task ARN if not provided
if ([string]::IsNullOrWhiteSpace($ReplicationTaskArn)) {
    Write-Host "Fetching DMS replication tasks..." -ForegroundColor Yellow
    $tasks = aws dms describe-replication-tasks --region $Region 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Failed to fetch replication tasks" -ForegroundColor Red
        Write-Host "Error: $tasks" -ForegroundColor Red
        exit 1
    }
    
    $tasksJson = $tasks | ConvertFrom-Json
    
    if ($tasksJson.ReplicationTasks.Count -eq 0) {
        Write-Host "✗ No replication tasks found" -ForegroundColor Red
        Write-Host "Please create a DMS replication task first" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Available replication tasks:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $tasksJson.ReplicationTasks.Count; $i++) {
        $task = $tasksJson.ReplicationTasks[$i]
        Write-Host "  [$i] $($task.ReplicationTaskIdentifier) - Status: $($task.Status)" -ForegroundColor Gray
    }
    
    $selection = Read-Host "Select task number"
    $ReplicationTaskArn = $tasksJson.ReplicationTasks[$selection].ReplicationTaskArn
}

Write-Host ""
Write-Host "Verifying replication task: $ReplicationTaskArn" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check replication task status
Write-Host "1. Checking replication task status..." -ForegroundColor Yellow
$taskStatus = aws dms describe-replication-tasks `
    --filters "Name=replication-task-arn,Values=$ReplicationTaskArn" `
    --region $Region 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to get task status" -ForegroundColor Red
    Write-Host "Error: $taskStatus" -ForegroundColor Red
    exit 1
}

$taskJson = ($taskStatus | ConvertFrom-Json).ReplicationTasks[0]
$status = $taskJson.Status

Write-Host "   Task Status: $status" -ForegroundColor $(if ($status -eq "running") { "Green" } else { "Yellow" })
Write-Host "   Task ID: $($taskJson.ReplicationTaskIdentifier)" -ForegroundColor Gray

if ($status -ne "running") {
    Write-Host "   ⚠ Task is not running. Start the task to begin replication." -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Check replication statistics
Write-Host "2. Checking replication statistics..." -ForegroundColor Yellow
$stats = aws dms describe-table-statistics `
    --replication-task-arn $ReplicationTaskArn `
    --region $Region 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to get replication statistics" -ForegroundColor Red
    Write-Host "Error: $stats" -ForegroundColor Red
} else {
    $statsJson = $stats | ConvertFrom-Json
    $tables = $statsJson.TableStatistics
    
    if ($tables.Count -eq 0) {
        Write-Host "   ⚠ No table statistics available yet" -ForegroundColor Yellow
    } else {
        Write-Host "   Tables being replicated: $($tables.Count)" -ForegroundColor Green
        Write-Host ""
        Write-Host "   Table Statistics:" -ForegroundColor Cyan
        Write-Host "   " + ("-" * 80) -ForegroundColor Gray
        Write-Host "   {0,-30} {1,15} {2,15} {3,15}" -f "Table", "Full Load", "Inserts", "Updates" -ForegroundColor Gray
        Write-Host "   " + ("-" * 80) -ForegroundColor Gray
        
        foreach ($table in $tables) {
            $tableName = "$($table.SchemaName).$($table.TableName)"
            Write-Host "   {0,-30} {1,15} {2,15} {3,15}" -f `
                $tableName, `
                $table.FullLoadRows, `
                $table.Inserts, `
                $table.Updates -ForegroundColor White
        }
        Write-Host "   " + ("-" * 80) -ForegroundColor Gray
    }
}

Write-Host ""

# Step 3: Check S3 buckets for replicated data
Write-Host "3. Checking S3 buckets for replicated data..." -ForegroundColor Yellow

# Get target endpoint to find S3 bucket
$targetEndpoint = $taskJson.TargetEndpointArn
$endpointInfo = aws dms describe-endpoints `
    --filters "Name=endpoint-arn,Values=$targetEndpoint" `
    --region $Region 2>&1

if ($LASTEXITCODE -eq 0) {
    $endpointJson = ($endpointInfo | ConvertFrom-Json).Endpoints[0]
    $s3Settings = $endpointJson.S3Settings
    $bucketName = $s3Settings.BucketName
    
    if ($bucketName) {
        Write-Host "   Target S3 Bucket: $bucketName" -ForegroundColor Cyan
        
        # List objects in bucket
        $objects = aws s3 ls "s3://$bucketName/" --recursive --region $Region 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $objectCount = ($objects | Measure-Object).Count
            Write-Host "   ✓ Found $objectCount objects in S3 bucket" -ForegroundColor Green
            
            if ($objectCount -gt 0) {
                Write-Host ""
                Write-Host "   Sample files (first 10):" -ForegroundColor Cyan
                $objects | Select-Object -First 10 | ForEach-Object {
                    Write-Host "     $_" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "   ⚠ Could not list S3 objects" -ForegroundColor Yellow
        }
    }
}

Write-Host ""

# Step 4: Check for replication errors
Write-Host "4. Checking for replication errors..." -ForegroundColor Yellow
$events = aws dms describe-events `
    --source-identifier $taskJson.ReplicationTaskIdentifier `
    --source-type "replication-task" `
    --duration 60 `
    --region $Region 2>&1

if ($LASTEXITCODE -eq 0) {
    $eventsJson = $events | ConvertFrom-Json
    $errorEvents = $eventsJson.Events | Where-Object { $_.EventCategories -contains "failure" }
    
    if ($errorEvents.Count -eq 0) {
        Write-Host "   ✓ No errors in the last 60 minutes" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Found $($errorEvents.Count) error(s)" -ForegroundColor Red
        foreach ($event in $errorEvents) {
            Write-Host "     - $($event.Message)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "   ⚠ Could not fetch events" -ForegroundColor Yellow
}

Write-Host ""

# Step 5: Verify data in Athena (if available)
Write-Host "5. Checking Athena tables..." -ForegroundColor Yellow
$databases = aws athena list-databases `
    --catalog-name "AwsDataCatalog" `
    --region $Region 2>&1

if ($LASTEXITCODE -eq 0) {
    $dbJson = $databases | ConvertFrom-Json
    $ecommerceDb = $dbJson.DatabaseList | Where-Object { $_.Name -like "*ecommerce*" }
    
    if ($ecommerceDb) {
        Write-Host "   ✓ Found eCommerce database in Athena" -ForegroundColor Green
        
        # List tables
        $tables = aws athena list-table-metadata `
            --catalog-name "AwsDataCatalog" `
            --database-name $ecommerceDb.Name `
            --region $Region 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $tablesJson = $tables | ConvertFrom-Json
            Write-Host "   Tables in Athena: $($tablesJson.TableMetadataList.Count)" -ForegroundColor Green
        }
    } else {
        Write-Host "   ⚠ No eCommerce database found in Athena yet" -ForegroundColor Yellow
        Write-Host "   Run Glue Crawler to catalog the data" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ⚠ Could not check Athena" -ForegroundColor Yellow
}

Write-Host ""

# Summary
Write-Host "=" -NoNewline -ForegroundColor Cyan
Write-Host ("=" * 59) -ForegroundColor Cyan
Write-Host "Verification Summary" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

$allGood = $true

if ($status -eq "running") {
    Write-Host "✓ Replication task is running" -ForegroundColor Green
} else {
    Write-Host "✗ Replication task is not running" -ForegroundColor Red
    $allGood = $false
}

if ($tables.Count -gt 0) {
    Write-Host "✓ Tables are being replicated ($($tables.Count) tables)" -ForegroundColor Green
} else {
    Write-Host "✗ No tables being replicated yet" -ForegroundColor Red
    $allGood = $false
}

if ($objectCount -gt 0) {
    Write-Host "✓ Data found in S3 ($objectCount objects)" -ForegroundColor Green
} else {
    Write-Host "⚠ No data in S3 yet (may take a few minutes)" -ForegroundColor Yellow
}

Write-Host ""

if ($allGood) {
    Write-Host "✓ DMS replication is working correctly!" -ForegroundColor Green
} else {
    Write-Host "⚠ DMS replication needs attention" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Start the replication task if not running:" -ForegroundColor White
    Write-Host "   aws dms start-replication-task --replication-task-arn $ReplicationTaskArn --start-replication-task-type start-replication" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Monitor replication progress:" -ForegroundColor White
    Write-Host "   aws dms describe-table-statistics --replication-task-arn $ReplicationTaskArn" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Check CloudWatch logs for errors:" -ForegroundColor White
    Write-Host "   AWS Console → CloudWatch → Log Groups → /aws/dms/tasks/" -ForegroundColor Gray
}

Write-Host ""
