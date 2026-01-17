# Monitoring Module

## Overview

This Terraform module implements comprehensive monitoring and logging for the eCommerce AI Analytics Platform. It includes CloudWatch dashboards, alarms, centralized logging, and CloudTrail audit logging.

## Features

### CloudWatch Dashboards

1. **Data Pipeline Dashboard**
   - DMS replication metrics (throughput, latency)
   - Batch job metrics (running, submitted, failed, succeeded)
   - Glue Crawler metrics (completed/failed tasks)
   - Recent Batch job errors

2. **API Performance Dashboard**
   - API Gateway request metrics (count, 4xx, 5xx errors)
   - API Gateway latency (total and integration)
   - Lambda function metrics (invocations, errors, throttles, duration)
   - Recent Lambda errors

3. **ML Model Performance Dashboard**
   - Market Intelligence Hub metrics (forecast accuracy, training time, latency)
   - Demand Insights Engine metrics (segmentation quality, CLV/churn accuracy)
   - Compliance Guardian metrics (fraud detection rate, high-risk transactions, PCI violations)
   - Retail Copilot metrics (response time, SQL generation success, conversation count)
   - Global Market Pulse metrics (trend accuracy, opportunity scores, analysis time)

### CloudWatch Alarms

1. **DMS Replication Lag** - Triggers when replication lag exceeds 5 minutes
2. **Lambda Errors** - Triggers when Lambda errors exceed 10 in 5 minutes
3. **API Gateway 5xx Errors** - Triggers when 5xx errors exceed 5 in 5 minutes
4. **Batch Job Failures** - Triggers when any Batch job fails

### Centralized Logging

- **Lambda Logs**: Separate log groups for each Lambda function
- **Batch Logs**: Centralized log group for all Batch jobs
- **API Gateway Logs**: Log group for API Gateway access logs
- **CloudTrail Logs**: Log group for CloudTrail events

All log groups have:
- Configurable retention (default: 30 days)
- KMS encryption
- Proper tagging

### CloudTrail Audit Logging

- Multi-region trail enabled
- Log file validation enabled
- Tracks all management events
- Tracks S3 data events (data lake bucket)
- Tracks Lambda function invocations
- Logs stored in encrypted S3 bucket
- Logs streamed to CloudWatch Logs

## Usage

```hcl
module "monitoring" {
  source = "./modules/monitoring"

  project_name          = "ecommerce-ai-platform"
  environment           = "prod"
  aws_region            = "us-east-1"
  kms_key_id            = module.kms.key_id
  data_lake_bucket_arn  = module.s3_data_lake.bucket_arn
  log_retention_days    = 30
  alert_emails          = ["ops@example.com", "devops@example.com"]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Name of the project | string | - | yes |
| environment | Environment (dev, staging, prod) | string | "prod" | no |
| aws_region | AWS region | string | - | yes |
| kms_key_id | KMS key ID for encryption | string | - | yes |
| data_lake_bucket_arn | ARN of the data lake S3 bucket | string | - | yes |
| log_retention_days | Number of days to retain logs | number | 30 | no |
| alert_emails | List of email addresses for alerts | list(string) | [] | no |

## Outputs

| Name | Description |
|------|-------------|
| data_pipeline_dashboard_arn | ARN of the data pipeline CloudWatch dashboard |
| api_performance_dashboard_arn | ARN of the API performance CloudWatch dashboard |
| ml_performance_dashboard_arn | ARN of the ML performance CloudWatch dashboard |
| sns_topic_arn | ARN of the SNS topic for alerts |
| cloudtrail_arn | ARN of the CloudTrail |
| cloudtrail_bucket_name | Name of the S3 bucket for CloudTrail logs |
| log_group_names | Names of CloudWatch log groups |
| alarm_arns | ARNs of CloudWatch alarms |

## Dashboards

### Accessing Dashboards

1. Navigate to CloudWatch in AWS Console
2. Select "Dashboards" from the left menu
3. Find dashboards:
   - `ecommerce-ai-platform-data-pipeline`
   - `ecommerce-ai-platform-api-performance`
   - `ecommerce-ai-platform-ml-performance`

### Dashboard Widgets

Each dashboard contains multiple widgets showing:
- Time series metrics
- Log insights queries
- Aggregated statistics
- Real-time data (5-minute intervals)

## Alarms

### Alarm Actions

All alarms send notifications to the SNS topic, which forwards to configured email addresses.

### Alarm States

- **OK**: Metric is within threshold
- **ALARM**: Metric has breached threshold
- **INSUFFICIENT_DATA**: Not enough data to evaluate

### Customizing Alarms

Modify thresholds in `main.tf`:

```hcl
resource "aws_cloudwatch_metric_alarm" "dms_replication_lag" {
  threshold = 300000 # Change this value (milliseconds)
  # ...
}
```

## Logging

### Log Retention

Default retention: 30 days

To change retention:

```hcl
module "monitoring" {
  # ...
  log_retention_days = 90 # 90 days
}
```

### Log Encryption

All logs are encrypted using the provided KMS key.

### Querying Logs

Use CloudWatch Logs Insights:

```sql
-- Find Lambda errors
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20

