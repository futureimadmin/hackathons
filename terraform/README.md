# eCommerce AI Analytics Platform - Terraform Infrastructure

This directory contains the Terraform infrastructure as code for the eCommerce AI Analytics Platform.

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with necessary permissions

## Project Structure

```
terraform/
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Variable definitions
├── backend.tfvars.example       # Example backend configuration
├── terraform.tfvars.example     # Example variable values
├── modules/
│   ├── kms/                     # KMS encryption module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── vpc/                     # VPC and networking module
│       ├── main.tf
│       ├── security_groups.tf
│       ├── variables.tf
│       └── outputs.tf
```

## Setup Instructions

### 1. Configure Backend

First, create an S3 bucket and DynamoDB table for Terraform state management:

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket ecommerce-ai-platform-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket ecommerce-ai-platform-terraform-state \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ecommerce-ai-platform-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name ecommerce-ai-platform-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Configure Variables

Copy the example files and update with your values:

```bash
cp backend.tfvars.example backend.tfvars
cp terraform.tfvars.example terraform.tfvars
```

Edit `backend.tfvars` with your backend configuration:
- Update bucket name if different
- Update region if different

Edit `terraform.tfvars` with your environment-specific values:
- Set your AWS region
- Set environment name (dev, staging, prod)
- Adjust VPC CIDR if needed

### 3. Initialize Terraform

```bash
terraform init -backend-config=backend.tfvars
```

### 4. Plan and Apply

```bash
# Review the execution plan
terraform plan

# Apply the configuration
terraform apply
```

## Modules

### KMS Module

Creates KMS keys for encryption with automatic key rotation enabled.

**Resources:**
- KMS key with 30-day deletion window
- KMS key alias
- KMS key policy allowing AWS services

**Outputs:**
- `kms_key_id` - KMS key ID
- `kms_key_arn` - KMS key ARN
- `kms_key_alias` - KMS key alias

### VPC Module

Creates a VPC with public and private subnets across 2 availability zones.

**Resources:**
- VPC with DNS support
- 2 public subnets with Internet Gateway
- 2 private subnets with NAT Gateways
- Route tables and associations
- VPC Flow Logs
- Security groups for Lambda, DMS, Batch, VPC Endpoints, and API Gateway

**Outputs:**
- `vpc_id` - VPC ID
- `public_subnet_ids` - Public subnet IDs
- `private_subnet_ids` - Private subnet IDs
- Security group IDs for various services

## Security Groups

The VPC module creates the following security groups:

1. **Lambda SG** - For Lambda functions with outbound internet access
2. **DMS SG** - For DMS replication instance with access to on-premise MySQL (172.20.10.4:3306)
3. **Batch SG** - For AWS Batch compute resources
4. **VPC Endpoints SG** - For VPC endpoints with HTTPS access from VPC
5. **API Gateway SG** - For API Gateway with HTTPS access

## Outputs

After applying, Terraform will output:
- VPC ID and subnet IDs
- KMS key ID and ARN
- Security group IDs
- AWS account ID

## State Management

Terraform state is stored in S3 with:
- Encryption enabled
- Versioning enabled
- DynamoDB table for state locking

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

**Warning:** This will delete all infrastructure. Make sure you have backups of any important data.

## Requirements Mapping

This infrastructure foundation satisfies the following requirements:
- **12.1, 12.2** - Infrastructure as Code using Terraform
- **13.5** - Encryption at rest using KMS
- **13.6** - Network isolation using VPC with public/private subnets
