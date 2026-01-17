# Demand Insights Lambda Module

This Terraform module creates the AWS Lambda function for the Demand Insights Engine, which provides customer segmentation, demand forecasting, price elasticity analysis, CLV prediction, and churn prediction.

## Features

- **Customer Segmentation**: K-Means clustering with RFM analysis
- **Demand Forecasting**: XGBoost-based forecasting with feature engineering
- **Price Elasticity**: Calculate price elasticity and optimize pricing
- **CLV Prediction**: Predict customer lifetime value using Random Forest
- **Churn Prediction**: Identify at-risk customers using Gradient Boosting

## Resources Created

- Lambda function with 3 GB memory and 5-minute timeout
- IAM role and policies for Lambda execution
- CloudWatch log group for Lambda logs
- Lambda permission for API Gateway invocation

## Usage

```hcl
module "demand_insights_lambda" {
  source = "./modules/demand-insights-lambda"

  function_name              = "demand-insights-engine"
  lambda_zip_path           = "../ai-systems/demand-insights-engine/deployment.zip"
  athena_database           = "demand_insights_db"
  athena_output_location    = "s3://ecommerce-athena-results/"
  data_bucket_prefix        = "ecommerce-data"
  api_gateway_execution_arn = module.api_gateway.execution_arn
  aws_region                = "us-east-1"

  tags = {
    Environment = "production"
    Project     = "ecommerce-ai-platform"
    System      = "demand-insights-engine"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| function_name | Name of the Lambda function | string | "demand-insights-engine" | no |
| lambda_zip_path | Path to the Lambda deployment package | string | - | yes |
| athena_database | Athena database name | string | "demand_insights_db" | no |
| athena_output_location | S3 location for Athena query results | string | - | yes |
| data_bucket_prefix | Prefix for data lake S3 buckets | string | "ecommerce-data" | no |
| aws_region | AWS region | string | "us-east-1" | no |
| log_level | Logging level | string | "INFO" | no |
| log_retention_days | CloudWatch log retention in days | number | 7 | no |
| api_gateway_execution_arn | API Gateway execution ARN | string | - | yes |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| function_name | Name of the Lambda function |
| function_arn | ARN of the Lambda function |
| invoke_arn | Invoke ARN of the Lambda function |
| role_arn | ARN of the Lambda execution role |
| log_group_name | Name of the CloudWatch log group |

## API Endpoints

The Lambda function provides the following endpoints:

### Customer Segmentation
- **GET** `/demand-insights/segments?n_clusters=5`
- Returns customer segments with RFM analysis

### Demand Forecasting
- **POST** `/demand-insights/forecast`
- Body: `{"product_id": "optional", "category_id": "optional", "forecast_days": 30}`
- Returns demand forecast with feature importance

### Price Elasticity
- **POST** `/demand-insights/price-elasticity`
- Body: `{"product_id": "optional", "category": "optional"}`
- Returns price elasticity coefficient and analysis

### Price Optimization
- **POST** `/demand-insights/price-optimization`
- Body: `{"product_id": "required", "current_price": 100.0, "current_quantity": 1000, "cost_per_unit": 60.0}`
- Returns optimal price recommendation

### CLV Prediction
- **POST** `/demand-insights/clv`
- Body: `{"customer_ids": ["optional", "list"]}`
- Returns customer lifetime value predictions

### Churn Prediction
- **POST** `/demand-insights/churn`
- Body: `{"customer_ids": ["optional", "list"]}`
- Returns churn probability and risk levels

### At-Risk Customers
- **GET** `/demand-insights/at-risk-customers?threshold=0.6&limit=100`
- Returns list of customers at risk of churning

## IAM Permissions

The Lambda function has permissions to:
- Write logs to CloudWatch
- Execute Athena queries
- Access Glue Data Catalog
- Read from data lake S3 buckets
- Write query results to Athena output location

## Configuration

### Environment Variables

- `ATHENA_DATABASE`: Athena database name
- `ATHENA_OUTPUT_LOCATION`: S3 location for query results
- `AWS_REGION`: AWS region
- `LOG_LEVEL`: Logging level (DEBUG, INFO, WARNING, ERROR)

### Memory and Timeout

- Memory: 3008 MB (3 GB) for ML model operations
- Timeout: 300 seconds (5 minutes) for complex queries and model training

## Dependencies

- Python 3.11 runtime
- Required Python packages (see requirements.txt):
  - boto3
  - pandas
  - numpy
  - scikit-learn
  - xgboost
  - lightgbm

## Deployment

1. Build the deployment package:
   ```bash
   cd ai-systems/demand-insights-engine
   ./build.ps1
   ```

2. Apply Terraform:
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

## Monitoring

- CloudWatch Logs: `/aws/lambda/demand-insights-engine`
- Metrics: Lambda invocations, duration, errors, throttles
- Alarms: Configure CloudWatch alarms for error rates and duration

## Notes

- The Lambda function reuses model instances across invocations for better performance
- In production, pre-trained models should be loaded from S3
- Consider using Lambda layers for large ML dependencies
- Adjust memory and timeout based on actual workload requirements
