# AWS Glue and Athena Setup Guide

This guide provides instructions for deploying and configuring AWS Glue and Athena resources for the eCommerce AI Analytics Platform.

## Overview

The Glue and Athena setup creates:

- **5 Glue Databases** - One for each system (Market Intelligence Hub, Demand Insights Engine, etc.)
- **5 Glue Crawlers** - Automatically scan prod buckets and register tables
- **5 Lambda Functions** - Trigger crawlers when new data arrives
- **1 Athena Workgroup** - Centralized query execution with cost controls
- **Sample Named Queries** - Pre-built queries for common analytics tasks

## Prerequisites

Before deploying:

1. ✅ Terraform infrastructure foundation deployed (Task 1)
2. ✅ S3 data lake buckets created (Task 2)
3. ✅ Data processing pipeline operational (Tasks 5-7)
4. ✅ At least one system has data in prod bucket

## Deployment Steps

### Step 1: Package Lambda Functions

Package the Lambda function that triggers Glue Crawlers:

```powershell
cd terraform/modules/glue/lambda
.\package.ps1
```

This creates `trigger_crawler.zip` containing the Lambda function code.

### Step 2: Update Terraform Configuration

Add Glue and Athena modules to your main Terraform configuration:

```hcl
# terraform/main.tf

# Get AWS account ID
data "aws_caller_identity" "current" {}

# Define systems
locals {
  systems = [
    "market-intelligence-hub",
    "demand-insights-engine",
    "compliance-guardian",
    "retail-copilot",
    "global-market-pulse"
  ]
}

# Create Glue resources for each system
module "glue" {
  for_each = toset(local.systems)
  
  source = "./modules/glue"
  
  system_name      = each.value
  database_name    = replace(each.value, "-", "_")
  prod_bucket_name = "${each.value}-prod-${data.aws_caller_identity.current.account_id}"
  
  crawler_role_arn = module.glue_iam.crawler_role_arn
  lambda_role_arn  = module.glue_iam.lambda_role_arn
  lambda_zip_path  = "${path.module}/modules/glue/lambda/trigger_crawler.zip"
  
  crawler_schedule     = "cron(0 */6 * * ? *)"
  enable_lambda_trigger = true
  log_retention_days   = 30
  
  alarm_actions = [] # Add SNS topic ARN if you want notifications
  
  tags = var.tags
}

# Create Athena workgroup
module "athena" {
  source = "./modules/athena"
  
  workgroup_name             = "ecommerce-analytics"
  query_results_bucket_name  = "athena-query-results-${data.aws_caller_identity.current.account_id}"
  query_results_retention_days = 30
  
  bytes_scanned_cutoff       = 10737418240  # 10 GB
  high_cost_threshold_bytes  = 5368709120   # 5 GB
  failure_threshold          = 5
  
  log_retention_days = 30
  sample_database_name = "market_intelligence_hub"
  
  alarm_actions = [] # Add SNS topic ARN if you want notifications
  
  tags = var.tags
}
```

### Step 3: Create IAM Module for Glue

Create a separate IAM module or add to existing IAM configuration:

```hcl
# terraform/modules/glue-iam/main.tf

# IAM Role for Glue Crawler
resource "aws_iam_role" "glue_crawler_role" {
  name = "glue-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_trigger_role" {
  name = "lambda-trigger-crawler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_trigger_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Outputs
output "crawler_role_arn" {
  value = aws_iam_role.glue_crawler_role.arn
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_trigger_role.arn
}
```

### Step 4: Deploy with Terraform

```powershell
cd terraform

# Initialize Terraform (if not already done)
terraform init

# Plan the deployment
terraform plan -out=glue-athena.tfplan

# Review the plan, then apply
terraform apply glue-athena.tfplan
```

### Step 5: Verify Deployment

Check that resources were created:

```powershell
# List Glue databases
aws glue get-databases --region <your-region>

# List Glue crawlers
aws glue list-crawlers --region <your-region>

# List Athena workgroups
aws athena list-work-groups --region <your-region>

# Check Lambda functions
aws lambda list-functions --region <your-region> | Select-String "trigger-crawler"
```

## Post-Deployment Configuration

### Step 1: Run Initial Crawlers

Manually run crawlers for the first time to populate the Glue Catalog:

```powershell
# Run crawler for each system
aws glue start-crawler --name market-intelligence-hub-crawler --region <your-region>
aws glue start-crawler --name demand-insights-engine-crawler --region <your-region>
aws glue start-crawler --name compliance-guardian-crawler --region <your-region>
aws glue start-crawler --name retail-copilot-crawler --region <your-region>
aws glue start-crawler --name global-market-pulse-crawler --region <your-region>
```

### Step 2: Monitor Crawler Execution

Check crawler status:

```powershell
# Get crawler status
aws glue get-crawler --name market-intelligence-hub-crawler --region <your-region>

# Get crawler metrics
aws glue get-crawler-metrics --crawler-name-list market-intelligence-hub-crawler --region <your-region>
```

### Step 3: Verify Tables in Glue Catalog

List tables created by crawlers:

```powershell
# List tables in database
aws glue get-tables --database-name market_intelligence_hub --region <your-region>
```

### Step 4: Test Athena Queries

Run a test query in Athena:

