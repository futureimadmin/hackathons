# EventBridge Module

This Terraform module creates EventBridge rules to orchestrate the data processing pipeline by triggering AWS Batch jobs on S3 events.

## Resources Created

- **EventBridge Rules**: Rules to detect S3 object creation events
- **EventBridge Targets**: Batch job targets for each rule
- **S3 Event Notifications**: Enable EventBridge notifications on S3 buckets
- **IAM Role**: Role for EventBridge to submit Batch jobs

## Architecture

```
S3 Raw Bucket (Object Created)
    ↓
EventBridge Rule
    ↓
AWS Batch Job (Raw-to-Curated)
    ↓
S3 Curated Bucket (Object Created)
    ↓
EventBridge Rule
    ↓
AWS Batch Job (Curated-to-Prod)
    ↓
S3 Prod Bucket
```

## Usage

```hcl
module "eventbridge" {
  source = "./modules/eventbridge"

  project_name   = "ecommerce-ai-platform"
  aws_account_id = data.aws_caller_identity.current.account_id

  systems = {
    market-intelligence-hub = {
      description = "Market Intelligence Hub system"
    }
    demand-insights-engine = {
      description = "Demand Insights Engine system"
    }
    compliance-guardian = {
      description = "Compliance Guardian system"
    }
    retail-copilot = {
      description = "Retail Copilot system"
    }
    global-market-pulse = {
      description = "Global Market Pulse system"
    }
  }

  batch_job_queue_arn                = module.batch.job_queue_arn
  raw_to_curated_job_definition_arn  = module.batch.raw_to_curated_job_definition_arn
  curated_to_prod_job_definition_arn = module.batch.curated_to_prod_job_definition_arn

  tags = {
    Environment = "production"
    Project     = "ecommerce-ai-platform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | string | - | yes |
| aws_account_id | AWS account ID | string | - | yes |
| systems | Map of system names to configurations | map(object) | - | yes |
| batch_job_queue_arn | ARN of the Batch job queue | string | - | yes |
| raw_to_curated_job_definition_arn | ARN of raw-to-curated job definition | string | - | yes |
| curated_to_prod_job_definition_arn | ARN of curated-to-prod job definition | string | - | yes |
| tags | Tags to apply to all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| raw_bucket_event_rules | Map of raw bucket event rule ARNs |
| curated_bucket_event_rules | Map of curated bucket event rule ARNs |
| eventbridge_role_arn | ARN of the EventBridge IAM role |

## Event Patterns

### Raw Bucket Events

Triggers when new Parquet files are created in raw buckets:

```json
{
  "source": ["aws.s3"],
  "detail-type": ["Object Created"],
  "detail": {
    "bucket": {
      "name": ["{system}-raw-{account-id}"]
    },
    "object": {
      "key": [{
        "suffix": ".parquet"
      }]
    }
  }
}
```

### Curated Bucket Events

Triggers when new Parquet files are created in curated buckets:

```json
{
  "source": ["aws.s3"],
  "detail-type": ["Object Created"],
  "detail": {
    "bucket": {
      "name": ["{system}-curated-{account-id}"]
    },
    "object": {
      "key": [{
        "suffix": ".parquet"
      }]
    }
  }
}
```

## Job Parameters

EventBridge passes S3 bucket and key information to Batch jobs:

```json
{
  "Parameters": {
    "Bucket": "<bucket-name>",
    "Key": "<object-key>"
  }
}
```

## IAM Permissions

The EventBridge role has permissions to:
- Submit jobs to the Batch job queue
- Invoke both job definitions (raw-to-curated and curated-to-prod)

## Monitoring

Monitor EventBridge rules in CloudWatch:
- **Invocations**: Number of times the rule was triggered
- **Failed invocations**: Number of failed target invocations
- **Throttled rules**: Number of throttled invocations

## Troubleshooting

### Events Not Triggering Jobs

1. **Check S3 Event Notifications**: Ensure EventBridge is enabled on the bucket
   ```bash
   aws s3api get-bucket-notification-configuration --bucket {bucket-name}
   ```

2. **Check EventBridge Rule**: Verify the rule is enabled
   ```bash
   aws events describe-rule --name {rule-name}
   ```

3. **Check IAM Permissions**: Verify EventBridge role has permissions to submit Batch jobs

4. **Check CloudWatch Logs**: Look for errors in EventBridge logs
   ```bash
   aws logs tail /aws/events/{rule-name} --follow
   ```

### Jobs Not Starting

1. **Check Batch Job Queue**: Verify the queue is enabled
   ```bash
   aws batch describe-job-queues --job-queues {queue-name}
   ```

2. **Check Compute Environment**: Verify compute environment is enabled and has capacity
   ```bash
   aws batch describe-compute-environments --compute-environments {env-name}
   ```

3. **Check Job Definition**: Verify job definition is active
   ```bash
   aws batch describe-job-definitions --job-definition-name {job-name}
   ```

## Testing

Test the pipeline manually by uploading a file to S3:

```bash
# Upload test file to raw bucket
aws s3 cp test-data.parquet s3://market-intelligence-hub-raw-{account-id}/ecommerce/orders-raw/

# Check if job was triggered
aws batch list-jobs --job-queue {queue-name} --job-status RUNNING

# View job logs
aws logs tail /aws/batch/{project-name} --follow
```

## Cost Considerations

- **EventBridge**: $1.00 per million events
- **S3 Event Notifications**: No additional cost
- **Batch Jobs**: Charged based on compute resources used

## Best Practices

1. **Filter Events**: Use specific event patterns to avoid unnecessary job triggers
2. **Idempotency**: Ensure jobs can handle duplicate events safely
3. **Error Handling**: Implement proper error handling in Batch jobs
4. **Monitoring**: Set up CloudWatch alarms for failed invocations
5. **Testing**: Test event patterns thoroughly before production deployment
