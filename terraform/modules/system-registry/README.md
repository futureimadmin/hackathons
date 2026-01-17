# System Registry Module

## Overview

This Terraform module implements an extensible system registration framework for the eCommerce AI Analytics Platform. It allows new AI systems to be registered dynamically without manual infrastructure changes, automatically provisioning all required AWS resources.

## Features

### System Registry
- DynamoDB table for storing system metadata
- System status tracking (pending, active, failed)
- Global secondary indexes for efficient queries
- Point-in-time recovery enabled
- KMS encryption

### Automated Provisioning
- S3 buckets (raw, curated, prod) for each system
- Glue database and crawler
- EventBridge rules for data pipeline orchestration
- DMS replication tasks (optional)
- Complete infrastructure lifecycle management

### API Endpoints
- `POST /admin/systems` - Register new system
- `GET /admin/systems` - List all systems
- `GET /admin/systems/{system_id}` - Get system details

### Event-Driven Architecture
- DynamoDB Streams trigger infrastructure provisioning
- Automatic status updates
- Error handling and retry logic

## Architecture

```
User Request
    ↓
API Gateway (/admin/systems)
    ↓
System Registration Lambda
    ↓
DynamoDB (System Registry)
    ↓
DynamoDB Stream
    ↓
Infrastructure Provisioner Lambda
    ↓
AWS Services (S3, Glue, DMS, EventBridge)
```

## Usage

```hcl
module "system_registry" {
  source = "./modules/system-registry"

  project_name                  = "ecommerce-ai-platform"
  environment                   = "prod"
  aws_region                    = "us-east-1"
  kms_key_id                    = module.kms.key_id
  kms_key_arn                   = module.kms.key_arn
  data_lake_bucket_name         = module.s3_data_lake.bucket_name
  api_gateway_id                = module.api_gateway.api_id
  api_gateway_root_resource_id  = module.api_gateway.root_resource_id
  api_gateway_authorizer_id     = module.api_gateway.authorizer_id
  api_gateway_execution_arn     = module.api_gateway.execution_arn
}
```

## System Registration

### Request Format

```json
{
  "system_name": "inventory-optimizer",
  "description": "AI system for inventory optimization",
  "data_sources": [
    "inventory",
    "orders",
    "products"
  ],
  "endpoints": [
    {
      "path": "/inventory-optimizer/optimize",
      "method": "POST"
    },
    {
      "path": "/inventory-optimizer/recommendations",
      "method": "GET"
    }
  ],
  "lambda_config": {
    "memory": 2048,
    "timeout": 600,
    "runtime": "python3.11"
  }
}
```

### Response Format

```json
{
  "message": "System registered successfully",
  "system_id": "550e8400-e29b-41d4-a716-446655440000",
  "system_name": "inventory-optimizer",
  "status": "pending_provisioning",
  "note": "Infrastructure provisioning will begin automatically"
}
```

## Infrastructure Provisioned

For each registered system, the following resources are automatically created:

### S3 Buckets
- `{project}-{system}-raw` - Raw data from source
- `{project}-{system}-curated` - Validated and cleaned data
- `{project}-{system}-prod` - Production-ready data

**Features**:
- Versioning enabled
- KMS encryption
- Public access blocked
- Lifecycle policies

### Glue Resources
- Database: `{project}_{system}_db`
- Crawler: `{project}-{system}-crawler`
- Schedule: Every 6 hours

### EventBridge Rules
- Rule: `{project}-{system}-raw-to-curated`
- Triggers data processing on S3 events

### DMS Replication (Optional)
- Task: `{project}-{system}-replication`
- Replicates specified tables from source database

## System States

| State | Description |
|-------|-------------|
| `pending_provisioning` | System registered, awaiting infrastructure |
| `active` | Infrastructure provisioned successfully |
| `provisioning_failed` | Infrastructure provisioning failed |

## API Examples

### Register New System

