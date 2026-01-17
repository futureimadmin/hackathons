# DMS Replication Verification Guide

## Overview

This guide walks through verifying that AWS DMS is successfully replicating data from the on-premise MySQL database to S3 buckets.

## Prerequisites

- ✅ MySQL database with sample data (Task 14.1-14.3)
- ✅ DMS infrastructure deployed (Task 3)
- ✅ S3 buckets created (Task 2)
- ✅ AWS CLI configured with appropriate credentials

## Verification Steps

### Step 1: Check DMS Replication Task Status

#### Using AWS CLI

```powershell
# List all replication tasks
aws dms describe-replication-tasks --region us-east-1

# Check specific task status
aws dms describe-replication-tasks `
    --filters "Name=replication-task-arn,Values=<your-task-arn>" `
    --region us-east-1
```

#### Using AWS Console

1. Navigate to **AWS DMS Console**
2. Click **Database migration tasks**
3. Find your replication task
4. Check the **Status** column

**Expected Status**: `running` or `replication ongoing`

### Step 2: Start Replication Task (if not running)

```powershell
# Start replication task
aws dms start-replication-task `
    --replication-task-arn <your-task-arn> `
    --start-replication-task-type start-replication `
    --region us-east-1
```

**Replication Types:**
- `start-replication` - Full load + CDC
- `resume-processing` - Resume from where it stopped
- `reload-target` - Reload all tables

### Step 3: Monitor Replication Progress

#### Check Table Statistics

```powershell
aws dms describe-table-statistics `
    --replication-task-arn <your-task-arn> `
    --region us-east-1
```

**Key Metrics:**
- `FullLoadRows` - Rows loaded during full load
- `Inserts` - CDC inserts
- `Updates` - CDC updates
- `Deletes` - CDC deletes
- `TableState` - Current state (Table completed, Table in progress, etc.)

#### Expected Output

```json
{
    "TableStatistics": [
        {
            "SchemaName": "ecommerce_platform",
            "TableName": "customers",
            "Inserts": 10000,
            "Updates": 0,
            "Deletes": 0,
            "FullLoadRows": 10000,
            "TableState": "Table completed"
        },
        {
            "SchemaName": "ecommerce_platform",
            "TableName": "products",
            "Inserts": 5000,
            "Updates": 0,
            "Deletes": 0,
            "FullLoadRows": 5000,
            "TableState": "Table completed"
        }
    ]
}
```

### Step 4: Verify Data in S3

#### List S3 Objects

```powershell
# Get bucket name from DMS target endpoint
aws dms describe-endpoints `
    --filters "Name=endpoint-type,Values=target" `
    --region us-east-1

# List objects in raw bucket
aws s3 ls s3://your-bucket-name/market-intelligence-hub/ecommerce_platform/ --recursive

# Check file count
aws s3 ls s3://your-bucket-name/ --recursive | Measure-Object
```

#### Expected S3 Structure

```
s3://your-bucket-name/
├── market-intelligence-hub/
│   └── ecommerce_platform/
│       ├── customers/
│       │   ├── LOAD00000001.parquet
│       │   └── 20260116-123456789.parquet (CDC)
│       ├── products/
│       │   ├── LOAD00000001.parquet
│       │   └── 20260116-123456790.parquet (CDC)
│       └── orders/
│           ├── LOAD00000001.parquet
│           └── 20260116-123456791.parquet (CDC)
```

#### Download and Inspect Sample File

```powershell
# Download a sample file
aws s3 cp s3://your-bucket-name/market-intelligence-hub/ecommerce_platform/customers/LOAD00000001.parquet ./sample.parquet

# Install parquet-tools (if not installed)
pip install parquet-tools

# View parquet file schema
parquet-tools schema sample.parquet

# View first few rows
parquet-tools head sample.parquet
```

### Step 5: Check for Replication Errors

#### View Recent Events

```powershell
aws dms describe-events `
    --source-identifier <task-identifier> `
    --source-type "replication-task" `
    --duration 60 `
    --region us-east-1
```

#### Check CloudWatch Logs

```powershell
# List log streams
aws logs describe-log-streams `
    --log-group-name "/aws/dms/tasks/<task-id>" `
    --region us-east-1

# Get recent logs
aws logs tail "/aws/dms/tasks/<task-id>" --follow --region us-east-1
```

**Common Error Patterns:**
- Connection timeouts → Check security groups
- Authentication failures → Verify credentials in Secrets Manager
- Table not found → Check table selection rules
- Insufficient permissions → Review IAM roles

### Step 6: Test CDC (Change Data Capture)

#### Insert New Record in MySQL

```sql
USE ecommerce_platform;

INSERT INTO customers (
    customer_id, email, first_name, last_name, 
    phone, city, state, country, customer_segment
) VALUES (
    UUID(), 'test@example.com', 'Test', 'User',
    '555-0100', 'Seattle', 'WA', 'US', 'New'
);
```

#### Wait and Check S3

```powershell
# Wait 5 minutes for CDC to process
Start-Sleep -Seconds 300

# Check for new CDC files
aws s3 ls s3://your-bucket-name/market-intelligence-hub/ecommerce_platform/customers/ --recursive

# Look for files with recent timestamps
```

#### Verify in Athena (after Glue Crawler runs)

```sql
-- Query in Athena
SELECT * FROM ecommerce_db.customers 
WHERE email = 'test@example.com';
```

### Step 7: Verify Data Quality

#### Row Count Comparison

```sql
-- In MySQL
USE ecommerce_platform;
SELECT 
    'customers' as table_name, COUNT(*) as mysql_count FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders;
