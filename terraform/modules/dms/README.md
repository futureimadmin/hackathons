# AWS DMS Terraform Module

This module creates AWS Database Migration Service (DMS) resources for continuous data replication from on-premise MySQL to S3.

## Features

- DMS Replication Instance with Multi-AZ support
- Source endpoint for on-premise MySQL database
- Target endpoints for S3 buckets (one per system)
- Replication tasks with CDC (Change Data Capture) enabled
- IAM roles and policies for DMS operations
- CloudWatch logging for monitoring
- KMS encryption for data at rest and in transit

## Usage

```hcl
module "dms" {
  source = "./modules/dms"

  environment                  = "dev"
  project_name                 = "ecommerce-ai-platform"
  vpc_id                       = module.vpc.vpc_id
  subnet_ids                   = module.vpc.private_subnet_ids
  security_group_ids           = [module.vpc.dms_security_group_id]
  kms_key_arn                  = module.kms.key_arn
  source_password_secret_arn   = aws_secretsmanager_secret.mysql_password.arn

  source_endpoint_config = {
    server_name   = "172.20.10.4"
    port          = 3306
    username      = "root"
    database_name = "ecommerce"
    ssl_mode      = "require"
  }

  target_s3_buckets = {
    "market-intelligence-hub" = "market-intelligence-hub-raw-123456789012"
    "demand-insights-engine"  = "demand-insights-engine-raw-123456789012"
    "compliance-guardian"     = "compliance-guardian-raw-123456789012"
    "retail-copilot"          = "retail-copilot-raw-123456789012"
    "global-market-pulse"     = "global-market-pulse-raw-123456789012"
  }

  replication_tasks = [
    {
      task_id        = "market-intelligence-hub-replication"
      source_database = "ecommerce"
      target_bucket  = "market-intelligence-hub"
      migration_type = "full-load-and-cdc"
      table_mappings = jsonencode({
        rules = [
          {
            rule-type = "selection"
            rule-id   = "1"
            rule-name = "1"
            object-locator = {
              schema-name = "ecommerce"
              table-name  = "%"
            }
            rule-action = "include"
          }
        ]
      })
    }
  ]

  tags = {
    Project     = "eCommerce AI Platform"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name (dev, staging, prod) | `string` | n/a | yes |
| project_name | Project name for resource naming | `string` | `"ecommerce-ai-platform"` | no |
| vpc_id | VPC ID where DMS replication instance will be deployed | `string` | n/a | yes |
| subnet_ids | List of subnet IDs for DMS replication instance | `list(string)` | n/a | yes |
| security_group_ids | List of security group IDs for DMS replication instance | `list(string)` | n/a | yes |
| kms_key_arn | ARN of KMS key for encryption | `string` | n/a | yes |
| source_password_secret_arn | ARN of the secret containing source database password | `string` | n/a | yes |
| source_endpoint_config | Configuration for source MySQL endpoint | `object` | See variables.tf | no |
| target_s3_buckets | Map of system names to their raw S3 bucket names | `map(string)` | n/a | yes |
| replication_tasks | List of replication tasks to create | `list(object)` | `[]` | no |
| replication_instance_class | Instance class for DMS replication instance | `string` | `"dms.c5.xlarge"` | no |
| allocated_storage | Allocated storage in GB for DMS replication instance | `number` | `200` | no |
| multi_az | Enable Multi-AZ for high availability | `bool` | `true` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| replication_instance_arn | ARN of the DMS replication instance |
| replication_instance_id | ID of the DMS replication instance |
| source_endpoint_arn | ARN of the source MySQL endpoint |
| target_endpoint_arns | Map of system names to target S3 endpoint ARNs |
| replication_task_arns | Map of task IDs to replication task ARNs |
| dms_s3_role_arn | ARN of the IAM role for DMS S3 access |
| cloudwatch_log_group_name | Name of the CloudWatch Log Group for DMS |

## Table Mappings

Table mappings define which tables to replicate and how to transform them. Example:

```json
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "include-all-tables",
      "object-locator": {
        "schema-name": "ecommerce",
        "table-name": "%"
      },
      "rule-action": "include"
    },
    {
      "rule-type": "transformation",
      "rule-id": "2",
      "rule-name": "add-prefix",
      "rule-target": "table",
      "object-locator": {
        "schema-name": "ecommerce",
        "table-name": "%"
      },
      "rule-action": "add-prefix",
      "value": "ecommerce_"
    }
  ]
}
```

## Monitoring

The module creates CloudWatch Log Groups for DMS logging. Monitor these metrics:

- `CDCLatencySource` - Latency between source and DMS
- `CDCLatencyTarget` - Latency between DMS and target
- `FullLoadThroughputBandwidthTarget` - Data transfer rate
- `FullLoadThroughputRowsTarget` - Row transfer rate

## Security

- All data is encrypted at rest using KMS
- Data in transit is encrypted using SSL/TLS
- IAM roles follow least-privilege principle
- Source database password stored in AWS Secrets Manager
- VPC security groups restrict network access

## Notes

- DMS replication instance takes 5-10 minutes to provision
- Full load can take several hours depending on data volume
- CDC captures changes with minimal latency (typically < 5 minutes)
- Monitor CloudWatch metrics for replication lag
- Test with small datasets before full production load
