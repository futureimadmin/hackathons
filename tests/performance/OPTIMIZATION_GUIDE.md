# Performance Optimization Guide

## Overview

This guide provides recommendations for optimizing the eCommerce AI Analytics Platform based on performance test results.

## Table of Contents

1. [API Gateway Optimization](#api-gateway-optimization)
2. [Lambda Optimization](#lambda-optimization)
3. [Athena Query Optimization](#athena-query-optimization)
4. [Data Pipeline Optimization](#data-pipeline-optimization)
5. [Database Optimization](#database-optimization)
6. [Caching Strategies](#caching-strategies)
7. [Monitoring and Alerts](#monitoring-and-alerts)

---

## API Gateway Optimization

### Current Performance Targets
- Average response time: < 500ms
- P95 response time: < 1000ms
- P99 response time: < 2000ms
- Error rate: < 1%
- Throughput: 1000 RPS

### Optimization Strategies

#### 1. Enable Caching
```terraform
resource "aws_api_gateway_stage" "prod" {
  # ... existing configuration ...
  
  cache_cluster_enabled = true
  cache_cluster_size    = "0.5"  # Start with 0.5GB, scale up if needed
  
  # Cache settings per method
  settings {
    caching_enabled      = true
    cache_ttl_in_seconds = 300  # 5 minutes
    cache_data_encrypted = true
  }
}
```

**Cache Strategy:**
- Cache GET requests for read-heavy endpoints
- Cache TTL: 5 minutes for frequently accessed data
- Invalidate cache on data updates

#### 2. Throttling Configuration
```terraform
resource "aws_api_gateway_method_settings" "all" {
  # ... existing configuration ...
  
  throttling_burst_limit = 5000
  throttling_rate_limit  = 2000
}
```

#### 3. Request/Response Compression
- Enable gzip compression for responses > 1KB
- Reduces bandwidth and improves response times

#### 4. Connection Reuse
- Enable HTTP keep-alive
- Reduces connection overhead

---

## Lambda Optimization

### Current Performance Targets
- Cold start: < 3000ms
- Warm response: < 200ms
- Memory utilization: < 80%
- Timeout rate: < 0.1%

### Optimization Strategies

#### 1. Memory Configuration

**Current Settings:**
- Auth Service: 512 MB
- Analytics Service: 1024 MB
- Market Intelligence: 3072 MB
- Demand Insights: 3072 MB
- Compliance Guardian: 3072 MB
- Retail Copilot: 2048 MB
- Global Market Pulse: 1024 MB

**Optimization:**
```terraform
# Increase memory for CPU-bound operations
resource "aws_lambda_function" "market_intelligence" {
  memory_size = 4096  # Increase from 3072 MB
  timeout     = 300   # 5 minutes
  
  # Enable provisioned concurrency for predictable performance
  reserved_concurrent_executions = 10
}
```

**Memory vs Performance:**
- More memory = More CPU power
- Test with 128 MB increments
- Monitor cost vs performance tradeoff

#### 2. Provisioned Concurrency

**For high-traffic functions:**
```terraform
resource "aws_lambda_provisioned_concurrency_config" "market_intelligence" {
  function_name                     = aws_lambda_function.market_intelligence.function_name
  provisioned_concurrent_executions = 5
  qualifier                         = aws_lambda_alias.prod.name
}
```

**Benefits:**
- Eliminates cold starts
- Predictable performance
- Cost: ~$0.015 per GB-hour

**Recommendation:**
- Enable for: Auth, Analytics, Market Intelligence
- Monitor utilization and adjust

#### 3. Code Optimization

**Python Lambda Best Practices:**

```python
# ❌ Bad: Import inside handler
def lambda_handler(event, context):
    import pandas as pd
    import boto3
    # ... processing ...

# ✅ Good: Import at module level
import pandas as pd
import boto3

# Initialize clients outside handler
s3_client = boto3.client('s3')
athena_client = boto3.client('athena')

def lambda_handler(event, context):
    # ... processing ...
```

**Connection Pooling:**
```python
# Reuse connections across invocations
from botocore.config import Config

config = Config(
    max_pool_connections=50,
    retries={'max_attempts': 3}
)

athena_client = boto3.client('athena', config=config)
```

#### 4. Lambda Layers

**Create shared layers for common dependencies:**
```bash
# Create layer for common libraries
mkdir python
pip install pandas numpy boto3 -t python/
zip -r layer.zip python/
aws lambda publish-layer-version --layer-name common-libs --zip-file fileb://layer.zip
```

**Benefits:**
- Smaller deployment packages
- Faster cold starts
- Shared code across functions

---

## Athena Query Optimization

### Current Performance Targets
- Simple queries: < 2 seconds
- Complex queries: < 15 seconds
- Concurrent queries: 50
- Data scanned: < 1 GB per query

### Optimization Strategies

#### 1. Partitioning

**Implement date-based partitioning:**
```sql
-- Create partitioned table
CREATE EXTERNAL TABLE orders_partitioned (
    order_id STRING,
    customer_id STRING,
    total_amount DECIMAL(10,2),
    status STRING
)
PARTITIONED BY (
    year INT,
    month INT,
    day INT
)
STORED AS PARQUET
LOCATION 's3://ecommerce-ai-platform-prod/orders/';

-- Add partitions
ALTER TABLE orders_partitioned ADD PARTITION (year=2026, month=1, day=16)
LOCATION 's3://ecommerce-ai-platform-prod/orders/year=2026/month=01/day=16/';
```

**Benefits:**
- Reduces data scanned by 90%+
- Faster query execution
- Lower costs

#### 2. Columnar Format (Parquet)

**Already implemented, but ensure:**
- All tables use Parquet format
- Compression enabled (Snappy or ZSTD)
- Proper column ordering (frequently queried columns first)

#### 3. Query Optimization

**Use partition pruning:**
```sql
-- ❌ Bad: Scans all data
SELECT * FROM orders WHERE order_date >= '2026-01-01';

-- ✅ Good: Uses partitions
SELECT * FROM orders_partitioned 
WHERE year = 2026 AND month = 1 AND day >= 1;
```

**Use column projection:**
```sql
-- ❌ Bad: Reads all columns
SELECT * FROM customers WHERE customer_id = 'CUST001';

-- ✅ Good: Reads only needed columns
SELECT customer_id, email, first_name, last_name 
FROM customers WHERE customer_id = 'CUST001';
```

**Use LIMIT for testing:**
```sql
-- Always use LIMIT during development
SELECT * FROM large_table LIMIT 100;
```

#### 4. Workgroup Configuration

```terraform
resource "aws_athena_workgroup" "optimized" {
  name = "${var.project_name}-optimized"
  
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true
    
    result_configuration {
      output_location = "s3://${var.project_name}-athena-results/"
      
      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
    
    # Set query limits
    bytes_scanned_cutoff_per_query = 1073741824  # 1 GB
  }
}
```

#### 5. Query Result Caching

- Athena caches query results for 24 hours
- Reuse cached results when possible
- Implement application-level caching for frequently accessed data

---

## Data Pipeline Optimization

### Current Performance Targets
- DMS lag: < 60 seconds
- Batch processing: < 10 minutes
- Glue crawler: < 5 minutes
- End-to-end: < 30 minutes

### Optimization Strategies

#### 1. DMS Optimization

**Increase replication instance size:**
```terraform
resource "aws_dms_replication_instance" "main" {
  replication_instance_class   = "dms.c5.2xlarge"  # Upgrade from c5.large
  allocated_storage            = 200  # Increase from 100 GB
  multi_az                     = true
  
  # Enable CloudWatch logs
  enable_cloudwatch_logs_exports = ["error", "warning"]
}
```

**Tune task settings:**
```json
{
  "FullLoadSettings": {
    "TargetTablePrepMode": "TRUNCATE_BEFORE_LOAD",
    "MaxFullLoadSubTasks": 8,
    "TransactionConsistencyTimeout": 600
  },
  "ChangeProcessingTuning": {
    "BatchApplyTimeoutMin": 1,
    "BatchApplyTimeoutMax": 30,
    "BatchApplyMemoryLimit": 500,
    "BatchSplitSize": 0,
    "MinTransactionSize": 1000,
    "CommitTimeout": 1,
    "MemoryLimitTotal": 1024,
    "MemoryKeepTime": 60,
    "StatementCacheSize": 50
  }
}
```

#### 2. Batch Job Optimization

**Increase compute resources:**
```terraform
resource "aws_batch_compute_environment" "main" {
  compute_resources {
    type      = "EC2"
    min_vcpus = 4   # Increase from 0
    max_vcpus = 64  # Increase from 16
    
    instance_type = [
      "c5.2xlarge",  # CPU-optimized
      "c5.4xlarge"
    ]
  }
}
```

**Optimize job definitions:**
```terraform
resource "aws_batch_job_definition" "raw_to_curated" {
  container_properties = jsonencode({
    vcpus  = 4   # Increase from 2
    memory = 8192  # Increase from 4096
    
    # Use spot instances for cost savings
    jobRoleArn = aws_iam_role.batch_job.arn
  })
}
```

#### 3. Glue Crawler Optimization

**Optimize crawler configuration:**
```terraform
resource "aws_glue_crawler" "main" {
  # ... existing configuration ...
  
  # Increase DPU for faster crawling
  configuration = jsonencode({
    Version = 1.0
    CrawlerOutput = {
      Partitions = { AddOrUpdateBehavior = "InheritFromTable" }
    }
    Grouping = {
      TableGroupingPolicy = "CombineCompatibleSchemas"
    }
  })
  
  # Schedule during off-peak hours
  schedule = "cron(0 2 * * ? *)"  # 2 AM daily
}
```

#### 4. Parallel Processing

**Process multiple tables in parallel:**
```python
import concurrent.futures

def process_table(table_name):
    # Process single table
    pass

tables = ['customers', 'orders', 'products', 'order_items']

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    executor.map(process_table, tables)
```

---

## Database Optimization

### MySQL Optimization (On-Premise)

#### 1. Indexing

**Add indexes for frequently queried columns:**
```sql
-- Customer lookups
CREATE INDEX idx_customer_email ON customers(email);
CREATE INDEX idx_customer_created ON customers(created_at);

-- Order queries
CREATE INDEX idx_order_customer ON orders(customer_id);
CREATE INDEX idx_order_date ON orders(order_date);
CREATE INDEX idx_order_status ON orders(status);

-- Product searches
CREATE INDEX idx_product_category ON products(category_id);
CREATE INDEX idx_product_name ON products(name);
```

#### 2. Query Optimization

**Use EXPLAIN to analyze queries:**
```sql
EXPLAIN SELECT * FROM orders WHERE customer_id = 'CUST001';
```

**Optimize slow queries:**
```sql
-- ❌ Bad: Full table scan
SELECT * FROM orders WHERE YEAR(order_date) = 2026;

-- ✅ Good: Uses index
SELECT * FROM orders WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01';
```

#### 3. Connection Pooling

**Configure connection pool:**
```ini
[mysqld]
max_connections = 500
thread_cache_size = 100
table_open_cache = 4000
```

### DynamoDB Optimization

#### 1. Capacity Planning

**Use auto-scaling:**
```terraform
resource "aws_appautoscaling_target" "users_table_read" {
  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/${aws_dynamodb_table.users.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "users_table_read_policy" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.users_table_read.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.users_table_read.resource_id
  scalable_dimension = aws_appautoscaling_target.users_table_read.scalable_dimension
  service_namespace  = aws_appautoscaling_target.users_table_read.service_namespace
  
  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}
```

#### 2. Query Optimization

**Use GSI for non-key queries:**
```terraform
resource "aws_dynamodb_table" "users" {
  # ... existing configuration ...
  
  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
    read_capacity   = 5
    write_capacity  = 5
  }
}
```

---

## Caching Strategies

### 1. API Gateway Cache

**Enable for read-heavy endpoints:**
- GET /market-intelligence/trends
- GET /demand-insights/segments
- GET /global-market/regional-prices

**TTL Recommendations:**
- Static data: 1 hour
- Semi-static data: 5 minutes
- Dynamic data: 30 seconds

### 2. Application-Level Cache (Redis/ElastiCache)

**Implement Redis for:**
- User sessions
- Frequently accessed data
- ML model predictions
- Athena query results

**Example configuration:**
```terraform
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-cache"
  engine               = "redis"
  node_type            = "cache.t3.medium"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]
}
```

**Cache patterns:**
```python
import redis
import json

redis_client = redis.Redis(host='cache-endpoint', port=6379, decode_responses=True)

def get_forecast(product_id):
    # Check cache first
    cache_key = f"forecast:{product_id}"
    cached = redis_client.get(cache_key)
    
    if cached:
        return json.loads(cached)
    
    # Generate forecast
    forecast = generate_forecast(product_id)
    
    # Cache for 5 minutes
    redis_client.setex(cache_key, 300, json.dumps(forecast))
    
    return forecast
```

### 3. CloudFront CDN

**For frontend assets:**
```terraform
resource "aws_cloudfront_distribution" "frontend" {
  enabled = true
  
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-${var.project_name}-frontend"
  }
  
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.project_name}-frontend"
    viewer_protocol_policy = "redirect-to-https"
    
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
    
    compress = true
  }
}
```

---

## Monitoring and Alerts

### Key Metrics to Monitor

#### 1. API Gateway
- Request count
- 4xx/5xx error rate
- Latency (avg, p95, p99)
- Cache hit rate

#### 2. Lambda
- Invocations
- Errors
- Duration
- Throttles
- Concurrent executions

#### 3. Athena
- Query execution time
- Data scanned
- Failed queries
- Concurrent queries

#### 4. Data Pipeline
- DMS replication lag
- Batch job duration
- Glue crawler duration
- S3 object count

### CloudWatch Alarms

**Create alarms for:**
```terraform
resource "aws_cloudwatch_metric_alarm" "api_high_latency" {
  alarm_name          = "${var.project_name}-api-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = "1000"  # 1 second
  alarm_description   = "API Gateway latency is too high"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

---

## Performance Testing Results Template

### Test Run: [Date]

#### API Gateway Load Test
- Concurrent Users: 1000
- Duration: 5 minutes
- Total Requests: 300,000
- Success Rate: 99.5%
- Average Response Time: 450ms
- P95 Response Time: 850ms
- P99 Response Time: 1800ms
- Throughput: 1000 RPS

#### Athena Query Performance
| Query Type | Duration | Data Scanned | Status |
|------------|----------|--------------|--------|
| Simple Select | 1.8s | 0.1 GB | ✓ |
| Aggregation | 4.2s | 0.5 GB | ✓ |
| Join Query | 8.5s | 1.2 GB | ⚠ |
| Complex Analytics | 12.3s | 2.1 GB | ⚠ |

#### Lambda Performance
| Function | Avg Duration | Max Duration | Cold Start |
|----------|--------------|--------------|------------|
| Auth | 150ms | 2800ms | 2500ms |
| Analytics | 300ms | 3200ms | 2800ms |
| Market Intelligence | 1200ms | 4500ms | 3500ms |

#### Data Pipeline
- DMS Lag: 45 seconds ✓
- Batch Processing: 8 minutes ✓
- Glue Crawler: 4 minutes ✓
- End-to-End: 25 minutes ✓

### Recommendations
1. Implement API Gateway caching for read-heavy endpoints
2. Increase Lambda memory for Market Intelligence (3GB → 4GB)
3. Optimize Athena join queries with better partitioning
4. Enable provisioned concurrency for Auth Lambda

---

## Cost Optimization

### 1. Right-Sizing
- Monitor actual usage vs provisioned capacity
- Scale down during off-peak hours
- Use spot instances for Batch jobs

### 2. Reserved Capacity
- Purchase reserved capacity for predictable workloads
- Savings: 30-70% vs on-demand

### 3. Data Lifecycle
- Move old data to S3 Glacier
- Delete unnecessary logs after retention period
- Compress data before storage

### 4. Query Optimization
- Reduce data scanned in Athena queries
- Use partitioning and columnar formats
- Implement caching

---

## Next Steps

1. Run baseline performance tests
2. Implement optimizations based on results
3. Re-run tests to measure improvements
4. Document findings and update this guide
5. Set up continuous performance monitoring
6. Schedule regular performance reviews

---

## References

- [AWS Lambda Performance Optimization](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Amazon Athena Performance Tuning](https://docs.aws.amazon.com/athena/latest/ug/performance-tuning.html)
- [API Gateway Caching](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-caching.html)
- [DMS Best Practices](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_BestPractices.html)