```powershell
# Start query execution
$queryId = aws athena start-query-execution `
  --query-string "SELECT COUNT(*) FROM market_intelligence_hub.ecommerce_orders_prod" `
  --query-execution-context Database=market_intelligence_hub `
  --result-configuration OutputLocation=s3://athena-query-results-<account-id>/ `
  --work-group ecommerce-analytics `
  --region <your-region> `
  --query 'QueryExecutionId' `
  --output text

# Wait for completion
aws athena get-query-execution --query-execution-id $queryId --region <your-region>

# Get results
aws athena get-query-results --query-execution-id $queryId --region <your-region>
```

## Using Athena Named Queries

The deployment creates several named queries for common tasks:

### 1. Sample Orders Query

```sql
-- Retrieves recent completed orders
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

```sql
-- Aggregates daily sales metrics
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

```sql
-- Identifies best-selling products
SELECT 
    p.product_id,
    p.name as product_name,
    COUNT(DISTINCT oi.order_id) as order_count,
    SUM(oi.quantity) as units_sold,
    SUM(oi.total) as total_revenue
FROM market_intelligence_hub.ecommerce_order_items_prod oi
JOIN market_intelligence_hub.ecommerce_products_prod p
    ON oi.product_id = p.product_id
WHERE oi.year = YEAR(CURRENT_DATE)
    AND oi.month = MONTH(CURRENT_DATE)
GROUP BY p.product_id, p.name
ORDER BY total_revenue DESC
LIMIT 20;
```

## Monitoring and Maintenance

### CloudWatch Dashboards

Create a dashboard to monitor Glue and Athena:

1. Navigate to CloudWatch Console
2. Create new dashboard: "eCommerce-Analytics"
3. Add widgets for:
   - Glue Crawler success/failure rate
   - Athena query execution time
   - Athena data scanned
   - Lambda invocations

### CloudWatch Alarms

The deployment creates alarms for:

- **Crawler Failures**: Alerts when crawlers fail
- **High Query Costs**: Alerts when queries scan > 5 GB
- **Query Failures**: Alerts when > 5 queries fail in 5 minutes

Configure SNS notifications:

```hcl
# Add to terraform configuration
resource "aws_sns_topic" "alerts" {
  name = "ecommerce-analytics-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "your-email@example.com"
}

# Update module calls to include alarm_actions
module "glue" {
  # ... other configuration ...
  alarm_actions = [aws_sns_topic.alerts.arn]
}

module "athena" {
  # ... other configuration ...
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

### Regular Maintenance Tasks

1. **Weekly**: Review crawler logs for errors
2. **Weekly**: Check Athena query costs
3. **Monthly**: Review and optimize slow queries
4. **Monthly**: Clean up old query results (automatic via lifecycle policy)
5. **Quarterly**: Review and update named queries

## Troubleshooting

### Crawler Not Finding Tables

**Problem**: Crawler runs but no tables appear in catalog

**Solutions**:
- Verify prod bucket contains Parquet files
- Check crawler S3 path is correct
- Ensure data has valid schema
- Check IAM role permissions
- Review crawler logs in CloudWatch

### Lambda Not Triggering Crawler

**Problem**: New data arrives but crawler doesn't start

**Solutions**:
- Check S3 event notification is configured
- Verify Lambda function has permission to start crawler
- Check Lambda logs in CloudWatch
- Ensure crawler is not already running
- Verify Lambda IAM role has glue:StartCrawler permission

### Athena Query Fails

**Problem**: Queries fail with various errors

**Solutions**:
- **"Table not found"**: Run crawler to register tables
- **"Access Denied"**: Check IAM permissions for S3 and Glue
- **"Query exhausted resources"**: Add partition filters or increase bytes_scanned_cutoff
- **"Invalid schema"**: Check data format and schema consistency

### High Query Costs

**Problem**: Athena costs are higher than expected

**Solutions**:
- Use partitioning in WHERE clauses
- Select specific columns instead of SELECT *
- Use LIMIT to reduce result sets
- Convert data to Parquet format
- Enable result caching
- Review and optimize frequently-run queries

## Cost Optimization

### Athena Pricing

- **Query Cost**: $5 per TB of data scanned
- **Storage Cost**: S3 standard pricing for query results

### Cost Reduction Strategies

1. **Partitioning**: Reduces data scanned by 90%+
   ```sql
   -- Good: Uses partitions
   WHERE year = 2025 AND month = 1
   
   -- Bad: Scans all data
   WHERE order_date >= '2025-01-01'
   ```

2. **Columnar Format**: Parquet reduces scans by 50-80%

3. **Compression**: Snappy compression reduces storage and scan costs

4. **Result Caching**: Reuse results for 24 hours (free)

5. **Bytes Scanned Cutoff**: Prevent runaway queries (configured at 10 GB)

## Next Steps

After completing Glue and Athena setup:

1. ✅ Task 9 complete - Glue and Athena operational
2. ➡️ Task 10 - Implement authentication service (Java Lambda)
3. ➡️ Task 13 - Build React frontend
4. ➡️ Tasks 16-21 - Implement the 5 AI systems

## References

- [AWS Glue Documentation](https://docs.aws.amazon.com/glue/)
- [Amazon Athena Documentation](https://docs.aws.amazon.com/athena/)
- [Glue Crawler Best Practices](https://docs.aws.amazon.com/glue/latest/dg/crawler-best-practices.html)
- [Athena Query Optimization](https://docs.aws.amazon.com/athena/latest/ug/performance-tuning.html)
- [Athena Cost Optimization](https://docs.aws.amazon.com/athena/latest/ug/cost-optimization.html)
