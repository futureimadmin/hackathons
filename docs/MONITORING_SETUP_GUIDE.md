# Monitoring and Logging Setup Guide

## Overview

This guide provides step-by-step instructions for deploying and configuring the comprehensive monitoring and logging infrastructure for the eCommerce AI Analytics Platform.

## What's Included

### CloudWatch Dashboards (3)
1. **Data Pipeline Dashboard** - DMS, Batch, Glue metrics
2. **API Performance Dashboard** - API Gateway, Lambda metrics
3. **ML Performance Dashboard** - All 5 AI systems metrics

### CloudWatch Alarms (4)
1. **DMS Replication Lag** - Alerts when lag > 5 minutes
2. **Lambda Errors** - Alerts when errors > 10 in 5 minutes
3. **API Gateway 5xx** - Alerts when 5xx errors > 5 in 5 minutes
4. **Batch Job Failures** - Alerts on any job failure

### Log Groups (10)
- 7 Lambda function log groups
- 1 Batch job log group
- 1 API Gateway log group
- 1 CloudTrail log group

### CloudTrail
- Multi-region audit trail
- S3 data event tracking
- Lambda invocation tracking
- Log file validation

## Prerequisites

- Terraform installed
- AWS CLI configured
- KMS key created
- S3 data lake deployed
- Email addresses for alerts

## Deployment Steps

### Step 1: Configure Variables

Edit your Terraform configuration to include the monitoring module:

```hcl
# main.tf or monitoring.tf

module "monitoring" {
  source = "./modules/monitoring"

  project_name          = "ecommerce-ai-platform"
  environment           = "prod"
  aws_region            = var.aws_region
  kms_key_id            = module.kms.key_id
  data_lake_bucket_arn  = module.s3_data_lake.bucket_arn
  log_retention_days    = 30
  alert_emails          = [
    "ops@example.com",
    "devops@example.com"
  ]
}
```

### Step 2: Deploy with Terraform

```powershell
# Navigate to terraform directory
cd terraform

# Initialize Terraform (if not already done)
terraform init

# Plan the deployment
terraform plan -out=monitoring.tfplan

# Apply the changes
terraform apply monitoring.tfplan
```

### Step 3: Confirm SNS Subscriptions

After deployment, check your email for SNS subscription confirmation messages:

1. Open email from "AWS Notifications"
2. Click "Confirm subscription" link
3. Verify confirmation page appears
4. Repeat for all email addresses

### Step 4: Verify Dashboards

1. Navigate to AWS Console → CloudWatch → Dashboards
2. Verify 3 dashboards exist:
   - `ecommerce-ai-platform-data-pipeline`
   - `ecommerce-ai-platform-api-performance`
   - `ecommerce-ai-platform-ml-performance`
3. Open each dashboard and verify widgets load

### Step 5: Verify Alarms

1. Navigate to AWS Console → CloudWatch → Alarms
2. Verify 4 alarms exist:
   - `ecommerce-ai-platform-dms-replication-lag`
   - `ecommerce-ai-platform-lambda-errors`
   - `ecommerce-ai-platform-api-gateway-5xx`
   - `ecommerce-ai-platform-batch-job-failures`
3. Check alarm state (should be "OK" or "INSUFFICIENT_DATA")

### Step 6: Verify Log Groups

1. Navigate to AWS Console → CloudWatch → Log groups
2. Verify 10 log groups exist:
   - `/aws/lambda/ecommerce-ai-platform-auth-service`
   - `/aws/lambda/ecommerce-ai-platform-analytics-service`
   - `/aws/lambda/ecommerce-ai-platform-market-intelligence-hub`
   - `/aws/lambda/ecommerce-ai-platform-demand-insights-engine`
   - `/aws/lambda/ecommerce-ai-platform-compliance-guardian`
   - `/aws/lambda/ecommerce-ai-platform-retail-copilot`
   - `/aws/lambda/ecommerce-ai-platform-global-market-pulse`
   - `/aws/batch/job`
   - `/aws/apigateway/ecommerce-ai-platform`
   - `/aws/cloudtrail/ecommerce-ai-platform`

### Step 7: Verify CloudTrail

1. Navigate to AWS Console → CloudTrail → Trails
2. Verify trail exists: `ecommerce-ai-platform-audit-trail`
3. Check trail status: "Logging" should be ON
4. Verify S3 bucket: `ecommerce-ai-platform-cloudtrail-logs-<account-id>`

