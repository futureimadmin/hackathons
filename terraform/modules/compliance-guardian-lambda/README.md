# Compliance Guardian Lambda Module

Terraform module for deploying the Compliance Guardian Lambda function with fraud detection, risk scoring, and PCI DSS compliance monitoring.

## Features

- Lambda function with Python 3.11 runtime
- 3 GB memory allocation for ML models and transformers
- 5-minute timeout for complex analysis
- IAM role with least-privilege permissions
- CloudWatch Logs integration
- API Gateway integration

## Usage

```hcl
module "compliance_guardian_lambda" {
  source = "./modules/compliance-guardian-lambda"

  function_name              = "compliance-guardian"
  lambda_zip_path           = "../ai-systems/compliance-guardian/deployment.zip"
  athena_database           = "compliance_db"
  athena_output_location    = "s3://ecommerce-athena-results/"
  data_bucket_prefix        = "ecommerce-data"
  aws_region                = "us-east-1"
  log_level                 = "INFO"
  log_retention_days        = 30
  api_gateway_execution_arn = module.api_gateway.execution_arn

  tags = {
    Environment = "production"
    Project     = "ecommerce-ai-platform"
    System      = "compliance-guardian"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| function_name | Name of the Lambda function | string | "compliance-guardian" | no |
| lambda_zip_path | Path to the Lambda deployment package | string | - | yes |
| athena_database | Athena database name for compliance data | string | "compliance_db" | no |
| athena_output_location | S3 location for Athena query results | string | - | yes |
| data_bucket_prefix | Prefix for data lake S3 buckets | string | - | yes |
| aws_region | AWS region | string | "us-east-1" | no |
| log_level | Logging level | string | "INFO" | no |
| log_retention_days | CloudWatch log retention in days | number | 30 | no |
| api_gateway_execution_arn | API Gateway execution ARN | string | - | yes |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_arn | ARN of the Compliance Guardian Lambda function |
| lambda_function_name | Name of the Compliance Guardian Lambda function |
| lambda_function_invoke_arn | Invoke ARN for API Gateway integration |
| lambda_role_arn | ARN of the Lambda execution role |
| lambda_role_name | Name of the Lambda execution role |
| log_group_name | Name of the CloudWatch log group |

## IAM Permissions

The Lambda function is granted the following permissions:

- **CloudWatch Logs**: Create log groups, streams, and put log events
- **Athena**: Execute queries, get results, stop queries
- **Glue**: Read database and table metadata
- **S3**: Read from data lake buckets, write to Athena results bucket

## Lambda Configuration

- **Runtime**: Python 3.11
- **Memory**: 3008 MB (3 GB)
- **Timeout**: 300 seconds (5 minutes)
- **Handler**: handler.lambda_handler

## Environment Variables

The Lambda function receives the following environment variables:

- `ATHENA_DATABASE`: Athena database name
- `ATHENA_OUTPUT_LOCATION`: S3 location for query results
- `AWS_REGION`: AWS region
- `LOG_LEVEL`: Logging level (INFO, DEBUG, WARNING, ERROR)

## Monitoring

CloudWatch Logs are automatically configured with:
- Log group: `/aws/lambda/${function_name}`
- Retention: Configurable (default 30 days)
- Encryption: AWS managed keys

## API Endpoints

The Lambda function handles the following endpoints:

- `POST /compliance/fraud-detection` - Detect fraudulent transactions
- `POST /compliance/risk-score` - Calculate risk scores
- `GET /compliance/high-risk-transactions` - List high-risk transactions
- `POST /compliance/pci-compliance` - Check PCI DSS compliance
- `GET /compliance/compliance-report` - Generate compliance report
- `GET /compliance/fraud-statistics` - Get fraud statistics

## Dependencies

The deployment package must include:
- boto3
- pandas
- numpy
- scikit-learn
- xgboost
- transformers
- torch
- scipy

## Cost Considerations

- Lambda invocations: Pay per request
- Memory: 3 GB allocation increases cost per millisecond
- Athena: Pay per query and data scanned
- CloudWatch Logs: Storage and ingestion costs

## Security

- IAM role follows least-privilege principle
- No hardcoded credentials
- Sensitive data masked in logs
- PCI DSS compliant data handling

## Troubleshooting

### Lambda Timeout
If the function times out, consider:
- Increasing timeout (max 15 minutes)
- Reducing data volume per request
- Optimizing Athena queries

### Out of Memory
If the function runs out of memory:
- Increase memory allocation
- Optimize model size
- Process data in smaller batches

### Cold Start
To reduce cold start latency:
- Use provisioned concurrency
- Keep Lambda warm with scheduled invocations
- Use smaller transformer models

## Requirements Validation

This module supports the following requirements:

- **17.1**: PCI DSS compliance monitoring ✓
- **17.2**: Fraud detection models ✓
- **17.3**: Transaction risk scoring ✓
- **17.4**: Document understanding with NLP ✓
- **17.5**: Compliance report generation ✓
- **17.6**: Anomaly detection algorithms ✓
- **17.7**: Real-time alerts on high-risk transactions ✓
- **17.8**: Audit logs for compliance checks ✓

## License

Copyright © 2026 eCommerce AI Platform. All rights reserved.
