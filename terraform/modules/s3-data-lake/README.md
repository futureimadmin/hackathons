# S3 Data Lake Module

This Terraform module creates a complete S3 data lake infrastructure for a system, including raw, curated, and prod buckets with appropriate configurations.

## Features

- **Three-tier bucket structure**: Raw, Curated, and Prod buckets
- **Encryption**: KMS encryption at rest for all buckets
- **Versioning**: Enabled for curated and prod buckets
- **Lifecycle policies**: Automatic archival to Glacier for cost optimization
- **EventBridge notifications**: Enabled for pipeline orchestration
- **Public access blocking**: All buckets block public access
- **Bucket policies**: Pre-configured for DMS, Batch, Glue, and Athena access

## Bucket Structure

### Raw Bucket
- **Purpose**: Receives data from AWS DMS
- **Naming**: `{system-name}-raw-{account-id}`
- **Versioning**: Disabled
- **Lifecycle**: Archive to Glacier after 90 days, delete after 365 days
- **Access**: DMS (write), Batch (read)

### Curated Bucket
- **Purpose**: Contains validated and deduplicated data
- **Naming**: `{system-name}-curated-{account-id}`
- **Versioning**: Enabled
- **Lifecycle**: Archive to Glacier after 180 days
- **Access**: Batch (read/write)

### Prod Bucket
- **Purpose**: Contains analyst-ready data for Athena queries
- **Naming**: `{system-name}-prod-{account-id}`
- **Versioning**: Enabled
- **Lifecycle**: Move to Intelligent Tiering after 90 days
- **Access**: Batch (write), Glue (read), Athena (read)

## Usage

```hcl
module "market_intelligence_hub_data_lake" {
  source = "./modules/s3-data-lake"

  system_name        = "market-intelligence-hub"
  environment        = "dev"
  kms_key_id         = aws_kms_key.data_encryption.id
  batch_job_role_arn = aws_iam_role.batch_job_execution.arn

  tags = {
    Project   = "eCommerce AI Platform"
    ManagedBy = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| system_name | Name of the system (e.g., market-intelligence-hub) | string | yes |
| environment | Environment (dev, staging, prod) | string | yes |
| kms_key_id | KMS key ID for S3 bucket encryption | string | yes |
| batch_job_role_arn | ARN of the IAM role used by AWS Batch jobs | string | yes |
| tags | Additional tags to apply to all resources | map(string) | no |

## Outputs

| Name | Description |
|------|-------------|
| raw_bucket_id | ID of the raw S3 bucket |
| raw_bucket_arn | ARN of the raw S3 bucket |
| raw_bucket_name | Name of the raw S3 bucket |
| curated_bucket_id | ID of the curated S3 bucket |
| curated_bucket_arn | ARN of the curated S3 bucket |
| curated_bucket_name | Name of the curated S3 bucket |
| prod_bucket_id | ID of the prod S3 bucket |
| prod_bucket_arn | ARN of the prod S3 bucket |
| prod_bucket_name | Name of the prod S3 bucket |
| all_bucket_arns | List of all bucket ARNs |
| all_bucket_names | Map of bucket types to bucket names |

## Folder Structure

Data should be organized within buckets following this structure:

```
{system-name}-raw-{account-id}/
├── {schema-name}/
│   ├── {table-name}-raw/
│   │   ├── year=2025/
│   │   │   ├── month=01/
│   │   │   │   ├── day=16/
│   │   │   │   │   ├── data-001.parquet

{system-name}-curated-{account-id}/
├── {schema-name}/
│   ├── {bucket-name}-curated/
│   │   ├── year=2025/
│   │   │   ├── month=01/
│   │   │   │   └── data.parquet

{system-name}-prod-{account-id}/
├── {schema-name}/
│   ├── {bucket-name}-prod/
│   │   ├── year=2025/
│   │   │   ├── month=01/
│   │   │   │   └── data.parquet
```

## Requirements

- Terraform >= 1.5
- AWS Provider >= 5.0
- KMS key must be created before using this module
- Batch job IAM role must be created before using this module

## Notes

- EventBridge notifications are enabled on all buckets for pipeline orchestration
- Bucket policies allow necessary AWS services to access the buckets
- All buckets have public access blocked by default
- Encryption is enforced using KMS keys