```bash
curl -X POST https://api.example.com/admin/systems \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "system_name": "inventory-optimizer",
    "description": "AI system for inventory optimization",
    "data_sources": ["inventory", "orders", "products"]
  }'
```

### List All Systems

```bash
curl -X GET https://api.example.com/admin/systems \
  -H "Authorization: Bearer $TOKEN"
```

### Get System Details

```bash
curl -X GET https://api.example.com/admin/systems/{system_id} \
  -H "Authorization: Bearer $TOKEN"
```

## DynamoDB Schema

### System Record

```json
{
  "system_id": "uuid",
  "system_name": "string",
  "description": "string",
  "data_sources": ["string"],
  "endpoints": [
    {
      "path": "string",
      "method": "string"
    }
  ],
  "lambda_config": {
    "memory": "number",
    "timeout": "number",
    "runtime": "string"
  },
  "status": "string",
  "created_at": "ISO8601",
  "updated_at": "ISO8601",
  "infrastructure": {
    "s3_buckets": {
      "raw": "string",
      "curated": "string",
      "prod": "string"
    },
    "glue_database": "string",
    "glue_crawler": "string",
    "dms_task": "string",
    "eventbridge_rules": ["string"]
  },
  "error_message": "string (optional)"
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project_name | Name of the project | string | yes |
| environment | Environment (dev, staging, prod) | string | no |
| aws_region | AWS region | string | yes |
| kms_key_id | KMS key ID for encryption | string | yes |
| kms_key_arn | KMS key ARN for encryption | string | yes |
| data_lake_bucket_name | Name of the data lake S3 bucket | string | yes |
| api_gateway_id | ID of the API Gateway REST API | string | yes |
| api_gateway_root_resource_id | Root resource ID of the API Gateway | string | yes |
| api_gateway_authorizer_id | ID of the API Gateway authorizer | string | yes |
| api_gateway_execution_arn | Execution ARN of the API Gateway | string | yes |

## Outputs

| Name | Description |
|------|-------------|
| registry_table_name | Name of the system registry DynamoDB table |
| registry_table_arn | ARN of the system registry DynamoDB table |
| system_registration_function_name | Name of the system registration Lambda function |
| system_registration_function_arn | ARN of the system registration Lambda function |
| infrastructure_provisioner_function_name | Name of the infrastructure provisioner Lambda function |
| infrastructure_provisioner_function_arn | ARN of the infrastructure provisioner Lambda function |

## Deployment

### 1. Build Lambda Functions

```powershell
cd terraform/modules/system-registry/lambda
.\build.ps1
```

### 2. Deploy with Terraform

```powershell
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. Verify Deployment

```powershell
# Check DynamoDB table
aws dynamodb describe-table --table-name ecommerce-ai-platform-system-registry

# Check Lambda functions
aws lambda list-functions --query "Functions[?contains(FunctionName, 'system-registration')]"
```

## Monitoring

### CloudWatch Logs

- `/aws/lambda/ecommerce-ai-platform-system-registration`
- `/aws/lambda/ecommerce-ai-platform-infrastructure-provisioner`

### Metrics to Monitor

- System registration success rate
- Infrastructure provisioning time
- Failed provisioning attempts
- DynamoDB read/write capacity

### Alarms

Consider setting up alarms for:
- Lambda errors
- DynamoDB throttling
- Failed provisioning attempts

## Security

### IAM Permissions

**System Registration Lambda**:
- DynamoDB: PutItem, GetItem, UpdateItem, Query, Scan
- KMS: Decrypt, Encrypt, GenerateDataKey
- CloudWatch Logs: CreateLogGroup, CreateLogStream, PutLogEvents

