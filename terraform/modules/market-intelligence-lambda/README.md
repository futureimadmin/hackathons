# Market Intelligence Hub Lambda Module

This Terraform module deploys the Market Intelligence Hub Lambda function for time series forecasting and market analytics.

## Features

- **Multiple Forecasting Models**: ARIMA, Prophet, and LSTM
- **Automatic Model Selection**: Compares models and selects the best performer
- **Market Analytics**: Trends analysis, competitive pricing, sales forecasting
- **Athena Integration**: Queries data from AWS Athena/Glue Data Catalog
- **High Memory**: 3 GB memory for ML model training
- **Extended Timeout**: 5-minute timeout for complex forecasting

## Usage

```hcl
module "market_intelligence_lambda" {
  source = "./modules/market-intelligence-lambda"
  
  project_name               = "ecommerce-ai-platform"
  aws_region                 = "us-east-1"
  lambda_s3_bucket           = "lambda-deployments-123456789012"
  lambda_s3_key              = "market-intelligence-hub/market-intelligence-hub-lambda.zip"
  athena_database            = "market_intelligence_hub"
  athena_workgroup           = "ecommerce-analytics"
  athena_staging_dir         = "s3://athena-query-results-123456789012/"
  api_gateway_execution_arn  = module.api_gateway.execution_arn
  
  tags = {
    Environment = "production"
    Project     = "eCommerce AI Platform"
  }
}
```

## API Endpoints

### 1. Generate Forecast

**POST** `/market-intelligence/forecast`

Generate sales forecast using specified or auto-selected model.

**Request Body:**
```json
{
  "metric": "sales",
  "horizon": 30,
  "model": "auto",
  "product_id": "optional",
  "category_id": "optional",
  "start_date": "2024-01-01",
  "end_date": "2025-01-15"
}
```

**Response:**
```json
{
  "forecast": [100.5, 102.3, ...],
  "lower_bound": [95.2, 97.1, ...],
  "upper_bound": [105.8, 107.5, ...],
  "model": "prophet",
  "evaluation_metrics": {
    "rmse": 5.2,
    "mae": 4.1,
    "mape": 3.8
  },
  "metadata": {
    "metric": "sales",
    "horizon": 30,
    "data_points": 365
  }
}
```

### 2. Get Market Trends

**GET** `/market-intelligence/trends?start_date=2024-01-01&end_date=2025-01-15`

Retrieve market trend data.

**Response:**
```json
{
  "trends": [
    {
      "trend_date": "2025-01-15",
      "trend_type": "sales",
      "metric_name": "daily_revenue",
      "metric_value": 15000.50,
      "growth_rate": 5.2
    }
  ],
  "count": 90
}
```

### 3. Get Competitive Pricing

**GET** `/market-intelligence/competitive-pricing?product_id=abc123`

Retrieve competitive pricing analysis.

**Response:**
```json
{
  "pricing": [
    {
      "product_id": "abc123",
      "competitor_name": "Competitor A",
      "competitor_price": 99.99,
      "our_price": 95.99,
      "price_difference": -4.00,
      "price_difference_pct": -4.0
    }
  ]
}
```

### 4. Compare Models

**POST** `/market-intelligence/compare-models`

Compare performance of multiple forecasting models.

**Request Body:**
```json
{
  "models": ["arima", "prophet", "lstm"],
  "product_id": "optional",
  "category_id": "optional",
  "start_date": "2024-01-01",
  "end_date": "2025-01-15"
}
```

**Response:**
```json
{
  "evaluation_results": {
    "arima": {"rmse": 5.2, "mae": 4.1, "mape": 3.8},
    "prophet": {"rmse": 4.8, "mae": 3.9, "mape": 3.5},
    "lstm": {"rmse": 5.5, "mae": 4.3, "mape": 4.0}
  },
  "comparison": [
    {"model": "prophet", "rmse": 4.8, "is_best": true},
    {"model": "arima", "rmse": 5.2, "is_best": false},
    {"model": "lstm", "rmse": 5.5, "is_best": false}
  ],
  "best_model": "prophet"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Project name for resource naming | string | - | yes |
| aws_region | AWS region | string | us-east-1 | no |
| lambda_s3_bucket | S3 bucket containing Lambda deployment package | string | - | yes |
| lambda_s3_key | S3 key for Lambda deployment package | string | - | yes |
| athena_database | Athena database name | string | market_intelligence_hub | no |
| athena_workgroup | Athena workgroup name | string | ecommerce-analytics | no |
| athena_staging_dir | S3 location for Athena query results | string | - | yes |
| api_gateway_execution_arn | API Gateway execution ARN | string | - | yes |
| vpc_config | VPC configuration (optional) | object | null | no |
| lambda_layers | List of Lambda layer ARNs | list(string) | [] | no |
| log_level | Logging level | string | INFO | no |
| log_retention_days | CloudWatch log retention in days | number | 30 | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_arn | ARN of the Lambda function |
| lambda_function_name | Name of the Lambda function |
| lambda_function_invoke_arn | Invoke ARN for API Gateway integration |
| lambda_role_arn | ARN of the Lambda execution role |
| lambda_role_name | Name of the Lambda execution role |
| log_group_name | Name of the CloudWatch log group |

## IAM Permissions

The Lambda function has permissions to:
- Execute Athena queries
- Read from S3 production buckets
- Write to Athena staging directory
- Access Glue Data Catalog
- Write CloudWatch logs

## Dependencies

- Python 3.11 runtime
- TensorFlow 2.15.0 (for LSTM)
- Prophet 1.1.5 (for Prophet forecasting)
- statsmodels 0.14.1 (for ARIMA)
- pandas, numpy, scikit-learn
- boto3, pyathena

## Building the Deployment Package

```powershell
cd ai-systems/market-intelligence-hub
./build.ps1 -Region us-east-1 -AccountId 123456789012
```

This creates `market-intelligence-hub-lambda.zip` and optionally uploads to S3.

## Performance Considerations

- **Memory**: 3 GB allocated for ML model training
- **Timeout**: 5 minutes for complex forecasting operations
- **Cold Start**: ~10-15 seconds due to ML library imports
- **Warm Execution**: 2-30 seconds depending on data size and model

## Monitoring

CloudWatch metrics to monitor:
- `Duration`: Execution time
- `Errors`: Failed invocations
- `Throttles`: Rate limiting
- `ConcurrentExecutions`: Concurrent invocations

Custom logs include:
- Model selection results
- Forecast accuracy metrics
- Data retrieval statistics
- Error traces

## Cost Optimization

- Lambda is billed per GB-second
- 3 GB memory × 30 seconds = 90 GB-seconds per forecast
- Consider using Lambda layers for large dependencies
- Use provisioned concurrency for consistent performance (optional)

## Security

- Least-privilege IAM role
- VPC configuration optional (for private Athena access)
- Encryption at rest for logs
- No sensitive data in environment variables
