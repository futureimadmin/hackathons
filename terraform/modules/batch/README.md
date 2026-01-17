# AWS Batch Module

This Terraform module creates AWS Batch resources for running data processing jobs.

## Resources Created

- **Compute Environment**: Managed compute environment with EC2 or Fargate
- **Job Queue**: Job queue for data processing tasks
- **Job Definitions**: 
  - Raw-to-Curated: Validates, deduplicates, and checks compliance
  - Curated-to-Prod: Transforms and optimizes data for Athena
- **ECR Repository**: Container registry for data processing Docker images
- **IAM Roles**: Service, instance, job, and execution roles with appropriate permissions
- **CloudWatch Log Group**: Centralized logging for Batch jobs

## Usage

```hcl
module "batch" {
  source = "./modules/batch"

  project_name       = "ecommerce-ai-platform"
  aws_region         = "us-east-1"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.batch_security_group_id]
  kms_key_id         = module.kms.key_id
  kms_key_arn        = module.kms.key_arn

  # Compute configuration
  compute_type   = "EC2"  # or "FARGATE"
  instance_types = ["c5.xlarge", "c5.2xlarge"]
  min_vcpus      = 0
  max_vcpus      = 256
  desired_vcpus  = 0

  # Job configuration
  raw_to_curated_vcpus  = 4
  raw_to_curated_memory = 8192
  raw_to_curated_timeout = 3600

  curated_to_prod_vcpus  = 2
  curated_to_prod_memory = 4096
  curated_to_prod_timeout = 1800

  retry_attempts = 3
  log_level      = "INFO"

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
| aws_region | AWS region | string | - | yes |
| vpc_id | VPC ID for Batch compute environment | string | - | yes |
| subnet_ids | List of subnet IDs | list(string) | - | yes |
| security_group_ids | List of security group IDs | list(string) | - | yes |
| kms_key_id | KMS key ID for encryption | string | - | yes |
| kms_key_arn | KMS key ARN for encryption | string | - | yes |
| compute_type | Compute type (EC2 or FARGATE) | string | "EC2" | no |
| instance_types | List of instance types for EC2 | list(string) | ["c5.xlarge", "c5.2xlarge", "c5.4xlarge"] | no |
| min_vcpus | Minimum vCPUs | number | 0 | no |
| max_vcpus | Maximum vCPUs | number | 256 | no |
| desired_vcpus | Desired vCPUs | number | 0 | no |
| raw_to_curated_vcpus | vCPUs for raw-to-curated job | number | 4 | no |
| raw_to_curated_memory | Memory (MB) for raw-to-curated job | number | 8192 | no |
| raw_to_curated_timeout | Timeout (seconds) for raw-to-curated job | number | 3600 | no |
| curated_to_prod_vcpus | vCPUs for curated-to-prod job | number | 2 | no |
| curated_to_prod_memory | Memory (MB) for curated-to-prod job | number | 4096 | no |
| curated_to_prod_timeout | Timeout (seconds) for curated-to-prod job | number | 1800 | no |
| retry_attempts | Number of retry attempts | number | 3 | no |
| log_level | Log level (DEBUG, INFO, WARNING, ERROR) | string | "INFO" | no |
| log_retention_days | CloudWatch log retention in days | number | 30 | no |
| tags | Tags to apply to all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| compute_environment_arn | ARN of the Batch compute environment |
| job_queue_arn | ARN of the Batch job queue |
| job_queue_name | Name of the Batch job queue |
| raw_to_curated_job_definition_arn | ARN of the raw-to-curated job definition |
| curated_to_prod_job_definition_arn | ARN of the curated-to-prod job definition |
| batch_job_role_arn | ARN of the Batch job IAM role |
| batch_execution_role_arn | ARN of the Batch execution IAM role |
| ecr_repository_url | URL of the ECR repository |
| log_group_name | Name of the CloudWatch log group |

## Job Definitions

### Raw-to-Curated Job

Processes raw data from S3:
1. Reads raw Parquet files
2. Validates schema and data quality
3. Deduplicates records by primary key
4. Checks PCI DSS compliance
5. Masks sensitive fields
6. Writes to curated bucket

**Environment Variables:**
- `AWS_REGION`: AWS region
- `LOG_LEVEL`: Logging level
- `DEDUPLICATION_ENABLED`: Enable deduplication
- `COMPLIANCE_PCI_DSS_ENABLED`: Enable PCI DSS checks

### Curated-to-Prod Job

Transforms curated data for analytics:
1. Reads curated Parquet files
2. Applies table-specific transformations
3. Calculates derived columns
4. Optimizes for Athena queries
5. Writes to prod bucket with partitioning
6. Triggers Glue Crawler

**Environment Variables:**
- `AWS_REGION`: AWS region
- `LOG_LEVEL`: Logging level
- `GLUE_TRIGGER_CRAWLER`: Enable Glue Crawler trigger

## IAM Permissions

The module creates the following IAM roles:

1. **Batch Service Role**: Allows Batch to manage compute resources
2. **Batch Instance Role**: Allows EC2 instances to pull container images
3. **Batch Job Role**: Grants jobs access to S3, Glue, Secrets Manager, KMS
4. **Batch Execution Role**: Allows Fargate tasks to pull images and access secrets

## Retry Strategy

Jobs automatically retry on transient failures:
- **Max attempts**: 3 (configurable)
- **Retry conditions**: Task failed to start
- **Exit conditions**: Essential container exited

## Monitoring

All job logs are sent to CloudWatch Logs:
- **Log group**: `/aws/batch/{project_name}`
- **Retention**: 30 days (configurable)
- **Encryption**: KMS encrypted

## ECR Repository

The module creates an ECR repository for Docker images:
- **Image scanning**: Enabled on push
- **Encryption**: KMS encrypted
- **Lifecycle policy**: 
  - Keep last 10 tagged images
  - Remove untagged images after 7 days

## Deploying Docker Images

After creating the infrastructure, build and push your Docker image:

```bash
cd data-processing

# Authenticate with ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build image
docker build -t ecommerce-ai-platform-data-processor .

# Tag image
docker tag ecommerce-ai-platform-data-processor:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/ecommerce-ai-platform-data-processor:latest

# Push image
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/ecommerce-ai-platform-data-processor:latest
```

Or use the provided PowerShell script:

```powershell
.\build-and-push.ps1
```

## Cost Optimization

- **Scale to zero**: Set `desired_vcpus = 0` to avoid idle costs
- **Spot instances**: Consider using Spot instances for non-critical workloads
- **Right-sizing**: Adjust vCPUs and memory based on actual job requirements
- **Fargate vs EC2**: Use Fargate for sporadic workloads, EC2 for sustained processing
