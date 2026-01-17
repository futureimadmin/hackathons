# PowerShell script to verify DMS replication status
# This script checks DMS replication tasks and S3 bucket contents

param(
    [string]$Region = "us-east-1",
    [string]$Environment = "dev",
    [string]$ProjectName = "ecommerce-ai-platform"
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Cyan
}

Write-Info "========================================="
Write-Info "DMS Replication Verification"
Write-Info "========================================="
Write-Host ""

# Check if AWS CLI is installed
try {
    $null = aws --version
} catch {
    Write-ErrorMsg "AWS CLI is not installed. Please install it first."
    exit 1
}

Write-Info "Environment: $Environment"
Write-Info "Region: $Region"
Write-Host ""

# 1. Check DMS Replication Instance
Write-Info "Checking DMS replication instance..."
$instanceId = "$ProjectName-$Environment-replication-instance"

try {
    $instance = aws dms describe-replication-instances `
        --filters "Name=replication-instance-id,Values=$instanceId" `
        --region $Region `
        --output json | ConvertFrom-Json
    
    if ($instance.ReplicationInstances.Count -gt 0) {
        $status = $instance.ReplicationInstances[0].ReplicationInstanceStatus
        Write-Success "✓ Replication instance found: $instanceId"
        Write-Info "  Status: $status"
        
        if ($status -ne "available") {
            Write-Warning "  Instance is not available yet. Current status: $status"
        }
    } else {
        Write-ErrorMsg "✗ Replication instance not found: $instanceId"
        exit 1
    }
} catch {
    Write-ErrorMsg "Failed to check replication instance: $_"
    exit 1
}

Write-Host ""

# 2. Check Source Endpoint
Write-Info "Checking source endpoint..."
$sourceEndpointId = "$ProjectName-$Environment-source-mysql"

try {
    $endpoint = aws dms describe-endpoints `
        --filters "Name=endpoint-id,Values=$sourceEndpointId" `
        --region $Region `
        --output json | ConvertFrom-Json
    
    if ($endpoint.Endpoints.Count -gt 0) {
        $status = $endpoint.Endpoints[0].Status
        Write-Success "✓ Source endpoint found: $sourceEndpointId"
        Write-Info "  Status: $status"
        Write-Info "  Server: $($endpoint.Endpoints[0].ServerName):$($endpoint.Endpoints[0].Port)"
    } else {
        Write-ErrorMsg "✗ Source endpoint not found: $sourceEndpointId"
    }
} catch {
    Write-ErrorMsg "Failed to check source endpoint: $_"
}

Write-Host ""

# 3. Check Target Endpoints
Write-Info "Checking target endpoints..."
$systems = @(
    "market-intelligence-hub",
    "demand-insights-engine",
    "compliance-guardian",
    "retail-copilot",
    "global-market-pulse"
)

foreach ($system in $systems) {
    $targetEndpointId = "$ProjectName-$Environment-target-$system"
    
    try {
        $endpoint = aws dms describe-endpoints `
            --filters "Name=endpoint-id,Values=$targetEndpointId" `
            --region $Region `
            --output json | ConvertFrom-Json
        
        if ($endpoint.Endpoints.Count -gt 0) {
            Write-Success "  ✓ $system"
        } else {
            Write-ErrorMsg "  ✗ $system - endpoint not found"
        }
    } catch {
        Write-ErrorMsg "  ✗ $system - error checking endpoint"
    }
}

Write-Host ""

# 4. Check Replication Tasks
Write-Info "Checking replication tasks..."

foreach ($system in $systems) {
    $taskId = "$ProjectName-$Environment-$system-replication"
    
    try {
        $task = aws dms describe-replication-tasks `
            --filters "Name=replication-task-id,Values=$taskId" `
            --region $Region `
            --output json | ConvertFrom-Json
        
        if ($task.ReplicationTasks.Count -gt 0) {
            $status = $task.ReplicationTasks[0].Status
            $progress = $task.ReplicationTasks[0].ReplicationTaskStats
            
            Write-Success "  ✓ $system"
            Write-Info "    Status: $status"
            
            if ($progress) {
                Write-Info "    Full Load Progress: $($progress.FullLoadProgressPercent)%"
                Write-Info "    Tables Loaded: $($progress.TablesLoaded)"
                Write-Info "    Tables Loading: $($progress.TablesLoading)"
                Write-Info "    Tables Queued: $($progress.TablesQueued)"
                Write-Info "    Tables Errored: $($progress.TablesErrored)"
            }
        } else {
            Write-Warning "  ⚠ $system - task not found (may not be created yet)"
        }
    } catch {
        Write-Warning "  ⚠ $system - error checking task"
    }
}