-- Find slow API requests
fields @timestamp, @message
| filter @message like /latency/
| parse @message /latency: (?<latency>\d+)/
| filter latency > 1000
| sort @timestamp desc
```

## CloudTrail

### What's Tracked

- All management events (API calls)
- S3 data events (data lake bucket)
- Lambda function invocations
- IAM actions
- Resource creation/modification/deletion

### Accessing CloudTrail Logs

1. **S3 Bucket**: `ecommerce-ai-platform-cloudtrail-logs-<account-id>`
2. **CloudWatch Logs**: `/aws/cloudtrail/ecommerce-ai-platform`

### Log File Validation

CloudTrail log file validation is enabled to ensure log integrity.

## SNS Alerts

### Email Subscriptions

Email addresses specified in `alert_emails` will receive:
- Alarm notifications
- Alarm state changes
- Alarm descriptions

### Confirming Subscriptions

After deployment, check email for SNS subscription confirmation and click the confirmation link.

### Adding More Subscribers

```hcl
module "monitoring" {
  # ...
  alert_emails = [
    "ops@example.com",
    "devops@example.com",
    "oncall@example.com"
  ]
}
```

## Custom Metrics

### Publishing Custom Metrics

From Lambda functions:

```python
import boto3

cloudwatch = boto3.client('cloudwatch')

cloudwatch.put_metric_data(
    Namespace='ecommerce-ai-platform',
    MetricData=[
        {
            'MetricName': 'MarketIntelligence.ForecastAccuracy',
            'Value': 0.95,
            'Unit': 'None'
        }
    ]
)
```

### Metric Namespaces

- `ecommerce-ai-platform`: Custom application metrics
- `AWS/Lambda`: Lambda function metrics
- `AWS/ApiGateway`: API Gateway metrics
- `AWS/Batch`: Batch job metrics
- `AWS/DMS`: DMS replication metrics
- `AWS/Glue`: Glue Crawler metrics

## Best Practices

1. **Monitor Regularly**: Check dashboards daily
2. **Respond to Alarms**: Investigate and resolve alarm triggers promptly
3. **Review Logs**: Periodically review logs for patterns
4. **Adjust Thresholds**: Fine-tune alarm thresholds based on actual usage
5. **Retain Logs**: Keep logs for compliance and troubleshooting
6. **Encrypt Everything**: Use KMS encryption for all logs
7. **Tag Resources**: Proper tagging for cost allocation and organization

## Troubleshooting

### Alarm Not Triggering

- Check metric data is being published
- Verify threshold is appropriate
- Check evaluation periods
- Ensure SNS topic has subscribers

### Dashboard Not Showing Data

- Verify resources are deployed
- Check metric namespace and names
- Ensure proper IAM permissions
- Wait for data to accumulate (5-10 minutes)

### Logs Not Appearing

- Check Lambda/Batch jobs are running
- Verify log group exists
- Check IAM permissions for logging
- Ensure KMS key allows CloudWatch Logs

### CloudTrail Not Logging

- Verify trail is enabled
- Check S3 bucket policy
- Ensure IAM role has permissions
- Check CloudWatch Logs role

## Cost Optimization

### Log Retention

Shorter retention = lower costs:
- Development: 7 days
- Staging: 14 days
- Production: 30-90 days

### Metric Resolution

- Standard resolution (5 minutes): Lower cost
- High resolution (1 minute): Higher cost

### Log Filtering

Use metric filters to reduce log volume:

```hcl
resource "aws_cloudwatch_log_metric_filter" "errors_only" {
  name           = "ErrorsOnly"
  log_group_name = aws_cloudwatch_log_group.lambda_logs["auth-service"].name
  pattern        = "[ERROR]"
  
  metric_transformation {
    name      = "ErrorCount"
    namespace = "ecommerce-ai-platform"
    value     = "1"
  }
}
```

## Security

- All logs encrypted with KMS
- S3 buckets have public access blocked
- CloudTrail log file validation enabled
- IAM roles follow least privilege principle
- SNS topic encrypted

## Compliance

This monitoring setup helps meet compliance requirements:
- **PCI DSS**: Audit logging, access monitoring
- **SOC 2**: Security monitoring, incident detection
- **GDPR**: Data access logging, audit trails
- **HIPAA**: Access logs, encryption

## Next Steps

After deploying monitoring:

1. Confirm SNS email subscriptions
2. Review dashboards for initial data
3. Adjust alarm thresholds if needed
4. Set up on-call rotation for alerts
5. Create runbooks for common issues
6. Implement automated remediation (optional)

## Related Documentation

- [CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)
- [CloudTrail Documentation](https://docs.aws.amazon.com/cloudtrail/)
- [SNS Documentation](https://docs.aws.amazon.com/sns/)
- [CloudWatch Logs Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html)