## Using the Dashboards

### Data Pipeline Dashboard

**Purpose**: Monitor data flow from MySQL to Athena

**Key Metrics**:
- DMS throughput (rows/second)
- DMS latency (milliseconds)
- Batch jobs (running, submitted, failed, succeeded)
- Glue Crawler tasks (completed, failed)

**What to Watch**:
- DMS latency should be < 5 minutes
- Batch job failures should be 0
- Glue Crawler failures should be 0

### API Performance Dashboard

**Purpose**: Monitor API and Lambda performance

**Key Metrics**:
- API Gateway requests (total, 4xx, 5xx)
- API Gateway latency (total, integration)
- Lambda invocations, errors, throttles
- Lambda duration

**What to Watch**:
- 5xx errors should be < 1%
- API latency should be < 2 seconds
- Lambda errors should be < 1%
- Lambda throttles should be 0

### ML Performance Dashboard

**Purpose**: Monitor AI system performance

**Key Metrics**:
- Forecast accuracy (Market Intelligence)
- Segmentation quality (Demand Insights)
- Fraud detection rate (Compliance Guardian)
- Chat response time (Retail Copilot)
- Trend accuracy (Global Market Pulse)

**What to Watch**:
- Forecast accuracy should be > 80%
- Fraud detection rate should be stable
- Chat response time should be < 45 seconds
- All metrics should show consistent patterns

## Responding to Alarms

### DMS Replication Lag Alarm

**Trigger**: Replication lag > 5 minutes

**Actions**:
1. Check DMS replication task status
2. Verify source database connectivity
3. Check for large transactions
4. Review DMS task logs
5. Consider increasing replication instance size

### Lambda Errors Alarm

**Trigger**: > 10 errors in 5 minutes

**Actions**:
1. Check CloudWatch Logs for error messages
2. Identify which Lambda function is failing
3. Review recent code changes
4. Check for dependency issues
5. Verify IAM permissions
6. Check for resource limits (memory, timeout)

### API Gateway 5xx Alarm

**Trigger**: > 5 5xx errors in 5 minutes

**Actions**:
1. Check Lambda function health
2. Review API Gateway logs
3. Verify backend service availability
4. Check for timeout issues
5. Review recent deployments

### Batch Job Failures Alarm

**Trigger**: Any Batch job failure

**Actions**:
1. Check Batch job logs
2. Identify failed job
3. Review error messages
4. Check S3 bucket permissions
5. Verify data format
6. Retry job if transient failure

## Querying Logs

### CloudWatch Logs Insights

Navigate to CloudWatch → Logs → Insights

#### Find Lambda Errors

```sql
fields @timestamp, @message, @logStream
| filter @message like /ERROR/
| sort @timestamp desc
| limit 50
```

#### Find Slow API Requests

```sql
fields @timestamp, @message
| filter @message like /Duration/
| parse @message /Duration: (?<duration>\d+\.\d+) ms/
| filter duration > 5000
| sort duration desc
| limit 20
```

#### Find Failed Batch Jobs

```sql
fields @timestamp, @message
| filter @message like /FAILED/
| sort @timestamp desc
| limit 20
```

#### Find High-Risk Transactions

```sql
fields @timestamp, @message
| filter @message like /high-risk/
| parse @message /risk_score: (?<score>\d+)/
| filter score > 70
| sort @timestamp desc
| limit 50
```

## Custom Metrics

### Publishing from Lambda

Add to your Lambda functions:

```python
import boto3
import json

cloudwatch = boto3.client('cloudwatch')

def publish_metric(metric_name, value, unit='None'):
    """Publish custom metric to CloudWatch"""
    try:
        cloudwatch.put_metric_data(
            Namespace='ecommerce-ai-platform',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': unit,
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
    except Exception as e:
        print(f"Error publishing metric: {e}")

# Example usage
publish_metric('MarketIntelligence.ForecastAccuracy', 0.95)
publish_metric('Compliance.FraudDetectionRate', 0.02)
publish_metric('RetailCopilot.ChatResponseTime', 2.5, 'Seconds')
```

### Viewing Custom Metrics

1. Navigate to CloudWatch → Metrics
2. Select "Custom Namespaces"
3. Select "ecommerce-ai-platform"
4. Choose metrics to graph

## CloudTrail Queries

