# AWS Glue Module

This Terraform module creates AWS Glue resources for the eCommerce AI Analytics Platform, including databases, crawlers, and Lambda triggers.

## Features

- Creates Glue database for each system
- Configures Glue Crawler to scan production S3 buckets
- Sets up Lambda function to trigger crawler on S3 events
- Implements schema change policies (update in database, log deletions)
- Configures CloudWatch logging and alarms
- Schedules crawler to run every 6 hours as backup

## Resources Created

- `aws_glue_catalog_database` - Glue database for storing table metadata
- `aws_glue_crawler` - Crawler to scan S3 and register tables
- `aws_lambda_function` - Function to trigger crawler on S3 events
- `aws_iam_role` - IAM roles for Glue Crawler and Lambda
- `aws_cloudwatch_log_group` - Log groups for crawler and Lambda
- `aws_cloudwatch_metric_alarm` - Alarm for crawler failures
- `aws_s3_bucket_notification` - S3 event notification to Lambda

## Usage

```hcl
module "glue_market_intelligence" {
  source = "./modules/glue"

  system_name       = "market-intelligence-hub"
  database_name     = "market_intelligence_hub"
  prod_bucket_name  = "market-intelligence-hub-prod-123456789012"
  crawler_role_arn  = module.iam.glue_crawler_role_arn
  lambda_role_arn   = module.iam.lambda_trigger_role_arn
  lambda_zip_path   = "${path.module}/modules/glue/lambda/trigger_crawler.zip"
  
  crawler_schedule     = "cron(0 */6 * * ? *)"
  enable_lambda_trigger = true
  log_retention_days   = 30
  
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
| system_name | Name of the system (e.g., market-intelligence-hub) | string | - | yes |
| database_name | Name of the Glue database (underscores instead of hyphens) | string | - | yes |
| prod_bucket_name | Name of the production S3 bucket to crawl | string | - | yes |
| crawler_role_arn | ARN of the IAM role for Glue Crawler | string | - | yes |
| crawler_schedule | Cron expression for crawler schedule | string | "cron(0 */6 * * ? *)" | no |
| enable_lambda_trigger | Enable Lambda function to trigger crawler on S3 events | bool | true | no |
| lambda_role_arn | ARN of the IAM role for Lambda function | string | "" | no |
| lambda_zip_path | Path to Lambda function ZIP file | string | "" | no |
| log_level | Log level for Lambda function | string | "INFO" | no |
| log_retention_days | Number of days to retain CloudWatch logs | number | 30 | no |
| alarm_actions | List of ARNs to notify when alarms trigger | list(string) | [] | no |
| tags | Tags to apply to all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| database_name | Name of the Glue database |
| database_arn | ARN of the Glue database |
| crawler_name | Name of the Glue crawler |
| crawler_arn | ARN of the Glue crawler |
| lambda_function_arn | ARN of the Lambda function that triggers the crawler |
| lambda_function_name | Name of the Lambda function that triggers the crawler |

## Crawler Configuration

### Schema Change Policy

- **Update Behavior**: `UPDATE_IN_DATABASE` - Updates table schema when changes detected
- **Delete Behavior**: `LOG` - Logs deleted tables but doesn't remove from catalog

### Table Grouping Policy

- **Policy**: `CombineCompatibleSchemas` - Combines tables with compatible schemas

### Schedule

- **Default**: Every 6 hours (`cron(0 */6 * * ? *)`)
- **On-Demand**: Triggered by Lambda when new data arrives in prod bucket

## Lambda Trigger

The Lambda function monitors S3 events and triggers the crawler when:

1. New Parquet files are created in the prod bucket
2. Files are in the `ecommerce/` prefix
3. Crawler is in READY state (not already running)

### Lambda Function Logic

```python
# Check crawler state
if crawler_state == 'READY':
    glue_client.start_crawler(Name=CRAWLER_NAME)
else:
    # Skip if already running
    pass
```

## CloudWatch Monitoring

### Log Groups

- `/aws-glue/crawlers/{system-name}-crawler` - Crawler logs
- `/aws/lambda/{system-name}-trigger-crawler` - Lambda logs

### Alarms

- **Crawler Failure Alarm**: Triggers when crawler fails
  - Metric: `glue.driver.aggregate.numFailedTasks`
  - Threshold: > 0
  - Period: 5 minutes

## IAM Permissions

### Glue Crawler Role

- `AWSGlueServiceRole` (managed policy)
- S3 read/write access to prod bucket
- CloudWatch Logs write access

### Lambda Trigger Role

- `AWSLambdaBasicExecutionRole` (managed policy)
- Glue crawler start/get permissions
- S3 read access to prod bucket

## Troubleshooting

### Crawler Not Starting

**Problem**: Crawler doesn't start after S3 event

**Solutions**:
- Check Lambda function logs in CloudWatch
- Verify Lambda has permission to start crawler
- Check crawler state (may already be running)
- Verify S3 event notification is configured

### Tables Not Appearing in Catalog

**Problem**: Crawler runs but tables not registered

**Solutions**:
- Check crawler logs in CloudWatch
- Verify S3 path is correct
- Ensure data is in Parquet format
- Check IAM role permissions
- Verify schema is valid

### Schema Not Updating

**Problem**: Schema changes not reflected in catalog

**Solutions**:
- Check schema change policy is set to UPDATE_IN_DATABASE
- Run crawler manually to force update
- Check crawler logs for errors
- Verify data format is consistent

## Best Practices

1. **Crawler Schedule**: Run every 6 hours as backup, rely on Lambda triggers for real-time updates
2. **Log Retention**: Set appropriate retention (30 days recommended)
3. **Alarms**: Configure SNS notifications for crawler failures
4. **Partitioning**: Ensure data is partitioned by date for optimal query performance
5. **Schema Evolution**: Use UPDATE_IN_DATABASE to handle schema changes gracefully

## Integration with Data Pipeline

The Glue module integrates with the data pipeline:

1. **Curated-to-Prod Job** writes data to prod bucket
2. **S3 Event** triggers Lambda function
3. **Lambda** starts Glue Crawler
4. **Crawler** scans data and registers tables
5. **Athena** queries tables through Glue Catalog

## Example: Creating Glue Resources for All Systems

```hcl
locals {
  systems = [
    "market-intelligence-hub",
    "demand-insights-engine",
    "compliance-guardian",
    "retail-copilot",
    "global-market-pulse"
  ]
}

module "glue" {
  for_each = toset(local.systems)
  
  source = "./modules/glue"
  
  system_name      = each.value
  database_name    = replace(each.value, "-", "_")
  prod_bucket_name = "${each.value}-prod-${data.aws_caller_identity.current.account_id}"
  
  crawler_role_arn = aws_iam_role.glue_crawler_role.arn
  lambda_role_arn  = aws_iam_role.lambda_trigger_role.arn
  lambda_zip_path  = "${path.module}/modules/glue/lambda/trigger_crawler.zip"
  
  tags = var.tags
}
```

## References

- [AWS Glue Documentation](https://docs.aws.amazon.com/glue/)
- [Glue Crawler Documentation](https://docs.aws.amazon.com/glue/latest/dg/add-crawler.html)
- [Glue Data Catalog](https://docs.aws.amazon.com/glue/latest/dg/catalog-and-crawler.html)
