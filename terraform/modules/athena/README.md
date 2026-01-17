# AWS Athena Module

This Terraform module creates AWS Athena resources for the eCommerce AI Analytics Platform, including workgroups, query result storage, and sample queries.

## Features

- Creates Athena workgroup with optimized configuration
- Sets up S3 bucket for query results with encryption and lifecycle policies
- Configures cost controls (bytes scanned cutoff)
- Enables CloudWatch metrics and logging
- Creates CloudWatch alarms for high costs and failures
- Provides sample named queries for common analytics tasks

## Resources Created

- `aws_athena_workgroup` - Workgroup for analytics queries
- `aws_s3_bucket` - Bucket for storing query results
- `aws_s3_bucket_versioning` - Versioning for query results
- `aws_s3_bucket_server_side_encryption_configuration` - Encryption for query results
- `aws_s3_bucket_lifecycle_configuration` - Lifecycle policy to delete old results
- `aws_cloudwatch_log_group` - Log group for Athena queries
- `aws_cloudwatch_metric_alarm` - Alarms for high costs and failures
- `aws_athena_named_query` - Sample queries for common tasks

## Usage

```hcl
module "athena" {
  source = "./modules/athena"

  workgroup_name             = "ecommerce-analytics"
  query_results_bucket_name  = "athena-query-results-123456789012"
  query_results_retention_days = 30
  
  bytes_scanned_cutoff       = 10737418240  # 10 GB
  high_cost_threshold_bytes  = 5368709120   # 5 GB
  failure_threshold          = 5
  
  log_retention_days = 30
  sample_database_name = "market_intelligence_hub"
  
  alarm_actions = [aws_sns_topic.alerts.arn]
  
  tags = {
    Environment = "production"
    Project     = "ecommerce-ai-platform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| workgroup_name | Name of the Athena workgroup | string | "ecommerce-analytics" | no |
| query_results_bucket_name | Name of the S3 bucket for Athena query results | string | - | yes |
| query_results_retention_days | Number of days to retain query results in S3 | number | 30 | no |
| bytes_scanned_cutoff | Maximum bytes scanned per query | number | 10737418240 (10 GB) | no |
| high_cost_threshold_bytes | Threshold for high query cost alarm | number | 5368709120 (5 GB) | no |
| failure_threshold | Threshold for query failure alarm | number | 5 | no |
| log_retention_days | Number of days to retain CloudWatch logs | number | 30 | no |
| sample_database_name | Name of a sample Glue database for named queries | string | "market_intelligence_hub" | no |
| alarm_actions | List of ARNs to notify when alarms trigger | list(string) | [] | no |
| tags | Tags to apply to all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| workgroup_name | Name of the Athena workgroup |
| workgroup_arn | ARN of the Athena workgroup |
| workgroup_id | ID of the Athena workgroup |
| query_results_bucket | Name of the S3 bucket for query results |
| query_results_bucket_arn | ARN of the S3 bucket for query results |
| named_queries | Map of named query names to their IDs |

## Workgroup Configuration

### Query Result Location

- **S3 Bucket**: Dedicated bucket for query results
- **Encryption**: SSE-S3 (AES-256)
- **Lifecycle**: Results deleted after 30 days (configurable)

### Cost Controls

- **Bytes Scanned Cutoff**: 10 GB per query (default)
- **Enforced**: Yes - queries exceeding limit will fail
- **Purpose**: Prevent accidentally expensive queries

### CloudWatch Metrics

- **Enabled**: Yes
- **Metrics**: Query execution time, data scanned, failed queries
- **Namespace**: `AWS/Athena`

### Engine Version

- **Version**: AUTO (latest stable version)
- **Updates**: Automatic

## Named Queries

The module creates several sample named queries:

### 1. Sample Orders Query

Retrieves recent completed orders for the current month.

```sql
SELECT 
    order_id,
    customer_id,
    order_total,
    order_date,
    order_status
FROM market_intelligence_hub.ecommerce_orders_prod
WHERE year = YEAR(CURRENT_DATE)
    AND month = MONTH(CURRENT_DATE)
    AND order_status = 'completed'
ORDER BY order_date DESC
LIMIT 100;
```

### 2. Daily Sales Summary

Aggregates daily sales metrics.

```sql
SELECT 
    DATE(order_date) as sale_date,
    COUNT(DISTINCT order_id) as order_count,
    COUNT(DISTINCT customer_id) as customer_count,
    SUM(order_total) as total_revenue,
    AVG(order_total) as avg_order_value
FROM market_intelligence_hub.ecommerce_orders_prod
WHERE year = YEAR(CURRENT_DATE)
    AND month = MONTH(CURRENT_DATE)
GROUP BY DATE(order_date)
ORDER BY sale_date DESC;
```

### 3. Top Products by Revenue

Identifies best-selling products.

```sql
SELECT 
    p.product_id,
    p.name as product_name,
    p.category_id,
    COUNT(DISTINCT oi.order_id) as order_count,
    SUM(oi.quantity) as units_sold,
    SUM(oi.total) as total_revenue
FROM market_intelligence_hub.ecommerce_order_items_prod oi
JOIN market_intelligence_hub.ecommerce_products_prod p
    ON oi.product_id = p.product_id
