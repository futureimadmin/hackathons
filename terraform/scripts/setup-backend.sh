#!/bin/bash
# Script to set up Terraform backend resources (S3 bucket and DynamoDB table)

set -e

# Configuration
BUCKET_NAME="ecommerce-ai-platform-terraform-state"
DYNAMODB_TABLE="ecommerce-ai-platform-terraform-locks"
AWS_REGION="us-east-1"

echo "Setting up Terraform backend resources..."
echo "Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "Region: $AWS_REGION"
echo ""

# Check if bucket exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✓ S3 bucket $BUCKET_NAME already exists"
else
    echo "Creating S3 bucket $BUCKET_NAME..."
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$AWS_REGION"
    echo "✓ S3 bucket created"
fi

# Enable versioning
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled
echo "✓ Versioning enabled"

# Enable encryption
echo "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'
echo "✓ Encryption enabled"

# Block public access
echo "Blocking public access on S3 bucket..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
echo "✓ Public access blocked"

# Check if DynamoDB table exists
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$AWS_REGION" 2>/dev/null; then
    echo "✓ DynamoDB table $DYNAMODB_TABLE already exists"
else
    echo "Creating DynamoDB table $DYNAMODB_TABLE..."
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$AWS_REGION"
    
    echo "Waiting for table to be active..."
    aws dynamodb wait table-exists \
        --table-name "$DYNAMODB_TABLE" \
        --region "$AWS_REGION"
    echo "✓ DynamoDB table created"
fi

echo ""
echo "✓ Backend setup complete!"
echo ""
echo "Next steps:"
echo "1. Copy backend.tfvars.example to backend.tfvars"
echo "2. Copy terraform.tfvars.example to terraform.tfvars"
echo "3. Update the values in both files as needed"
echo "4. Run: terraform init -backend-config=backend.tfvars"