Write-Host ""

# 5. Check S3 Buckets for Data
Write-Info "Checking S3 buckets for replicated data..."

$accountId = aws sts get-caller-identity --query Account --output text

foreach ($system in $systems) {
    $bucketName = "$system-raw-$accountId"
    
    try {
        # Check if bucket exists
        $null = aws s3api head-bucket --bucket $bucketName --region $Region 2>&1
        
        # List objects in bucket
        $objects = aws s3 ls "s3://$bucketName/" --recursive --region $Region 2>&1
        
        if ($objects) {
            $objectCount = ($objects | Measure-Object).Count
            Write-Success "  ✓ $system - $objectCount objects found"
        } else {
            Write-Warning "  ⚠ $system - bucket exists but no data yet"
        }
    } catch {
        Write-ErrorMsg "  ✗ $system - bucket not accessible"
    }
}

Write-Host ""

# 6. Check CloudWatch Logs
Write-Info "Checking CloudWatch logs..."
$logGroup = "/aws/dms/$ProjectName-$Environment"

try {
    $logs = aws logs describe-log-groups `
        --log-group-name-prefix $logGroup `
        --region $Region `
        --output json | ConvertFrom-Json
    
    if ($logs.logGroups.Count -gt 0) {
        Write-Success "✓ CloudWatch log group found: $logGroup"
        
        # Get recent log streams
        $streams = aws logs describe-log-streams `
            --log-group-name $logGroup `
            --order-by LastEventTime `
            --descending `
            --max-items 5 `
            --region $Region `
            --output json | ConvertFrom-Json
        
        if ($streams.logStreams.Count -gt 0) {
            Write-Info "  Recent log streams:"
            foreach ($stream in $streams.logStreams) {
                Write-Info "    - $($stream.logStreamName)"
            }
        }
    } else {
        Write-Warning "⚠ CloudWatch log group not found"
    }
} catch {
    Write-Warning "⚠ Error checking CloudWatch logs: $_"
}

Write-Host ""

# 7. Test MySQL Connectivity (if possible)
Write-Info "Testing MySQL connectivity..."
Write-Warning "Manual verification required:"
Write-Info "  1. Ensure on-premise MySQL is accessible from AWS VPC"
Write-Info "  2. Verify binary logging is enabled on MySQL"
Write-Info "  3. Check MySQL user has replication permissions"
Write-Info "  4. Test connection from a VPC instance"

Write-Host ""

# Summary
Write-Info "========================================="
Write-Info "Verification Summary"
Write-Info "========================================="
Write-Host ""
Write-Info "Next Steps:"
Write-Info "  1. If replication tasks are not started, start them manually:"
Write-Info "     aws dms start-replication-task --replication-task-arn <arn> --start-replication-task-type start-replication"
Write-Host ""
Write-Info "  2. Monitor replication progress in AWS Console:"
Write-Info "     https://console.aws.amazon.com/dms/v2/home?region=$Region#tasks"
Write-Host ""
Write-Info "  3. Check S3 buckets for data after full load completes"
Write-Host ""
Write-Info "  4. Verify data appears in Athena (after Glue Crawlers run)"
Write-Host ""

Write-Success "Verification script completed!"