WHERE oi.year = YEAR(CURRENT_DATE)
    AND oi.month = MONTH(CURRENT_DATE)
GROUP BY p.product_id, p.name, p.category_id
ORDER BY total_revenue DESC
LIMIT 20;
```

### 4. Customer Lifetime Value

Calculates CLV for repeat customers.

```sql
SELECT 
    customer_id,
    COUNT(DISTINCT order_id) as total_orders,
    SUM(order_total) as lifetime_value,
    AVG(order_total) as avg_order_value,
    MIN(order_date) as first_order_date,
    MAX(order_date) as last_order_date,
    DATE_DIFF('day', MIN(order_date), MAX(order_date)) as customer_age_days
FROM market_intelligence_hub.ecommerce_orders_prod
WHERE order_status IN ('completed', 'delivered')
GROUP BY customer_id
HAVING COUNT(DISTINCT order_id) > 1
ORDER BY lifetime_value DESC
LIMIT 100;
```

## CloudWatch Monitoring

### Log Groups

- `/aws/athena/ecommerce-analytics` - Query execution logs

### Alarms

1. **High Query Cost Alarm**
   - Metric: `DataScannedInBytes`
   - Threshold: 5 GB (default)
   - Period: 5 minutes
   - Purpose: Alert on expensive queries

2. **Query Failure Alarm**
   - Metric: `FailedQueries`
   - Threshold: 5 failures (default)
   - Period: 5 minutes
   - Purpose: Alert on query errors

## Query Optimization Best Practices

### 1. Use Partitioning

Always include partition columns in WHERE clause:

```sql
-- Good: Uses partitions
SELECT * FROM orders_prod
WHERE year = 2025 AND month = 1 AND day = 16;

-- Bad: Scans all data
SELECT * FROM orders_prod
WHERE order_date = '2025-01-16';
```

### 2. Limit Result Sets

Use LIMIT to reduce data scanned:

```sql
SELECT * FROM orders_prod
WHERE year = 2025
LIMIT 1000;
```

### 3. Select Specific Columns

Avoid SELECT *:

```sql
-- Good: Only needed columns
SELECT order_id, customer_id, total FROM orders_prod;

-- Bad: All columns
SELECT * FROM orders_prod;
```

### 4. Use Columnar Format

Parquet format allows column pruning:

- Only requested columns are read
- Significantly reduces data scanned
- Improves query performance

### 5. Use CTAS for Complex Queries

Create Table As Select for reusable results:

```sql
CREATE TABLE daily_summary AS
SELECT 
    DATE(order_date) as sale_date,
    SUM(order_total) as revenue
FROM orders_prod
WHERE year = 2025
GROUP BY DATE(order_date);
```

## Cost Optimization

### Query Cost Calculation

- **Cost**: $5 per TB scanned
- **Example**: 10 GB query = $0.05

### Cost Reduction Strategies

1. **Partitioning**: Reduces data scanned by 90%+
2. **Columnar Format**: Reduces data scanned by 50-80%
3. **Compression**: Reduces storage and scan costs
4. **Result Caching**: Reuse results for 24 hours
5. **Bytes Scanned Cutoff**: Prevent runaway queries

## Troubleshooting

### Query Exceeds Bytes Scanned Cutoff

**Problem**: Query fails with "Query exhausted resources"

**Solutions**:
- Add partition filters to WHERE clause
- Select fewer columns
- Reduce date range
- Increase bytes_scanned_cutoff if necessary

### Query Results Not Found

**Problem**: Cannot access query results

**Solutions**:
- Check S3 bucket permissions
- Verify workgroup configuration
- Check lifecycle policy hasn't deleted results

### Slow Query Performance

**Problem**: Queries take too long to execute

**Solutions**:
- Use partitioning in WHERE clause
- Optimize table structure
- Use CTAS for complex queries
- Check data format (should be Parquet)

## Integration with Analytics Services

The Athena module integrates with analytics services:

1. **Python Lambda** queries Athena using boto3
2. **Workgroup** enforces cost controls and logging
3. **Named Queries** provide templates for common tasks
4. **CloudWatch** monitors query performance and costs

## Example: Querying from Python

```python
import boto3

athena_client = boto3.client('athena')

# Start query execution
response = athena_client.start_query_execution(
    QueryString='SELECT COUNT(*) FROM market_intelligence_hub.ecommerce_orders_prod WHERE year=2025',
    QueryExecutionContext={'Database': 'market_intelligence_hub'},
    ResultConfiguration={
        'OutputLocation': 's3://athena-query-results-123456789012/'
    },
    WorkGroup='ecommerce-analytics'
)

query_execution_id = response['QueryExecutionId']

# Wait for completion and get results
# ... (see analytics service implementation)
```

## References

- [Amazon Athena Documentation](https://docs.aws.amazon.com/athena/)
- [Athena Query Optimization](https://docs.aws.amazon.com/athena/latest/ug/performance-tuning.html)
- [Athena Cost Optimization](https://docs.aws.amazon.com/athena/latest/ug/cost-optimization.html)
- [Athena Workgroups](https://docs.aws.amazon.com/athena/latest/ug/workgroups.html)