```

```sql
-- In Athena (after Glue Crawler)
SELECT 
    'customers' as table_name, COUNT(*) as athena_count FROM ecommerce_db.customers
UNION ALL
SELECT 'products', COUNT(*) FROM ecommerce_db.products
UNION ALL
SELECT 'orders', COUNT(*) FROM ecommerce_db.orders;
```

**Expected**: Counts should match (within CDC lag time)

#### Sample Data Comparison

```sql
-- MySQL
SELECT customer_id, email, first_name, last_name 
FROM customers 
ORDER BY created_at DESC 
LIMIT 10;
```

```sql
-- Athena
SELECT customer_id, email, first_name, last_name 
FROM ecommerce_db.customers 
ORDER BY created_at DESC 
LIMIT 10;
```

## Automated Verification Script

Use the provided PowerShell script for automated verification:

```powershell
cd database
.\verify-dms-replication.ps1 -ReplicationTaskArn <your-task-arn>
```

The script will:
1. ✓ Check replication task status
2. ✓ Display table statistics
3. ✓ Verify data in S3
4. ✓ Check for errors
5. ✓ Verify Athena tables

## Troubleshooting

### Issue: Replication Task Stuck in "Starting" State

**Solution:**
```powershell
# Stop the task
aws dms stop-replication-task --replication-task-arn <arn>

# Wait for it to stop
aws dms describe-replication-tasks --filters "Name=replication-task-arn,Values=<arn>"

# Start again
aws dms start-replication-task --replication-task-arn <arn> --start-replication-task-type start-replication
```

### Issue: No Data in S3

**Possible Causes:**
1. Replication task not started
2. Source endpoint connection issues
3. Table selection rules incorrect
4. IAM permissions missing

**Solution:**
```powershell
# Check source endpoint connectivity
aws dms test-connection --replication-instance-arn <instance-arn> --endpoint-arn <source-endpoint-arn>

# Review table selection rules
aws dms describe-replication-tasks --filters "Name=replication-task-arn,Values=<arn>" | jq '.ReplicationTasks[0].TableMappings'

# Check IAM role permissions
aws iam get-role --role-name dms-vpc-role
aws iam get-role --role-name dms-cloudwatch-logs-role
```

### Issue: CDC Not Working

**Symptoms:**
- Initial load completes
- No new files appear after MySQL changes

**Solution:**
```powershell
# Check if CDC is enabled
aws dms describe-replication-tasks --filters "Name=replication-task-arn,Values=<arn>" | jq '.ReplicationTasks[0].MigrationType'

# Should be "full-load-and-cdc" or "cdc"

# Check MySQL binary logging
mysql -u root -p -e "SHOW VARIABLES LIKE 'log_bin';"
# Should be ON

# Check binlog format
mysql -u root -p -e "SHOW VARIABLES LIKE 'binlog_format';"
# Should be ROW
```

### Issue: High Replication Lag

**Symptoms:**
- CDC lag time > 5 minutes
- `CDCLatencySource` metric high

**Solution:**
```powershell
# Increase replication instance size
aws dms modify-replication-instance `
    --replication-instance-arn <arn> `
    --replication-instance-class dms.c5.xlarge `
    --apply-immediately

# Enable parallel load
# Update table mappings to use parallel-load settings

# Check network bandwidth
# Ensure sufficient bandwidth between on-premise and AWS
```

## Performance Metrics

### Key CloudWatch Metrics

Monitor these metrics in CloudWatch:

| Metric | Description | Target |
|--------|-------------|--------|
| `CDCLatencySource` | CDC lag from source | < 60 seconds |
| `CDCLatencyTarget` | CDC lag to target | < 60 seconds |
| `FullLoadThroughputRowsSource` | Rows/sec during full load | > 1000 |
| `NetworkReceiveThroughput` | Network throughput | Stable |
| `CPUUtilization` | Instance CPU usage | < 80% |

### Create CloudWatch Dashboard

```powershell
# Create dashboard for DMS monitoring
aws cloudwatch put-dashboard `
    --dashboard-name "DMS-Replication-Monitor" `
    --dashboard-body file://dms-dashboard.json
```

## Success Criteria

✅ **Task 14.4 is complete when:**

1. ✓ Replication task status is "running"
2. ✓ All tables show "Table completed" state
3. ✓ Data appears in S3 raw buckets
4. ✓ Row counts match between MySQL and S3
5. ✓ CDC is working (new inserts appear in S3 within 5 minutes)
6. ✓ No errors in CloudWatch logs
7. ✓ Glue Crawler can catalog the data
8. ✓ Athena can query the replicated data

## Next Steps

After successful DMS replication verification:

1. ➡️ **Task 15** - Verify end-to-end flow (MySQL → DMS → S3 → Glue → Athena)
2. ➡️ **Task 16** - Implement analytics service (Python Lambda)
3. ➡️ **Tasks 17-21** - Implement the 5 AI systems

## References

- [AWS DMS Documentation](https://docs.aws.amazon.com/dms/)
- [DMS Best Practices](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_BestPractices.html)
- [Monitoring DMS Tasks](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Monitoring.html)
- [Troubleshooting DMS](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Troubleshooting.html)

---

**Task**: 14.4 Verify DMS Replication  
**Requirements**: 6.6, 6.7  
**Dependencies**: Tasks 2, 3, 14.1-14.3  
**Estimated Time**: 30-60 minutes (including wait time for replication)
