# Retail Copilot Lambda Terraform Module

This module creates AWS Lambda infrastructure for the Retail Copilot AI assistant.

## Resources Created

- **Lambda Function**: Python 3.11 runtime with 2 GB memory
- **IAM Role**: Execution role with necessary permissions
- **IAM Policy**: Permissions for Athena, S3, Bedrock, DynamoDB, CloudWatch
- **CloudWatch Log Group**: For Lambda logs
- **DynamoDB Table**: For conversation history storage
- **Lambda Permission**: For API Gateway invocation

## Usage

```hcl
module "retail_copilot_lambda" {
  source = "./modules/retail-copilot-lambda"

  function_name              = "retail-copilot"
  lambda_zip_path           = "../ai-systems/retail-copilot/deployment.zip"
  athena_database           = "retail_copilot_db"
  athena_output_location    = "s3://ecommerce-athena-results/"
  aws_region                = "us-east-1"
  llm_provider              = "bedrock"
  llm_model_id              = "anthropic.claude-v2"
  llm_temperature           = "0.7"
  llm_max_tokens            = "2000"
  conversation_table        = "retail-copilot-conversations"
  data_bucket_prefix        = "ecommerce-data"
  api_gateway_execution_arn = module.api_gateway.execution_arn
  log_level                 = "INFO"
  log_retention_days        = 30

  tags = {
    Environment = "production"
    Project     = "ecommerce-ai-platform"
    System      = "retail-copilot"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| function_name | Name of the Lambda function | string | "retail-copilot" | no |
| lambda_zip_path | Path to Lambda deployment package | string | - | yes |
| athena_database | Athena database name | string | "retail_copilot_db" | no |
| athena_output_location | S3 location for Athena query results | string | - | yes |
| aws_region | AWS region | string | "us-east-1" | no |
| llm_provider | LLM provider (bedrock, openai) | string | "bedrock" | no |
| llm_model_id | LLM model identifier | string | "anthropic.claude-v2" | no |
| llm_temperature | LLM sampling temperature | string | "0.7" | no |
| llm_max_tokens | Maximum tokens in LLM response | string | "2000" | no |
| conversation_table | DynamoDB table name for conversations | string | "retail-copilot-conversations" | no |
| data_bucket_prefix | Prefix for data lake S3 buckets | string | - | yes |
| api_gateway_execution_arn | API Gateway execution ARN | string | - | yes |
| log_level | Logging level | string | "INFO" | no |
| log_retention_days | CloudWatch log retention in days | number | 30 | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| lambda_function_arn | ARN of the Retail Copilot Lambda function |
| lambda_function_name | Name of the Retail Copilot Lambda function |
| lambda_function_invoke_arn | Invoke ARN of the Retail Copilot Lambda function |
| lambda_role_arn | ARN of the Lambda execution role |
| conversation_table_name | Name of the DynamoDB conversations table |
| conversation_table_arn | ARN of the DynamoDB conversations table |
| log_group_name | Name of the CloudWatch log group |

## IAM Permissions

The Lambda function has permissions for:

- **CloudWatch Logs**: Create log groups, streams, and put log events
- **Athena**: Execute queries, get results
- **Glue**: Access database and table metadata
- **S3**: Read from data lake buckets, write to Athena results bucket
- **Bedrock**: Invoke foundation models (Claude, Titan)
- **DynamoDB**: Full access to conversations table

## DynamoDB Table Schema

### Conversations Table

- **Hash Key**: `conversation_id` (String)
- **GSI**: `user_id-index` on `user_id` (String)
- **TTL**: Enabled on `ttl` attribute
- **Billing**: Pay-per-request

### Item Structure

```json
{
  "conversation_id": "conv-user123-1705401600",
  "user_id": "user123",
  "created_at": "2026-01-16T10:00:00Z",
  "updated_at": "2026-01-16T10:30:00Z",
  "messages": [
    {
      "role": "user",
      "content": "Show me low stock products",
      "timestamp": "2026-01-16T10:00:00Z",
      "metadata": {}
    },
    {
      "role": "assistant",
      "content": "I found 15 products with low stock...",
      "timestamp": "2026-01-16T10:00:05Z",
      "metadata": {
        "query_type": "data_query",
        "has_data": true
      }
    }
  ],
  "metadata": {
    "source": "chat"
  },
  "ttl": 1737897600
}
```

## Lambda Configuration

- **Runtime**: Python 3.11
- **Memory**: 2048 MB (2 GB)
- **Timeout**: 300 seconds (5 minutes)
- **Handler**: `handler.lambda_handler`
- **Architecture**: x86_64

## Environment Variables

The Lambda function receives these environment variables:

- `ATHENA_DATABASE`: Athena database name
- `ATHENA_OUTPUT_LOCATION`: S3 location for query results
- `AWS_REGION`: AWS region
- `LLM_PROVIDER`: LLM provider (bedrock, openai)
- `LLM_MODEL_ID`: Model identifier
- `LLM_TEMPERATURE`: Sampling temperature
- `LLM_MAX_TOKENS`: Maximum tokens in response
- `CONVERSATION_TABLE`: DynamoDB table name
- `LOG_LEVEL`: Logging level

## Monitoring

### CloudWatch Metrics

- Lambda invocations
- Duration
- Errors
- Throttles
- Memory usage
- Concurrent executions

### CloudWatch Logs

- Request/response logging
- LLM interactions
- SQL query generation
- Error stack traces
- Performance timings

### Recommended Alarms

- Error rate > 1%
- Duration > 4 minutes
- Throttles > 0
- Memory usage > 90%
- DynamoDB read/write capacity

## Cost Optimization

1. **Memory Allocation**: 2 GB is sufficient for LLM operations
2. **Timeout**: 5 minutes allows for complex queries
3. **DynamoDB**: Pay-per-request billing for variable workloads
4. **Log Retention**: 30 days balances cost and debugging needs
5. **Bedrock**: Pay per token, optimize prompts for efficiency

## Security

1. **IAM Roles**: Least-privilege access
2. **Encryption**: Data encrypted at rest and in transit
3. **VPC**: Can be deployed in VPC for additional isolation
4. **Secrets**: LLM API keys stored in Secrets Manager
5. **SQL Safety**: Validates queries to prevent dangerous operations

## Deployment

1. Build deployment package:
   ```bash
   cd ../ai-systems/retail-copilot
   ./build.ps1
   ```

2. Apply Terraform:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. Verify deployment:
   ```bash
   aws lambda invoke \
     --function-name retail-copilot \
     --payload '{"path":"/copilot/inventory","httpMethod":"GET"}' \
     response.json
   ```

## Troubleshooting

### Lambda Timeout

- Increase timeout in variables
- Optimize Athena queries
- Reduce LLM max_tokens

### Out of Memory

- Increase memory_size
- Optimize data processing
- Use streaming for large results

### Bedrock Access Denied

- Verify Bedrock is enabled in region
- Check IAM permissions
- Confirm model availability

### DynamoDB Throttling

- Check table capacity
- Review access patterns
- Consider provisioned capacity

## Requirements Validation

This module supports the following requirements:

- **18.1**: Natural language query interface ✓
- **18.2**: Answers questions about inventory, orders, customers ✓
- **18.3**: Product recommendations ✓
- **18.4**: Sales reports on demand ✓
- **18.5**: Order status updates ✓
- **18.6**: LLM integration (AWS Bedrock) ✓
- **18.7**: Integration with all systems ✓
- **18.8**: Conversation history and learning ✓

## License

Copyright © 2026 eCommerce AI Platform. All rights reserved.
