# Analytics Lambda Terraform Module

Creates AWS Lambda function for the analytics service with Athena integration.

## Resources Created

- Lambda function (Python 3.11)
- IAM role and policies
- CloudWatch log group
- Lambda permission for API Gateway

## Features

- **Athena Integration**: Full access to query Athena and Glue Catalog
- **S3 Access**: Read from data lake, write to Athena results bucket
- **Secrets Manager**: Access to JWT secret for authentication
- **CloudWatch Logs**: 7-day retention for debugging

## Usage

```hcl
module "analytics_lambda" {
  source = "./modules/analytics-lambda"

  project_name               = "ecommerce-platform"
  environment                = "dev"
  aws_region                 = "us-east-1"
  lambda_zip_path            = "../analytics-service/analytics-service.zip"
  athena_database            = "ecommerce_db"
  athena_output_location     = "s3://ecommerce-platform-athena-results/"
  athena_workgroup           = "primary"
  jwt_secret_name            = "ecommerce-platform/jwt-secret"
  jwt_secret_arn             = aws_secretsmanager_secret.jwt.arn
  data_lake_bucket_arn       = module.s3_data_lake.prod_bucket_arn
  athena_results_bucket_arn  = aws_s3_bucket.athena_results.arn
  api_gateway_execution_arn  = module.api_gateway.execution_arn

  tags = {
    Project     = "eCommerce AI Platform"
    Environment = "Development"
  }
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project_name | Project name for resource naming | string | yes |
| environment | Environment name | string | yes |
| aws_region | AWS region | string | yes |
| lambda_zip_path | Path to Lambda deployment package | string | yes |
| athena_database | Athena database name | string | yes |
| athena_output_location | S3 location for Athena results | string | yes |
| athena_workgroup | Athena workgroup name | string | no |
| jwt_secret_name | Secrets Manager secret name | string | yes |
| jwt_secret_arn | ARN of JWT secret | string | yes |
| data_lake_bucket_arn | ARN of data lake bucket | string | yes |
| athena_results_bucket_arn | ARN of Athena results bucket | string | yes |
| api_gateway_execution_arn | API Gateway execution ARN | string | yes |
| tags | Tags to apply | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| function_name | Lambda function name |
| function_arn | Lambda function ARN |
| invoke_arn | Lambda invoke ARN |
| role_arn | IAM role ARN |
| log_group_name | CloudWatch log group name |

## IAM Permissions

The Lambda function has permissions to:

- **Athena**: Execute queries, get results
- **Glue**: Read database and table metadata
- **S3**: Read from data lake, write to Athena results
- **Secrets Manager**: Read JWT secret
- **CloudWatch Logs**: Write logs

## Configuration

### Lambda Settings

- **Runtime**: Python 3.11
- **Timeout**: 60 seconds
- **Memory**: 512 MB
- **Handler**: `handler.lambda_handler`

### Environment Variables

- `ATHENA_DATABASE`: Athena database name
- `ATHENA_OUTPUT_LOCATION`: S3 location for query results
- `ATHENA_WORKGROUP`: Athena workgroup
- `JWT_SECRET_NAME`: Secrets Manager secret name

## Deployment

1. Build the Lambda package:
```powershell
cd ../analytics-service
.\build.ps1
```

2. Apply Terraform:
```bash
terraform apply
```

3. Update function code:
```bash
aws lambda update-function-code \
  --function-name ecommerce-platform-analytics-service \
  --zip-file fileb://../analytics-service/analytics-service.zip
```

## Monitoring

View logs in CloudWatch:
```bash
aws logs tail /aws/lambda/ecommerce-platform-analytics-service --follow
```

## Testing

Test the function:
```bash
aws lambda invoke \
  --function-name ecommerce-platform-analytics-service \
  --payload file://test-event.json \
  response.json
```

## Requirements Validated

- ✅ Requirement 4.1: Python-based analytics backend
- ✅ Requirement 4.7: Athena integration
- ✅ Requirement 20.3: AWS Lambda for serverless functions
- ✅ Requirement 20.9: CloudWatch for monitoring