### Find Who Created a Resource

```sql
SELECT eventTime, userIdentity.principalId, eventName, requestParameters
FROM cloudtrail_logs
WHERE eventName LIKE 'Create%'
ORDER BY eventTime DESC
LIMIT 100
```

### Find Failed API Calls

```sql
SELECT eventTime, eventName, errorCode, errorMessage
FROM cloudtrail_logs
WHERE errorCode IS NOT NULL
ORDER BY eventTime DESC
LIMIT 100
```

### Find S3 Data Access

```sql
SELECT eventTime, userIdentity.principalId, eventName, requestParameters.bucketName
FROM cloudtrail_logs
WHERE eventSource = 's3.amazonaws.com'
AND eventName IN ('GetObject', 'PutObject', 'DeleteObject')
ORDER BY eventTime DESC
LIMIT 100
```

## Maintenance Tasks

### Daily
- Review dashboards for anomalies
- Check alarm states
- Respond to any triggered alarms

### Weekly
- Review log insights for patterns
- Check for recurring errors
- Verify log retention settings
- Review CloudTrail events

### Monthly
- Analyze metric trends
- Adjust alarm thresholds if needed
- Review and optimize log retention
- Check CloudTrail storage costs
- Update alert email list

## Cost Optimization

### Log Retention

Adjust retention based on environment:

```hcl
# Development
log_retention_days = 7

# Staging
log_retention_days = 14

# Production
log_retention_days = 30
```

### Metric Resolution

Use standard resolution (5 minutes) for most metrics. Only use high resolution (1 minute) for critical metrics.

### Log Filtering

Create metric filters to reduce log volume:

```hcl
resource "aws_cloudwatch_log_metric_filter" "errors_only" {
  name           = "ErrorsOnly"
  log_group_name = "/aws/lambda/my-function"
  pattern        = "[ERROR]"
  
  metric_transformation {
    name      = "ErrorCount"
    namespace = "ecommerce-ai-platform"
    value     = "1"
  }
}
```

## Troubleshooting

### Dashboard Shows No Data

**Cause**: Resources not generating metrics yet

**Solution**:
- Wait 5-10 minutes for data to accumulate
- Verify resources are deployed and running
- Check metric namespace and names
- Ensure proper IAM permissions

### Alarm Not Triggering

**Cause**: Threshold too high or metric not publishing

**Solution**:
- Check metric data in CloudWatch
- Verify threshold is appropriate
- Check evaluation periods
- Ensure SNS topic has confirmed subscribers

### Logs Not Appearing

**Cause**: Lambda/Batch not running or IAM issues

**Solution**:
- Verify Lambda/Batch jobs are executing
- Check IAM permissions for logging
- Ensure KMS key allows CloudWatch Logs
- Check log group exists

### CloudTrail Not Logging

**Cause**: Trail disabled or S3 bucket policy issue

**Solution**:
- Verify trail is enabled
- Check S3 bucket policy allows CloudTrail
- Ensure IAM role has permissions
- Check CloudWatch Logs role

## Security Best Practices

1. **Encrypt Everything**: Use KMS for all logs
2. **Least Privilege**: IAM roles with minimal permissions
3. **Log File Validation**: Enable for CloudTrail
4. **Access Control**: Restrict who can view logs
5. **Retention Policies**: Don't keep logs longer than needed
6. **Audit Access**: Monitor who accesses logs

## Compliance

This monitoring setup helps meet:

- **PCI DSS**: Audit logging, access monitoring
- **SOC 2**: Security monitoring, incident detection
- **GDPR**: Data access logging, audit trails
- **HIPAA**: Access logs, encryption

## Next Steps

After monitoring is set up:

1. ✅ Confirm SNS subscriptions
2. ✅ Review dashboards
3. ✅ Test alarms (optional)
4. ✅ Set up on-call rotation
5. ✅ Create runbooks for common issues
6. ⏳ Implement automated remediation (Task 24)
7. ⏳ Add integration tests (Task 25)
8. ⏳ Conduct performance testing (Task 26)

## Support

For issues or questions:
- Check CloudWatch Logs for error messages
- Review AWS CloudWatch documentation
- Contact DevOps team
- Create incident ticket

---

**Status**: Ready for Deployment  
**Date**: January 16, 2026  
**Phase**: 6 (Integration and Testing)  
**Task**: 23 - Monitoring and Logging
