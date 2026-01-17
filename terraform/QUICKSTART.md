# Quick Start Guide

This guide will help you quickly set up the Terraform infrastructure foundation for the eCommerce AI Analytics Platform.

## Prerequisites

- AWS CLI installed and configured
- Terraform >= 1.0 installed
- AWS account with administrative permissions

## Step-by-Step Setup

### 1. Set Up Backend Resources

Run the setup script to create the S3 bucket and DynamoDB table for Terraform state:

```bash
cd terraform
chmod +x scripts/*.sh
./scripts/setup-backend.sh
```

This will create:
- S3 bucket: `ecommerce-ai-platform-terraform-state`
- DynamoDB table: `ecommerce-ai-platform-terraform-locks`

### 2. Configure Terraform

Copy the example configuration files:

```bash
cp backend.tfvars.example backend.tfvars
cp terraform.tfvars.example terraform.tfvars
```

**Edit `backend.tfvars`** (if you changed bucket/table names):
```hcl
bucket         = "ecommerce-ai-platform-terraform-state"
key            = "terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "ecommerce-ai-platform-terraform-locks"
```

**Edit `terraform.tfvars`** (customize for your environment):
```hcl
aws_region   = "us-east-1"
environment  = "dev"
project_name = "ecommerce-ai-platform"
vpc_cidr     = "10.0.0.0/16"
```

### 3. Initialize Terraform

```bash
terraform init -backend-config=backend.tfvars
```

### 4. Validate Configuration

```bash
./scripts/validate.sh
```

Or manually:
```bash
terraform fmt -recursive
terraform validate
```

### 5. Plan Infrastructure

Review what will be created:

```bash
terraform plan
```

Expected resources:
- 1 KMS key with alias and policy
- 1 VPC with DNS support
- 2 public subnets
- 2 private subnets
- 1 Internet Gateway
- 2 NAT Gateways with Elastic IPs
- Route tables and associations
- VPC Flow Logs with CloudWatch Log Group
- 5 Security Groups (Lambda, DMS, Batch, VPC Endpoints, API Gateway)
- IAM role and policy for VPC Flow Logs

### 6. Apply Infrastructure

Create the infrastructure:

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 7. View Outputs

After successful apply, view the outputs:

```bash
terraform output
```

You should see:
- `vpc_id` - VPC identifier
- `private_subnet_ids` - Private subnet identifiers
- `public_subnet_ids` - Public subnet identifiers
- `kms_key_id` - KMS key identifier
- `kms_key_arn` - KMS key ARN
- `aws_account_id` - Your AWS account ID

## What Gets Created

### KMS Encryption
- KMS key with automatic rotation enabled
- Key policy allowing AWS services (S3, Lambda, DMS, Glue, Secrets Manager)
- 30-day deletion window for safety

### VPC and Networking
- VPC with CIDR 10.0.0.0/16 (customizable)
- 2 public subnets (10.0.0.0/24, 10.0.1.0/24)
- 2 private subnets (10.0.10.0/24, 10.0.11.0/24)
- Internet Gateway for public subnets
- 2 NAT Gateways for private subnet internet access
- VPC Flow Logs for network monitoring

### Security Groups
1. **Lambda SG** - Outbound internet access for Lambda functions
2. **DMS SG** - Access to on-premise MySQL (172.20.10.4:3306)
3. **Batch SG** - For AWS Batch compute resources
4. **VPC Endpoints SG** - HTTPS access from VPC
5. **API Gateway SG** - HTTPS access from internet

## Troubleshooting

### Backend Already Exists Error
If you get an error about the backend already existing, the S3 bucket or DynamoDB table may already be created. Check AWS Console or run:
```bash
aws s3 ls | grep terraform-state
aws dynamodb list-tables | grep terraform-locks
```

### Insufficient Permissions
Ensure your AWS credentials have permissions for:
- S3 (create bucket, put object)
- DynamoDB (create table)
- VPC (create VPC, subnets, gateways)
- KMS (create key, create alias)
- IAM (create role, attach policy)
- CloudWatch Logs (create log group)

### Region Mismatch
Ensure the region in `backend.tfvars` matches the region in `terraform.tfvars`.

## Next Steps

After the infrastructure foundation is set up, you can proceed to:
1. Task 2: Implement S3 data lake infrastructure
2. Task 3: Implement AWS DMS for data replication
3. Continue with remaining tasks in the implementation plan

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

**Warning:** This will delete all infrastructure. Ensure you have backups of any important data.

To also remove backend resources:
```bash
aws s3 rb s3://ecommerce-ai-platform-terraform-state --force
aws dynamodb delete-table --table-name ecommerce-ai-platform-terraform-locks
```
