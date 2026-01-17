# Global Market Pulse Lambda Terraform Module

This module creates an AWS Lambda function for the Global Market Pulse system, which provides global and regional market analysis capabilities.

## Features

- Lambda function with Python 3.11 runtime
- IAM role with appropriate permissions for Athena, S3, and Glue
- CloudWatch log group with configurable retention
- CloudWatch alarms for errors, duration, and throttles
- Environment variable configuration
- KMS encryption support

## Usage

```hcl
module "global_market_pulse_lambda" {
  source = "./modules/global-market-pulse-lambda"

  function_name           = "global-market-pulse"
  deployment_package_path = "../../ai-systems/global-market-pulse/deployment.zip"
  memory_size            = 1024
  timeout                = 300

  athena_database        = "global_market_db"
  athena_output_location = "s3://ecommerce-athena-results/"
  s3_data_bucket        = "ecommerce-data-prod"
  s3_results_bucket     = "ecommerce-athena-results"

  aws_region         = "us-east-1"
  log_level          = "INFO"
  log_retention_days = 30

  kms_key_arn = aws_kms_key.main.arn

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Environment = "production"
    Project     = "ecommerce-ai-platform"
    System      = "global-market-pulse"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| function_name | Name of the Lambda function | string | "global-market-pulse" | no |
| deployment_package_path | Path to the Lambda deployment package (zip file) | string | - | yes |
| memory_size | Amount of memory in MB for Lambda function | number | 1024 | no |
| timeout | Timeout in seconds for Lambda function | number | 300 | no |
| athena_database | Athena database name | string | "global_market_db" | no |
| athena_output_location | S3 location for Athena query results | string | - | yes |
| s3_data_bucket | S3 bucket containing data for analysis | string | - | yes |
| s3_results_bucket | S3 bucket for Athena query results | string | - | yes |
| aws_region | AWS region | string | "us-east-1" | no |
| log_level | Logging level | string | "INFO" | no |
| log_retention_days | CloudWatch log retention in days | number | 30 | no |
| kms_key_arn | KMS key ARN for encryption | string | "" | no |
| error_threshold | Threshold for error alarm | number | 5 | no |
| duration_threshold_ms | Threshold for duration alarm in milliseconds | number | 250000 | no |
| alarm_actions | List of ARNs to notify when alarms trigger | list(string) | [] | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| function_name | Name of the Lambda function |
| function_arn | ARN of the Lambda function |
| function_invoke_arn | Invoke ARN of the Lambda function |
| function_role_arn | ARN of the Lambda execution role |
| function_role_name | Name of the Lambda execution role |
| log_group_name | Name of the CloudWatch log group |

## IAM Permissions

The Lambda function is granted the following permissions:

- **Athena**: Start and manage query executions
- **S3**: Read from data bucket, write to results bucket
- **Glue**: Read database and table metadata
- **CloudWatch Logs**: Create and write logs

## CloudWatch Alarms

The module creates three CloudWatch alarms:

1. **Errors**: Triggers when error count exceeds threshold (default: 5)
2. **Duration**: Triggers when average duration exceeds threshold (default: 250 seconds)
3. **Throttles**: Triggers when throttle count exceeds 5

## Environment Variables

The Lambda function is configured with the following environment variables:

- `ATHENA_DATABASE`: Athena database name
- `ATHENA_OUTPUT_LOCATION`: S3 location for query results
- `AWS_REGION`: AWS region
- `LOG_LEVEL`: Logging level (INFO, DEBUG, WARNING, ERROR)

## Resource Configuration

### Lambda Function
- **Runtime**: Python 3.11
- **Memory**: 1024 MB (configurable)
- **Timeout**: 300 seconds (configurable)
- **Handler**: `handler.lambda_handler`

### CloudWatch Logs
- **Retention**: 30 days (configurable)
- **Encryption**: Optional KMS encryption

## Dependencies

This module requires:
- AWS Provider
- Deployment package (zip file) with Global Market Pulse code
- S3 buckets for data and results
- Athena database and workgroup
- Optional: KMS key for encryption
- Optional: SNS topic for alarm notifications

## Notes

- Ensure the deployment package is built before applying this module
- The Lambda function requires access to Athena, S3, and Glue
- CloudWatch alarms require SNS topics for notifications
- Adjust memory and timeout based on workload requirements
- Consider using VPC configuration for enhanced security

## Example with API Gateway Integration

```hcl
module "global_market_pulse_lambda" {
  source = "./modules/global-market-pulse-lambda"
  # ... configuration ...
}

# API Gateway integration
resource "aws_api_gateway_integration" "global_market_trends" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.global_market_trends.id
  http_method             = aws_api_gateway_method.global_market_trends_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.global_market_pulse_lambda.function_invoke_arn
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.global_market_pulse_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
```

## License

Copyright © 2026 eCommerce AI Platform. All rights reserved.