**Infrastructure Provisioner Lambda**:
- S3: CreateBucket, PutBucketPolicy, PutBucketVersioning, etc.
- Glue: CreateDatabase, CreateCrawler, StartCrawler
- DMS: CreateReplicationTask, StartReplicationTask
- EventBridge: PutRule, PutTargets
- IAM: PassRole (limited to specific services)
- DynamoDB: GetItem, UpdateItem, Stream access
- KMS: Decrypt, Encrypt, GenerateDataKey
- CloudWatch Logs: CreateLogGroup, CreateLogStream, PutLogEvents

### Encryption

- DynamoDB table encrypted with KMS
- S3 buckets encrypted with KMS
- CloudWatch Logs encrypted with KMS
- All data in transit uses TLS

### Access Control

- API endpoints require JWT authentication
- Lambda functions use least-privilege IAM roles
- DynamoDB Streams trigger Lambda automatically

## Limitations

### Current Limitations

1. **DMS Task Creation**: Requires manual endpoint configuration
2. **Lambda Deployment**: System-specific Lambda functions not auto-deployed
3. **API Gateway Routes**: System endpoints not auto-registered
4. **Rollback**: No automatic rollback on provisioning failure

### Future Enhancements

1. **Complete DMS Automation**: Auto-configure source/target endpoints
2. **Lambda Template System**: Deploy system-specific Lambda from templates
3. **Dynamic API Routes**: Auto-register system endpoints in API Gateway
4. **Rollback Mechanism**: Automatic cleanup on provisioning failure
5. **Validation**: Pre-provisioning validation of system configuration
6. **Monitoring Integration**: Auto-create CloudWatch dashboards per system

## Troubleshooting

### System Stuck in pending_provisioning

**Cause**: Infrastructure provisioner Lambda failed

**Solution**:
1. Check CloudWatch Logs for provisioner Lambda
2. Verify IAM permissions
3. Check for resource limits (S3 bucket limits, etc.)
4. Manually update system status if needed

### Infrastructure Provisioning Failed

**Cause**: AWS service error or permission issue

**Solution**:
1. Check error_message in system record
2. Review CloudWatch Logs
3. Verify IAM permissions
4. Check AWS service quotas
5. Retry provisioning if transient error

### Bucket Already Exists Error

**Cause**: S3 bucket name collision

**Solution**:
1. Choose different system name
2. Delete existing buckets if safe
3. Update bucket naming convention

## Best Practices

1. **Naming Conventions**: Use lowercase, hyphen-separated names
2. **Data Sources**: Specify only tables that exist in source database
3. **Lambda Config**: Set appropriate memory and timeout based on workload
4. **Testing**: Test in dev environment before production
5. **Monitoring**: Set up CloudWatch alarms for critical metrics
6. **Documentation**: Document each system's purpose and endpoints

## Examples

### Example 1: Simple System

```json
{
  "system_name": "customer-insights",
  "description": "Customer behavior analysis system",
  "data_sources": ["customers", "orders"]
}
```

### Example 2: Complex System

```json
{
  "system_name": "supply-chain-optimizer",
  "description": "Supply chain optimization with ML",
  "data_sources": [
    "inventory",
    "orders",
    "shipments",
    "suppliers"
  ],
  "endpoints": [
    {
      "path": "/supply-chain/optimize",
      "method": "POST"
    },
    {
      "path": "/supply-chain/forecast",
      "method": "GET"
    },
    {
      "path": "/supply-chain/alerts",
      "method": "GET"
    }
  ],
  "lambda_config": {
    "memory": 3008,
    "timeout": 900,
    "runtime": "python3.11"
  }
}
```

## Related Documentation

- [DynamoDB Streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.html)
- [AWS Lambda](https://docs.aws.amazon.com/lambda/)
- [AWS Glue](https://docs.aws.amazon.com/glue/)
- [AWS DMS](https://docs.aws.amazon.com/dms/)
- [EventBridge](https://docs.aws.amazon.com/eventbridge/)

## Support

For issues or questions:
- Check CloudWatch Logs
- Review system record in DynamoDB
- Contact DevOps team
- Create incident ticket
